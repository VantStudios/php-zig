const std = @import("std");

const ffi = @import("ffi.zig");
const module = @import("module.zig");
const types = @import("types.zig");
const class = @import("class.zig");
const object = @import("object.zig");
const zval_mod = @import("zval.zig");
const string = @import("string.zig");
const str_mod = @import("string.zig");
const params = @import("params.zig");

const zval = types.zval;
const zend_class_entry = types.zend_class_entry;
const zend_object = types.zend_object;
const zend_execute_data = types.zend_execute_data;
const zend_array = types.zend_array;

// High-level, comptime-typed declarative classes.
//
// `Class(spec)` returns a type with a one-shot `register(module_entry) ->
// Registration{ .ce }`. `name` lives in the spec. Handlers take the class's
// `Self` view as their first parameter (declared `self: anytype`, resolved
// per-class) and use `self.prop(name)` (comptime-key checked, `@compileError`
// on typo), `self.return_string()`, `self.this()`, etc. Generic legacy
// `Self.get/getOwned/set` are removed.

/// Class-level flags. `.final`/`.abstract` map to `ZEND_ACC_FINAL`/`ZEND_ACC_ABSTRACT`.
pub const ClassSpecFlags = struct {
    final: bool = false,
    abstract: bool = false,
};

/// PHP prototype of a typed property/param at the Zig API boundary. `mixed` is
/// the catch-all (v1); `protoTypeMask` yields the `MAY_BE_*` mask.
pub const Proto = enum {
    long,
    double,
    bool,
    string,
    mixed,
};

pub fn protoTypeMask(p: Proto) u32 {
    return switch (p) {
        .long => types.MAY_BE_LONG,
        .double => types.MAY_BE_DOUBLE,
        .bool => types.MAY_BE_TRUE | types.MAY_BE_FALSE,
        .string => types.MAY_BE_STRING,
        .mixed => types.MAY_BE_NULL | types.MAY_BE_LONG | types.MAY_BE_DOUBLE |
            types.MAY_BE_TRUE | types.MAY_BE_FALSE | types.MAY_BE_STRING |
            types.MAY_BE_ARRAY | types.MAY_BE_OBJECT,
    };
}

/// Opts literal for `method()`. `anytype` lets callers attach an arbitrary
/// `.params` map keyed by handler-parameter name.
const MethodOpts = struct {};

/// Declares a method (used inside a `methods` spec). Returns a comptime type
/// carrying the handler, static/visibility flags and the per-param opt map as
/// `pub const`s; `classMethods` turns one entry per method name into a
/// `zend_function_entry`.
pub fn method(comptime handler: anytype, comptime opts: anytype) type {
    const O = @TypeOf(opts);
    return struct {
        pub const fn_ptr = handler;
        pub const static = if (@hasField(O, "static")) opts.static else false;
        pub const visibility: u32 =
            if (@hasField(O, "visibility")) opts.visibility else class.ZEND_ACC_PUBLIC;
        pub const params = if (@hasField(O, "params")) opts.params else .{};
    };
}

/// The handler's function type for a `method()`-style descriptor. Signatures
/// carry `fn_type` instead of `fn_ptr`, so this is the one canonical way to
/// derive the function type from either descriptor kind.
fn mdFnType(comptime md: anytype) type {
    return if (@hasDecl(md, "fn_type")) md.fn_type else @TypeOf(md.fn_ptr);
}

/// Whether a descriptor is a signature-only method (has `fn_type`, no handler).
fn isSignature(comptime md: anytype) bool {
    return @hasDecl(md, "fn_type");
}

/// Declares an interface method *signature*: no handler, just the argument
/// list and return type, emitted as an abstract method on the interface.
/// Accepted in the `methods` block of `Interface(...)`; the PHP engine then
/// enforces that every implementing class (Zig or userland) provides a body.
/// `fn_t` is the pure PHP signature with no handler/Self parameter, e.g.
/// `fn (name: []const u8) []const u8`.
pub fn signature(comptime fn_t: type, comptime opts: anytype) type {
    const O = @TypeOf(opts);
    return struct {
        pub const fn_type = fn_t;
        pub const visibility: u32 =
            if (@hasField(O, "visibility")) opts.visibility else class.ZEND_ACC_PUBLIC;
        pub const params = if (@hasField(O, "params")) opts.params else .{};
    };
}

