const std = @import("std");

const ffi = @import("ffi.zig");

const types = @import("types.zig");
const module = @import("module.zig");
const zval = types.zval;
const zend_class_entry = types.zend_class_entry;

// Access/visibility flags (PHP 8.0, Zend/zend_compile.h). Values differ from
// the 8.5 bindgen dump — do not port those. Visibility occupies the low bits.
pub const ZEND_ACC_PUBLIC: u32 = 1 << 0;
pub const ZEND_ACC_PROTECTED: u32 = 1 << 1;
pub const ZEND_ACC_PRIVATE: u32 = 1 << 2;
pub const ZEND_ACC_STATIC: u32 = 1 << 4;
pub const ZEND_ACC_FINAL: u32 = 1 << 5;
pub const ZEND_ACC_ABSTRACT: u32 = 1 << 6;
pub const ZEND_ACC_INTERFACE: u32 = 1 << 0;
pub const ZEND_ACC_CTOR: u32 = 1 << 21;

/// Marks a class entry as "still being built"; required by
/// `zend_register_internal_class` to run the registration path. The engine
/// clears it afterwards.
const ZEND_ACC_RESERVED: u32 = 1 << 29;

/// Registers an internal class with `methods` as its function table and
/// returns the persistent class entry. Mirrors `INIT_CLASS_ENTRY` +
/// `zend_register_internal_class`: the entry is copied by the engine, so the
/// temp struct can live on the stack. The name is interned by registration.
///
/// Call from `module_startup_func`. `methods` is a `zend_function_entry`
/// array terminated by `module.function_entry_end`.
pub fn registerClass(name: []const u8, methods: []const module.zend_function_entry) *zend_class_entry {
    return registerClassFlags(name, methods, null, 0);
}

/// Registers an internal class with an optional parent and class-level flags
/// (`ZEND_ACC_FINAL`/`ZEND_ACC_ABSTRACT`/...). Sets `ce_flags =
/// ZEND_ACC_RESERVED | flags` BEFORE `zend_register_internal_class_ex`; the
/// engine's `do_register_internal_class` ORs the pre-set flags into the
/// registered entry (zend_API.c:2758), so final/abstract survive.
pub fn registerClassFlags(
    name: []const u8,
    methods: []const module.zend_function_entry,
    parent_ce: ?*zend_class_entry,
    flags: u32,
) *zend_class_entry {
    var entry: zend_class_entry = std.mem.zeroes(zend_class_entry);
    entry.type = types.ZEND_INTERNAL_CLASS;
    entry.name = @ptrCast(@alignCast(ffi.zend_string_init_interned(name.ptr, name.len, 1)));
    entry.ce_flags = ZEND_ACC_RESERVED | flags;
    entry.info.internal.builtin_functions = @ptrCast(methods.ptr);

    const raw = if (parent_ce) |p|
        ffi.zend_register_internal_class_ex(&entry, p)
    else
        ffi.zend_register_internal_class(&entry);
    return @ptrCast(@alignCast(raw));
}

/// Registers an internal interface (empty `methods` is fine). Sets
/// `ZEND_ACC_RESERVED | ZEND_ACC_INTERFACE` before
/// `zend_register_internal_interface`; the engine ORs `ZEND_ACC_INTERFACE`
/// itself, so pre-setting it is idempotent.
pub fn registerInterface(name: []const u8, methods: []const module.zend_function_entry) *zend_class_entry {
    var entry: zend_class_entry = std.mem.zeroes(zend_class_entry);
    entry.type = types.ZEND_INTERNAL_CLASS;
    entry.name = @ptrCast(@alignCast(ffi.zend_string_init_interned(name.ptr, name.len, 1)));
    entry.ce_flags = ZEND_ACC_RESERVED | ZEND_ACC_INTERFACE;
    entry.info.internal.builtin_functions = @ptrCast(methods.ptr);

    const raw = ffi.zend_register_internal_interface(&entry) orelse unreachable;
    return @ptrCast(@alignCast(raw));
}

/// Marks `ce` as implementing `iface` (both already registered). The interface
/// must be registered before the implementing class.
pub fn implementInterface(ce: *zend_class_entry, iface: *zend_class_entry) void {
    ffi.zend_do_implement_interface(ce, iface);
}

/// Declares a *typed* property via `zend_declare_typed_property` (PHP 8.0
/// signature, doc_comment BEFORE type_). `name` must be a persistent interned
/// `zend_string`; `doc_comment` may be null. Returns the engine's
/// `zend_property_info` (opaque here).
pub fn declareTypedProperty(
    ce: *zend_class_entry,
    name: *types.zend_string,
    default_value: *const zval,
    access_type: c_int,
    doc_comment: ?*types.zend_string,
    type_: types.zend_type,
) ?*types.zend_property_info {
    return ffi.zend_declare_typed_property(ce, name, @constCast(default_value), access_type, doc_comment, type_);
}

/// Builds a `zend_function_entry` for a class method (like `ZEND_ME`).
/// `arg_info` includes the leading `returnInfo` entry; the parameter count is
/// derived from it (`num_args = len - 1`).
pub fn method(
    fname: [*:0]const u8,
    handler: *const fn (?*types.zend_execute_data, ?*zval) callconv(.c) void,
    arg_info: []const module.zend_internal_arg_info,
    flags: u32,
) module.zend_function_entry {
    return .{
        .fname = fname,
        .handler = handler,
        .arg_info = if (arg_info.len == 0) null else arg_info.ptr,
        .num_args = if (arg_info.len == 0) 0 else @intCast(arg_info.len - 1),
        .flags = flags,
    };
}

/// Declares an instance property with default value `default_value` (copied by
/// the engine). `flags` are visibility bits (`ZEND_ACC_PUBLIC`, ...).
pub fn declareProperty(ce: *zend_class_entry, name: []const u8, default_value: *const zval, flags: u32) void {
    ffi.zend_declare_property(ce, name.ptr, name.len, @constCast(default_value), @intCast(flags));
}

/// Declares a class constant `name = value` (copied by the engine).
pub fn declareClassConstant(ce: *zend_class_entry, name: []const u8, value: *const zval, flags: u32) void {
    ffi.zend_declare_class_constant(ce, name.ptr, name.len, @constCast(value), @intCast(flags));
}

/// Links `ce` back to its owning module entry (used by phpinfo/module dumps).
/// Optional; registration works without it.
pub fn setModule(ce: *zend_class_entry, module_entry: *const module.zend_module_entry) void {
    ce.info.internal.module = @ptrCast(@constCast(module_entry));
}
