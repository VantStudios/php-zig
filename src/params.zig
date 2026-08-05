const string = @import("string.zig");
const zval_mod = @import("zval.zig");

const types = @import("types.zig");
pub const zval = types.zval;
pub const zend_array = types.zend_array;
pub const zend_execute_data = types.zend_execute_data;
pub const zend_reference = types.zend_reference;

/// The `zend_execute_data` struct (PHP 8.0 ZTS). The type is opaque in
/// `types.zig`; this full layout is used only to compute argument offsets.
///
/// Zend stores a call's argument zvals immediately after the
/// `zend_execute_data` struct in the same allocation, so arg N (1-based) is
/// found at `execute_data + @sizeOf(zend_execute_data_full) + (N-1)`.
pub const zend_execute_data_full = extern struct {
    opline: ?*anyopaque,
    call: ?*anyopaque,
    return_value: ?*zval,
    func: ?*anyopaque,
    this: zval,
    prev_execute_data: ?*anyopaque,
    symbol_table: ?*anyopaque,
    run_time_cache: ?*anyopaque,
    extra_named_params: ?*anyopaque,
};

pub const ParamType = enum {
    undef,
    null,
    bool,
    long,
    double,
    string,
    array,
    object,
    unknown,
};

/// A borrowed view of an argument zval. Does not own any references.
pub const Param = struct {
    zv: *zval,

    pub fn paramType(self: Param) ParamType {
        return switch (zval_mod.getType(self.zv)) {
            types.IS_UNDEF => .undef,
            types.IS_NULL => .null,
            types.IS_FALSE, types.IS_TRUE => .bool,
            types.IS_LONG => .long,
            types.IS_DOUBLE => .double,
            types.IS_STRING => .string,
            types.IS_ARRAY => .array,
            types.IS_OBJECT => .object,
            else => .unknown,
        };
    }

    pub fn toLong(self: Param) ?i64 {
        if (zval_mod.getType(self.zv) != types.IS_LONG) return null;
        return self.zv.value.lval;
    }

    pub fn toDouble(self: Param) ?f64 {
        if (zval_mod.getType(self.zv) != types.IS_DOUBLE) return null;
        return self.zv.value.dval;
    }

    pub fn toBool(self: Param) ?bool {
        return switch (zval_mod.getType(self.zv)) {
            types.IS_TRUE => true,
            types.IS_FALSE => false,
            else => null,
        };
    }

    pub fn toString(self: Param) ?[]const u8 {
        if (zval_mod.getType(self.zv) != types.IS_STRING) return null;
        const str = self.zv.value.str orelse return null;
        return string.slice(str);
    }

    pub fn toArray(self: Param) ?*zend_array {
        if (zval_mod.getType(self.zv) != types.IS_ARRAY) return null;
        return self.zv.value.arr;
    }

    /// True when the argument was passed by reference (`&$arg`).
    pub fn isRef(self: Param) bool {
        return zval_mod.isRef(self.zv);
    }

    /// Pointer to the zval held by a by-ref argument (only when `isRef()`).
    pub fn deref(self: Param) *zval {
        return zval_mod.derefValue(self.zv);
    }

    /// The `zend_reference` box for a by-ref argument (only when `isRef()`).
    pub fn toRef(self: Param) ?*zend_reference {
        if (!zval_mod.isRef(self.zv)) return null;
        return self.zv.value.ref;
    }

    pub fn raw(self: Param) *zval {
        return self.zv;
    }
};

/// Returns argument `n` (1-based) from `execute_data`, or null.
pub fn getArg(execute_data: ?*zend_execute_data, n: usize) ?Param {
    const ed = execute_data orelse return null;
    const base: [*]u8 = @ptrCast(ed);
    const offset = @sizeOf(zend_execute_data_full);
    const args: [*]zval = @ptrCast(@alignCast(base + offset));
    return Param{ .zv = &args[n - 1] };
}

/// Returns the number of arguments passed to the current function.
pub fn getArgCount(execute_data: ?*zend_execute_data) u32 {
    const ed: *zend_execute_data_full = @ptrCast(@alignCast(execute_data orelse return 0));
    return ed.this.u2.num_args;
}