fn isSliceOfU8(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .pointer and info.pointer.size == .slice and info.pointer.child == u8;
}

fn isRawZval(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .pointer and info.pointer.size == .one and info.pointer.child == zval;
}

fn isArrayPtr(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .pointer and info.pointer.size == .one and info.pointer.child == zend_array;
}

fn isObjectPtr(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .pointer and info.pointer.size == .one and info.pointer.child == zend_object;
}

fn isStringLike(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .pointer) return false;
    const p = info.pointer;
    if (p.size == .slice) return p.child == u8;
    if (p.size == .one) {
        if (p.child == u8) return true;
        const ci = @typeInfo(p.child);
        return ci == .array and ci.array.child == u8;
    }
    return false;
}

fn coerceSlice(value: anytype) []const u8 {
    return @as([]const u8, value);
}

fn mayBeMask(comptime T: type) u32 {
    return switch (@typeInfo(T)) {
        .optional => mayBeMask(@typeInfo(T).optional.child) | types.MAY_BE_NULL,
        .int, .comptime_int => types.MAY_BE_LONG,
        .float, .comptime_float => types.MAY_BE_DOUBLE,
        .bool => types.MAY_BE_TRUE | types.MAY_BE_FALSE,
        .pointer => if (isSliceOfU8(T))
            types.MAY_BE_STRING
        else if (isArrayPtr(T))
            types.MAY_BE_ARRAY
        else if (isObjectPtr(T))
            types.MAY_BE_OBJECT
        else if (isRawZval(T))
            0
        else
            0,
        else => 0,
    };
}

const arg_name: [*:0]const u8 = "arg";

/// Normalized per-param descriptor (positional, keyed by handler-param index).
const ArgOpt = struct {
    optional: bool = false,
    by_ref: bool = false,
    variadic: bool = false,
    default: ?[]const u8 = null,
};

/// Renders the `.default` literal of a per-param descriptor as text, or null.
fn renderDefault(comptime opt: anytype, comptime has_default: bool) ?[]const u8 {
    if (!has_default) return null;
    return textOf(@field(opt, "default"));
}

/// The default text for an optional/by-ref param composed with the `ArgOpt`
/// `opt`; compile error if the descriptor omitted `.default`.
fn requiredDefault(comptime opt: ArgOpt, comptime what: []const u8) []const u8 {
    return opt.default orelse @compileError(what ++ " parameter requires a .default literal");
}

/// The normalized descriptor for handler param `i`, or null when `md.params`
/// omits it (positional array).
fn paramOptAt(comptime md: anytype, comptime i: usize) ?ArgOpt {
    const P = @TypeOf(md.params);
    if (@typeInfo(P) != .array) return null;
    if (i >= @typeInfo(P).array.len) return null;
    const opt = md.params[i];
    const has_def = @hasField(@TypeOf(opt), "default");
    return .{
        .optional = if (@hasField(@TypeOf(opt), "optional")) opt.optional else false,
        .by_ref = if (@hasField(@TypeOf(opt), "by_ref")) opt.by_ref else false,
        .variadic = if (@hasField(@TypeOf(opt), "variadic")) opt.variadic else false,
        .default = renderDefault(opt, has_def),
    };
}

fn textOf(comptime value: anytype) []const u8 {
    const V = @TypeOf(value);
    return switch (@typeInfo(V)) {
        .int, .comptime_int => std.fmt.comptimePrint("{d}", .{value}),
        .float, .comptime_float => std.fmt.comptimePrint("{d}", .{value}),
        .bool => if (value) "true" else "false",
        .pointer => if (comptime isStringLike(V)) coerceSlice(value) else @compileError("unsupported default"),
        else => @compileError("unsupported default"),
    };
}

