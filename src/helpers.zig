const std = @import("std");
const builtin = @import("builtin");

const types = @import("types.zig");
pub const zval = types.zval;
pub const zend_array = types.zend_array;
pub const zend_string = types.zend_string;

pub const _zend_new_array = if (builtin.os.tag == .windows)
    @extern(*const fn (u32) callconv(.c) ?*zend_array, .{ .name = "_zend_new_array@@8" })
else
    @extern(*const fn (u32) callconv(.c) ?*zend_array, .{ .name = "_zend_new_array" });

pub extern fn add_next_index_string(arg: ?*zval, str: [*:0]const u8) c_int;
pub extern fn add_next_index_long(arg: ?*zval, val: i64) c_int;
pub extern fn add_next_index_double(arg: ?*zval, val: f64) c_int;
pub extern fn add_next_index_bool(arg: ?*zval, val: c_int) c_int;
pub extern fn add_next_index_null(arg: ?*zval) c_int;

pub const zend_hash_next_index_insert = if (builtin.os.tag == .windows)
    @extern(*const fn (?*types.zend_array, ?*zval) callconv(.c) ?*zval, .{ .name = "zend_hash_next_index_insert@@16" })
else
    @extern(*const fn (?*types.zend_array, ?*zval) callconv(.c) ?*zval, .{ .name = "zend_hash_next_index_insert" });

const zend_hash_str_update = if (builtin.os.tag == .windows)
    @extern(*const fn (?*types.zend_array, [*:0]const u8, usize, ?*zval) callconv(.c) ?*zval, .{ .name = "zend_hash_str_update@@32" })
else
    @extern(*const fn (?*types.zend_array, [*:0]const u8, usize, ?*zval) callconv(.c) ?*zval, .{ .name = "zend_hash_str_update" });

pub extern fn add_assoc_string_ex(arg: ?*zval, key: [*:0]const u8, key_len: usize, str: [*:0]const u8) c_int;
pub extern fn add_assoc_long_ex(arg: ?*zval, key: [*:0]const u8, key_len: usize, val: i64) c_int;
pub extern fn add_assoc_double_ex(arg: ?*zval, key: [*:0]const u8, key_len: usize, val: f64) c_int;
pub extern fn add_assoc_bool_ex(arg: ?*zval, key: [*:0]const u8, key_len: usize, val: c_int) c_int;
pub extern fn add_assoc_null_ex(arg: ?*zval, key: [*:0]const u8, key_len: usize) c_int;
pub extern fn add_assoc_zval_ex(arg: ?*zval, key: [*:0]const u8, key_len: usize, val: ?*zval) c_int;

const _emalloc = if (builtin.os.tag == .windows)
    @extern(*const fn (usize) callconv(.c) ?*anyopaque, .{ .name = "_emalloc@@8" })
else
    @extern(*const fn (usize) callconv(.c) ?*anyopaque, .{ .name = "_emalloc" });

pub fn returnArray(return_value: ?*zval, reserve: u32) void {
    const arr = _zend_new_array(reserve);
    const rv = return_value.?;
    rv.value.arr = arr;
    rv.u1.type_info = types.IS_ARRAY_EX;
}

pub fn returnLong(return_value: ?*zval, val: i64) void {
    const rv = return_value.?;
    rv.value.lval = val;
    rv.u1.type_info = types.IS_LONG;
}

pub fn returnDouble(return_value: ?*zval, val: f64) void {
    const rv = return_value.?;
    rv.value.dval = val;
    rv.u1.type_info = types.IS_DOUBLE;
}

pub fn returnTrue(return_value: ?*zval) void {
    return_value.?.u1.type_info = types.IS_TRUE;
}

pub fn returnFalse(return_value: ?*zval) void {
    return_value.?.u1.type_info = types.IS_FALSE;
}

pub fn returnNull(return_value: ?*zval) void {
    return_value.?.u1.type_info = types.IS_NULL;
}

pub fn returnString(return_value: ?*zval, s: []const u8) void {
    const rv = return_value orelse return;

    const size = @sizeOf(types.zend_string) + s.len;
    const mem = _emalloc(size) orelse return;

    const zstr: *types.zend_string = @ptrCast(@alignCast(mem));
    zstr.gc.refcount = 1;
    zstr.gc.type_info = 0;
    zstr.h = 0;
    zstr.len = s.len;

    const val_ptr: [*]u8 = @ptrCast(&zstr.val[0]);
    @memcpy(val_ptr[0..s.len], s);
    val_ptr[s.len] = 0;

    rv.value.str = zstr;
    rv.u1.type_info = types.IS_STRING_EX;
}

pub fn returnStringZ(return_value: ?*zval, s: [*:0]const u8) void {
    returnString(return_value, std.mem.span(s));
}

pub fn arrayPushString(arr: ?*zval, val: [*:0]const u8) void {
    _ = add_next_index_string(arr, val);
}

pub fn arrayPushLong(arr: ?*zval, val: i64) void {
    _ = add_next_index_long(arr, val);
}

pub fn arrayPushDouble(arr: ?*zval, val: f64) void {
    _ = add_next_index_double(arr, val);
}

pub fn arrayPushBool(arr: ?*zval, val: bool) void {
    _ = add_next_index_bool(arr, if (val) 1 else 0);
}

pub fn arrayPushNull(arr: ?*zval) void {
    _ = add_next_index_null(arr);
}

pub fn newArrayZval(reserve: u32) zval {
    var zv: zval = std.mem.zeroes(zval);
    zv.value.arr = _zend_new_array(reserve);
    zv.u1.type_info = types.IS_ARRAY_EX;
    return zv;
}

pub fn arrayPushArray(parent: ?*zval, child: *zval) void {
    const p = parent orelse return;
    const arr = p.value.arr orelse return;
    if (child.value.arr) |child_arr| {
        child_arr.gc.refcount += 1;
    }
    _ = zend_hash_next_index_insert(arr, child);
}

pub fn arraySetString(arr: ?*zval, key: [*:0]const u8, val: [*:0]const u8) void {
    const key_len = std.mem.len(key);
    _ = add_assoc_string_ex(arr, key, key_len, val);
}

pub fn arraySetLong(arr: ?*zval, key: [*:0]const u8, val: i64) void {
    const key_len = std.mem.len(key);
    _ = add_assoc_long_ex(arr, key, key_len, val);
}

pub fn arraySetDouble(arr: ?*zval, key: [*:0]const u8, val: f64) void {
    const key_len = std.mem.len(key);
    _ = add_assoc_double_ex(arr, key, key_len, val);
}

pub fn arraySetBool(arr: ?*zval, key: [*:0]const u8, val: bool) void {
    const key_len = std.mem.len(key);
    _ = add_assoc_bool_ex(arr, key, key_len, if (val) 1 else 0);
}

pub fn arraySetNull(arr: ?*zval, key: [*:0]const u8) void {
    const key_len = std.mem.len(key);
    _ = add_assoc_null_ex(arr, key, key_len);
}

pub fn arraySetArray(parent: ?*zval, key: [*:0]const u8, child: *zval) void {
    const p = parent orelse return;
    const arr = p.value.arr orelse return;
    if (child.value.arr) |child_arr| {
        child_arr.gc.refcount += 1;
    }
    _ = zend_hash_str_update(arr, key, std.mem.len(key), child);
}
