const string = @import("string.zig");
const zval_mod = @import("zval.zig");

const types = @import("types.zig");
const zval = types.zval;
const zend_array = types.zend_array;
const zend_execute_data = types.zend_execute_data;
const zend_reference = types.zend_reference;

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

    pub fn toObject(self: Param) ?*types.zend_object {
        if (zval_mod.getType(self.zv) != types.IS_OBJECT) return null;
        const obj = self.zv.value.obj orelse return null;
        return @ptrCast(@alignCast(obj));
    }

    /// True when the argument was passed by reference.
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

/// Returns argument `n` (1-based) from `execute_data`, or null. Arguments sit
/// immediately after the struct in the same allocation, so arg N lives at
/// `execute_data + @sizeOf(zend_execute_data) + (N-1)`.
pub fn getArg(execute_data: ?*zend_execute_data, n: usize) ?Param {
    const ed = execute_data orelse return null;
    const base: [*]u8 = @ptrCast(ed);
    const offset = @sizeOf(zend_execute_data);
    const args: [*]zval = @ptrCast(@alignCast(base + offset));
    return Param{ .zv = &args[n - 1] };
}

pub fn getArgCount(execute_data: ?*zend_execute_data) u32 {
    const ed: *zend_execute_data = execute_data orelse return 0;
    return ed.this.u2.num_args;
}