/// A statically-stored default-value string (comptime literal).
fn textZ(comptime s: []const u8) [*:0]const u8 {
    @setEvalBranchQuota(1000000);
    comptime var buf: [s.len + 1:0]u8 = undefined;
    buf[0..s.len].* = s.*;
    buf[s.len] = 0;
    return &buf;
}

/// The arg-info block for a method: `[0]` is the return entry whose `.name`
/// carries the required-minimum marker; `[1..=total]` are the parameters.
fn buildArgInfo(
    comptime md: anytype,
    comptime php_name: []const u8,
) blk: {
    const fn_info = @typeInfo(mdFnType(md)).@"fn";
    const has_self = !isSignature(md);
    break :blk [fn_info.params.len - @as(usize, @intFromBool(has_self)) + 1]module.zend_internal_arg_info;
} {
    const fn_info = @typeInfo(mdFnType(md)).@"fn";
    const has_self = !isSignature(md);
    const start: usize = @intFromBool(has_self);
    const total = fn_info.params.len - start;
    const is_ctor = std.mem.eql(u8, php_name, "__construct");
    const ret_type = fn_info.return_type orelse void;

    comptime var required: usize = 0;
    inline for (fn_info.params[start..], 0..) |_, i| {
        const opt = comptime paramOptAt(md, i) orelse ArgOpt{};
        if (!opt.optional and !opt.variadic) required += 1;
    }
    // Required-minimum marker: `-1` iff required == total.
    const marker: [*:0]const u8 = if (required == total)
        module.RETURN_INFO_MARKER
    else
        @ptrFromInt(required);

    comptime var info: [total + 1]module.zend_internal_arg_info = undefined;
    info[0] = module.returnInfoNamed(
        marker,
        if (is_ctor) 0 else if (ret_type == void) 0 else mayBeMask(ret_type),
    );

    inline for (fn_info.params[start..], 0..) |p, i| {
        const opt = comptime paramOptAt(md, i) orelse ArgOpt{};
        const mask = mayBeMask(p.type orelse void);
        const nm: [*:0]const u8 = arg_name;
        const optional = opt.optional;
        const by_ref = opt.by_ref;
        const variadic = opt.variadic;

        if (variadic and i != total - 1) {
            @compileError("variadic parameter must be the last parameter");
        }

        if (variadic and by_ref) {
            info[i + 1] = module.paramInfoVariadicByRef(nm, mask);
        } else if (variadic) {
            info[i + 1] = module.paramInfoVariadic(nm, mask);
        } else if (by_ref and optional) {
            info[i + 1] = module.paramInfoByRefOptional(nm, mask, textZ(requiredDefault(opt, "by_ref+optional")));
        } else if (by_ref) {
            info[i + 1] = module.paramInfoByRef(nm, mask);
        } else if (optional) {
            info[i + 1] = module.paramInfoOptional(nm, mask, textZ(requiredDefault(opt, "optional")));
        } else {
            info[i + 1] = module.paramInfo(nm, mask);
        }
    }
    return info;
}

fn defaultOf(comptime T: type) T {
    return switch (@typeInfo(T)) {
        .optional => null,
        .int, .comptime_int => 0,
        .float, .comptime_float => 0,
        .bool => false,
        .pointer => if (comptime isSliceOfU8(T))
            ""
        else if (comptime isRawZval(T))
            @ptrCast(&undefined_zval)
        else
            @as(T, @ptrFromInt(0)), // array/object: caller must guard null
        else => unreachable,
    };
}

var undefined_zval: zval = std.mem.zeroes(zval);

