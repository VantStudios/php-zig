const std = @import("std");

pub const CONST_CS: c_int = 0;
pub const CONST_PERSISTENT: c_int = 1;

extern fn zend_register_long_constant(
    name: [*:0]const u8,
    name_len: usize,
    lval: i64,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;

extern fn zend_register_double_constant(
    name: [*:0]const u8,
    name_len: usize,
    dval: f64,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;

extern fn zend_register_string_constant(
    name: [*:0]const u8,
    name_len: usize,
    strval: [*:0]const u8,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;

extern fn zend_register_bool_constant(
    name: [*:0]const u8,
    name_len: usize,
    bval: bool,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;

pub fn registerLong(name: [*:0]const u8, value: i64, module_number: c_int) void {
    _ = zend_register_long_constant(name, std.mem.len(name), value, CONST_CS | CONST_PERSISTENT, module_number);
}

pub fn registerDouble(name: [*:0]const u8, value: f64, module_number: c_int) void {
    _ = zend_register_double_constant(name, std.mem.len(name), value, CONST_CS | CONST_PERSISTENT, module_number);
}

pub fn registerString(name: [*:0]const u8, value: [*:0]const u8, module_number: c_int) void {
    _ = zend_register_string_constant(name, std.mem.len(name), value, CONST_CS | CONST_PERSISTENT, module_number);
}

pub fn registerBool(name: [*:0]const u8, value: bool, module_number: c_int) void {
    _ = zend_register_bool_constant(name, std.mem.len(name), value, CONST_CS | CONST_PERSISTENT, module_number);
}
