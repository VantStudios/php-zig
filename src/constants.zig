const std = @import("std");

const ffi = @import("ffi.zig");

pub const CONST_CS: c_int = 0;
pub const CONST_PERSISTENT: c_int = 1;

pub fn registerLong(name: [*:0]const u8, value: i64, module_number: c_int) void {
    _ = ffi.zend_register_long_constant(
        name,
        std.mem.len(name),
        value,
        CONST_CS | CONST_PERSISTENT,
        module_number,
    );
}

pub fn registerDouble(name: [*:0]const u8, value: f64, module_number: c_int) void {
    _ = ffi.zend_register_double_constant(
        name,
        std.mem.len(name),
        value,
        CONST_CS | CONST_PERSISTENT,
        module_number,
    );
}

pub fn registerString(name: [*:0]const u8, value: [*:0]const u8, module_number: c_int) void {
    _ = ffi.zend_register_string_constant(
        name,
        std.mem.len(name),
        value,
        CONST_CS | CONST_PERSISTENT,
        module_number,
    );
}

pub fn registerBool(name: [*:0]const u8, value: bool, module_number: c_int) void {
    _ = ffi.zend_register_bool_constant(
        name,
        std.mem.len(name),
        value,
        CONST_CS | CONST_PERSISTENT,
        module_number,
    );
}