fn readParam(p: params.Param, comptime T: type) ?T {
    return switch (@typeInfo(T)) {
        .optional => if (p.paramType() == .null or p.paramType() == .undef)
            null
        else
            readParam(p, @typeInfo(T).optional.child),
        .int => if (p.toLong()) |v| @intCast(v) else null,
        .float => p.toDouble(),
        .bool => p.toBool(),
        .pointer => if (comptime isSliceOfU8(T))
            p.toString()
        else if (comptime isArrayPtr(T))
            p.toArray()
        else if (comptime isObjectPtr(T))
            p.toObject()
        else if (comptime isRawZval(T))
            p.raw()
        else
            null,
        else => null,
    };
}

fn argOf(execute_data: ?*zend_execute_data, comptime i: usize, comptime T: type) T {
    if (execute_data == null) return defaultOf(T);
    if (params.getArgCount(execute_data) < i) return defaultOf(T);
    const p = params.getArg(execute_data, i) orelse return defaultOf(T);
    if (readParam(p, T)) |v| return v;
    return defaultOf(T);
}

fn readZval(p: *const zval, comptime T: type) ?T {
    return switch (@typeInfo(T)) {
        .optional => if (zval_mod.getType(p) == types.IS_NULL or zval_mod.getType(p) == types.IS_UNDEF)
            null
        else
            readZval(p, @typeInfo(T).optional.child),
        .int => if (zval_mod.getType(p) == types.IS_LONG)
            @intCast(p.value.lval)
        else
            null,
        .float => if (zval_mod.getType(p) == types.IS_DOUBLE) p.value.dval else null,
        .bool => switch (zval_mod.getType(p)) {
            types.IS_TRUE => true,
            types.IS_FALSE => false,
            else => null,
        },
        .pointer => if (comptime isSliceOfU8(T)) blk: {
            if (zval_mod.getType(p) != types.IS_STRING) break :blk null;
            const str = p.value.str orelse break :blk null;
            break :blk string.slice(str);
        } else if (comptime isRawZval(T)) @constCast(p) else null,
        else => null,
    };
}

fn writeScalar(zv: *zval, value: anytype) void {
    const V = @TypeOf(value);
    switch (@typeInfo(V)) {
        .optional => if (value) |inner| writeScalar(zv, inner) else zval_mod.setNull(zv),
        .int, .comptime_int => zval_mod.setLong(zv, @intCast(value)),
        .float, .comptime_float => zval_mod.setDouble(zv, value),
        .bool => if (value) zval_mod.setTrue(zv) else zval_mod.setFalse(zv),
        .pointer => if (comptime isStringLike(V)) zval_mod.setString(zv, coerceSlice(value)),
        else => @compileError("unsupported property value type"),
    }
}

fn writeReturn(return_value: ?*zval, value: anytype) void {
    const rv = return_value orelse return;
    const V = @TypeOf(value);
    switch (@typeInfo(V)) {
        .void => zval_mod.setNull(rv),
        .optional => if (value) |inner| writeReturn(return_value, inner) else zval_mod.setNull(rv),
        .int, .comptime_int => zval_mod.setLong(rv, @intCast(value)),
        .float, .comptime_float => zval_mod.setDouble(rv, value),
        .bool => if (value) zval_mod.setTrue(rv) else zval_mod.setFalse(rv),
        .pointer => if (comptime isStringLike(V))
            zval_mod.setString(rv, coerceSlice(value))
        else if (comptime isRawZval(V))
            zval_mod.copy(rv, value)
        else
            @compileError("unsupported return type"),
        else => @compileError("unsupported return type"),
    }
}

/// Appends bytes into `rv` as a refcounted string. `append` grows the backing
/// `zend_string`; `finish` writes the bound `return_value` zval. This is the
/// "builder writes return_value, no manual type_info" path for `greet`-style
/// string returns.
const StringWriter = struct {
    rv: ?*zval,
    data: *types.zend_string,
    used: usize,

    pub fn append(self: *StringWriter, s: []const u8) void {
        const need = self.used + s.len;
        if (need > self.data.len) {
            const new_cap = (self.data.len * 2) + s.len;
            const grown = string.alloc(new_cap);
            const dst: [*]u8 = @ptrCast(&grown.val[0]);
            const src: [*]const u8 = @ptrCast(&self.data.val[0]);
            @memcpy(dst[0..self.used], src[0..self.used]);
            string.free(self.data);
            self.data = grown;
        }
        const dst: [*]u8 = @ptrCast(&self.data.val[0]);
        @memcpy(dst[self.used .. self.used + s.len], s);
        self.used += s.len;
    }

    pub fn finish(self: *StringWriter) void {
        const rv = self.rv orelse return;
        self.data.len = self.used;
        rv.value.str = self.data;
        rv.u1.type_info = zval_mod.typeInfo(types.IS_STRING, zval_mod.Z_TYPE_FLAG_REFCOUNTED);
    }
};

