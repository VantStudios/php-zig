const builtin = @import("builtin");

const types = @import("types.zig");
pub const zval = types.zval;
pub const zend_array = types.zend_array;
pub const zend_execute_data = types.zend_execute_data;

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

pub const Param = struct {
    zv: *zval,

    pub fn paramType(self: Param) ParamType {
        return switch (self.zv.u1.v.type) {
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
        if (self.zv.u1.v.type != types.IS_LONG) return null;
        return self.zv.value.lval;
    }

    pub fn toDouble(self: Param) ?f64 {
        if (self.zv.u1.v.type != types.IS_DOUBLE) return null;
        return self.zv.value.dval;
    }

    pub fn toBool(self: Param) ?bool {
        return switch (self.zv.u1.v.type) {
            types.IS_TRUE => true,
            types.IS_FALSE => false,
            else => null,
        };
    }

    pub fn toString(self: Param) ?[]const u8 {
        if (self.zv.u1.v.type != types.IS_STRING) return null;
        const str = self.zv.value.str orelse return null;
        const ptr: [*]const u8 = @ptrCast(&str.val[0]);
        return ptr[0..str.len];
    }

    pub fn toArray(self: Param) ?*zend_array {
        if (self.zv.u1.v.type != types.IS_ARRAY) return null;
        return self.zv.value.arr;
    }

    pub fn raw(self: Param) *zval {
        return self.zv;
    }
};

pub fn getArg(execute_data: ?*zend_execute_data, n: usize) ?Param {
    const ed = execute_data orelse return null;
    const base: [*]u8 = @ptrCast(ed);
    const offset = @sizeOf(zend_execute_data_full);
    const args: [*]zval = @ptrCast(@alignCast(base + offset));
    return Param{ .zv = &args[n - 1] };
}

pub fn getArgCount(execute_data: ?*zend_execute_data) u32 {
    const ed: *zend_execute_data_full = @ptrCast(@alignCast(execute_data orelse return 0));
    return ed.this.u2.num_args;
}