fn buildSelf(
    execute_data: ?*zend_execute_data,
    return_value: ?*zval,
    comptime is_static: bool,
    comptime SelfT: type,
    comptime ce_storage: *const *zend_class_entry,
) SelfT {
    return SelfT.build(execute_data, return_value, is_static, ce_storage);
}

fn invoke(
    comptime md: anytype,
    self_arg: anytype,
    execute_data: ?*zend_execute_data,
) (@typeInfo(@TypeOf(md.fn_ptr)).@"fn".return_type orelse void) {
    const fn_info = @typeInfo(@TypeOf(md.fn_ptr)).@"fn";
    const n = fn_info.params.len;
    comptime var arg_types: [n]type = undefined;
    arg_types[0] = @TypeOf(self_arg);
    inline for (fn_info.params[1..], 0..) |p, i| {
        arg_types[i + 1] = p.type orelse void;
    }
    const ArgTuple = std.meta.Tuple(&arg_types);
    var args: ArgTuple = undefined;
    args[0] = self_arg;
    inline for (fn_info.params[1..], 0..) |p, i| {
        args[i + 1] = argOf(execute_data, i + 1, p.type orelse void);
    }
    return @call(.auto, md.fn_ptr, args);
}

/// A method wrapper: fixed C handler signature backed by the class's
/// encapsulated `_ce` slot (for static handlers) and the per-class `Self`.
fn MethodWrapper(
    comptime md: anytype,
    comptime php_name: []const u8,
    comptime SelfT: type,
    comptime ce_storage: *const *zend_class_entry,
) type {
    return struct {
        const name_storage = blk: {
            var buf: [php_name.len + 1:0]u8 = undefined;
            @memcpy(buf[0..php_name.len], php_name);
            buf[php_name.len] = 0;
            break :blk buf;
        };
        pub const name_z: [*:0]const u8 = &name_storage;
        pub const arg_info = buildArgInfo(md, php_name);
        pub const flags = if (md.static) class.ZEND_ACC_STATIC | md.visibility else md.visibility;

        pub fn call(execute_data: ?*zend_execute_data, return_value: ?*zval) callconv(.c) void {
            const self = buildSelf(execute_data, return_value, md.static, SelfT, ce_storage);
            const fn_info = @typeInfo(@TypeOf(md.fn_ptr)).@"fn";
            const ret = fn_info.return_type orelse void;
            if (ret == void) {
                _ = invoke(md, self, execute_data);
            } else {
                writeReturn(return_value, invoke(md, self, execute_data));
            }
        }
    };
}

/// A signature-only wrapper: no C handler, arg-info only, flagged abstract.
/// Used for interface method declarations.
fn SignatureWrapper(comptime md: anytype, comptime php_name: []const u8) type {
    return struct {
        const name_storage = blk: {
            var buf: [php_name.len + 1:0]u8 = undefined;
            @memcpy(buf[0..php_name.len], php_name);
            buf[php_name.len] = 0;
            break :blk buf;
        };
        pub const name_z: [*:0]const u8 = &name_storage;
        pub const arg_info = buildArgInfo(md, php_name);
        pub const flags = class.ZEND_ACC_ABSTRACT | md.visibility;
    };
}

/// Builds the term-nated `zend_function_entry` array for a spec's methods.
fn classMethods(
    comptime methods: anytype,
    comptime SelfT: type,
    comptime ce_storage: *const *zend_class_entry,
) type {
    const M = @TypeOf(methods);
    const count = std.meta.fields(M).len;
    return struct {
        pub const entries = blk: {
            var arr: [count + 1]module.zend_function_entry = undefined;
            for (std.meta.fields(M), 0..) |f, i| {
                const md = @field(methods, f.name);
                if (isSignature(md)) {
                    const W = SignatureWrapper(md, f.name);
                    arr[i] = .{
                        .fname = W.name_z,
                        .handler = null,
                        .arg_info = &W.arg_info,
                        .num_args = @intCast(W.arg_info.len - 1), // TOTAL params
                        .flags = W.flags,
                    };
                } else {
                    const W = MethodWrapper(md, f.name, SelfT, ce_storage);
                    arr[i] = .{
                        .fname = W.name_z,
                        .handler = &W.call,
                        .arg_info = &W.arg_info,
                        .num_args = @intCast(W.arg_info.len - 1), // TOTAL params (required marker in [0])
                        .flags = W.flags,
                    };
                }
            }
            arr[count] = module.function_entry_end;
            break :blk arr;
        };
    };
}

fn buildDefaultZval(comptime value: anytype, out: *zval) void {
    const V = @TypeOf(value);
    switch (@typeInfo(V)) {
        .int, .comptime_int => zval_mod.setLong(out, @intCast(value)),
        .float, .comptime_float => zval_mod.setDouble(out, value),
        .bool => if (value) zval_mod.setTrue(out) else zval_mod.setFalse(out),
        .pointer => if (comptime isStringLike(V))
            zval_mod.setInternedString(out, coerceSlice(value))
        else
            @compileError("unsupported default value type"),
        else => @compileError("unsupported default value type"),
    }
}

fn classFlagsMask(comptime spec: anytype) u32 {
    const T = @TypeOf(spec);
    var f: u32 = 0;
    if (comptime @hasField(T, "flags")) {
        const F = @TypeOf(spec.flags);
        if (comptime @hasField(F, "final")) {
            if (spec.flags.final) f |= class.ZEND_ACC_FINAL;
        }
        if (comptime @hasField(F, "abstract")) {
            if (spec.flags.abstract) f |= class.ZEND_ACC_ABSTRACT;
        }
    }
    return f;
}

/// The parent type from the spec, or null when `.parent` is unset/`null`.
fn parentTypeOf(comptime spec: anytype) ?type {
    const T = @TypeOf(spec);
    if (comptime !@hasField(T, "parent")) return null;
    const parent = comptime @field(spec, "parent");
    if (comptime @typeInfo(@TypeOf(parent)) == .null) return null;
    return parent;
}

/// True when `.implements` is a (possibly empty) comptime array/tuple of types.
/// Both `.[]const type`/`[_]type` and the anonymous tuple `.{ A, B }` are
/// accepted.
fn implementsIsList(comptime spec: anytype) bool {
    const v = comptime spec.implements;
    const info = @typeInfo(@TypeOf(v));
    return info == .array or (info == .@"struct" and
        std.meta.fields(@TypeOf(v)).len > 0 and
        std.meta.fields(@TypeOf(v))[0].type == type);
}

/// Declares a class type from a declarative spec. `register()` is one-shot
/// (`assert(!_registered)`) and returns `Registration{ .ce }`; the internal
/// `_ce` slot stays encapsulated to back the fixed-C-signature static method
/// handlers. `this_ce` is intentionally NOT part of the public API.
pub fn Class(comptime spec: anytype) type {
    return struct {
        pub var _ce: *zend_class_entry = undefined;
        pub var _registered = false;
        pub const spec_name = spec.name;

        const has_consts = @hasField(@TypeOf(spec), "consts");
        const has_implements = @hasField(@TypeOf(spec), "implements");
        const has_props = @hasField(@TypeOf(spec), "props");
        const has_static_props = @hasField(@TypeOf(spec), "static_props");
        const parent_type: ?type = parentTypeOf(spec);
        const has_parent = parent_type != null;

        /// True when `key` names a static property; `@compileError` if undeclared.
        /// Drives the comptime-key check in `Self.prop`.
        fn propIsStatic(comptime s: anytype, comptime key: []const u8) bool {
            if (@hasField(@TypeOf(s), "props") and @hasField(@TypeOf(s.props), key)) return false;
            if (@hasField(@TypeOf(s), "static_props") and @hasField(@TypeOf(s.static_props), key)) {
                return true;
            }
            @compileError("undeclared property '" ++ key ++ "' on class " ++ s.name);
        }

        /// Per-class view handed to method handlers.
        pub const Self = struct {
            ce: *zend_class_entry,
            obj: ?*zend_object,
            return_value: ?*zval,

            pub fn build(
                execute_data: ?*zend_execute_data,
                return_value: ?*zval,
                comptime is_static: bool,
                comptime ce_storage: *const *zend_class_entry,
            ) Self {
                if (is_static) {
                    return .{ .ce = ce_storage.*, .obj = null, .return_value = return_value };
                }
                const ed = execute_data orelse
                    return .{ .ce = ce_storage.*, .obj = null, .return_value = return_value };
                if (object.getObject(&ed.this)) |obj| {
                    return .{ .ce = obj.ce orelse ce_storage.*, .obj = obj, .return_value = return_value };
                }
                return .{ .ce = ce_storage.*, .obj = null, .return_value = return_value };
            }

            /// The active instance object (`$this`), or null for static calls.
            pub fn this(self: Self) ?*zend_object {
                return self.obj;
            }

            /// Comptime-key-checked property view. Undeclared keys are a
            /// `@compileError`. `.get/.set` route to instance or static storage;
            /// `.ptr()` is static-only in v1.
            pub fn prop(self: Self, comptime key: []const u8) PropView(key, propIsStatic(spec, key)) {
                return .{ .host = self };
            }

            /// A string writer bound to this method's `return_value`; use
            /// `.append`/`.finish`, no manual `return_value`/`type_` writes.
            pub fn return_string(self: Self) StringWriter {
                return .{ .rv = self.return_value, .data = str_mod.alloc(16), .used = 0 };
            }

            /// Alias of `return_string` (both write `return_value`).
            pub fn string(self: Self) StringWriter {
                return self.return_string();
            }
        };

        /// A typed, comptime-key-checked property view. Keyed by property name
        /// and whether it is static (both known at comptime), so `.ptr()` can be
        /// statically restricted.
        fn PropView(comptime key: []const u8, comptime is_static: bool) type {
            return struct {
                host: Self,

                pub fn get(self: @This(), comptime T: type) ?T {
                    const p = self.raw() orelse return null;
                    return readZval(p, T);
                }

                pub fn set(self: @This(), value: anytype) void {
                    var zv: zval = undefined;
                    writeScalar(&zv, value);
                    if (is_static) {
                        ffi.zend_update_static_property(self.host.ce, key.ptr, key.len, &zv);
                    } else {
                        const obj = self.host.obj orelse @panic("instance prop on null $this");
                        ffi.zend_update_property(obj.ce, obj, key.ptr, key.len, &zv);
                    }
                }

                /// Borrowed in-place pointer (static storage only in v1).
                pub fn ptr(self: @This()) *zval {
                    if (!is_static) {
                        comptime @compileError("prop('" ++ key ++ "').ptr() is static-only in v1");
                    }
                    return ffi.zend_read_static_property(self.host.ce, key.ptr, key.len, true) orelse
                        @panic("static property unset before ptr()");
                }

                fn raw(self: @This()) ?*const zval {
                    if (is_static) {
                        return ffi.zend_read_static_property(self.host.ce, key.ptr, key.len, true);
                    }
                    const obj = self.host.obj orelse return null;
                    var scratch: zval = undefined;
                    return ffi.zend_read_property(obj.ce, obj, key.ptr, key.len, true, &scratch);
                }
            };
        }

        const methods_built = classMethods(spec.methods, Self, &_ce);
        const flags: u32 = classFlagsMask(spec);

        /// Result of a successful one-shot registration.
        pub const Registration = struct {
            ce: *zend_class_entry,
        };

        pub fn register(module_entry: *const module.zend_module_entry) Registration {
            std.debug.assert(!_registered); // one-shot guard

            const parent_ce: ?*zend_class_entry = if (has_parent) blk: {
                const P = comptime parent_type.?;
                std.debug.assert(P._registered); // parent-before-child ordering
                break :blk P._ce;
            } else null;

            _ce = class.registerClassFlags(spec_name, &methods_built.entries, parent_ce, flags);
            class.setModule(_ce, module_entry);

            if (has_implements and comptime implementsIsList(spec)) {
                inline for (std.meta.fields(@TypeOf(spec.implements))) |f| {
                    const I = @field(spec.implements, f.name);
                    std.debug.assert(I._registered); // interface-first ordering
                    class.implementInterface(_ce, I._ce);
                }
            }

            if (has_props) {
                inline for (std.meta.fields(@TypeOf(spec.props))) |f| {
                    var zv: zval = undefined;
                    buildDefaultZval(@field(spec.props, f.name), &zv);
                    class.declareProperty(_ce, f.name, &zv, class.ZEND_ACC_PUBLIC);
                }
            }
            if (has_static_props) {
                inline for (std.meta.fields(@TypeOf(spec.static_props))) |f| {
                    var zv: zval = undefined;
                    buildDefaultZval(@field(spec.static_props, f.name), &zv);
                    class.declareProperty(_ce, f.name, &zv, class.ZEND_ACC_PUBLIC | class.ZEND_ACC_STATIC);
                }
            }
            if (has_consts) {
                inline for (std.meta.fields(@TypeOf(spec.consts))) |f| {
                    var zv: zval = undefined;
                    buildDefaultZval(@field(spec.consts, f.name), &zv);
                    class.declareClassConstant(_ce, f.name, &zv, class.ZEND_ACC_PUBLIC);
                }
            }

            _registered = true;
            return .{ .ce = _ce };
        }
    };
}

/// Declares an interface type. `register()` runs `class.registerInterface`
/// and is one-shot, mirroring `Class`. Registers a type carrying `_ce` that
/// `Class.implements` elements reference.
pub fn Interface(comptime iface_name: []const u8, comptime spec: anytype) type {
    return struct {
        pub var _ce: *zend_class_entry = undefined;
        pub var _registered = false;
        pub const spec_name = iface_name;

        // Interfaces carry no per-class handler view; a minimal Self is used
        // only to let `classMethods` build an (empty) method table.
        pub const Self = struct {
            pub fn build(
                execute_data: ?*zend_execute_data,
                return_value: ?*zval,
                comptime is_static: bool,
                comptime ce_storage: *const *zend_class_entry,
            ) Self {
                _ = execute_data;
                _ = return_value;
                _ = is_static;
                _ = ce_storage;
                return .{};
            }
        };

        const IFACE_METHODS = if (@hasField(@TypeOf(spec), "methods")) spec.methods else .{};
        comptime {
            for (std.meta.fields(@TypeOf(IFACE_METHODS))) |f| {
                if (!isSignature(@field(IFACE_METHODS, f.name))) {
                    @compileError("interface method '" ++ f.name ++ "' must use defs.signature(...): " ++ "interfaces carry no body (use defs.method on the implementing Class)");
                }
            }
        }

        const methods_built = classMethods(IFACE_METHODS, Self, &_ce);

        pub fn register(module_entry: *const module.zend_module_entry) *zend_class_entry {
            std.debug.assert(!_registered); // one-shot guard
            _ce = class.registerInterface(spec_name, &methods_built.entries);
            class.setModule(_ce, module_entry);
            _registered = true;
            return _ce;
        }
    };
}
