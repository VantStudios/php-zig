const std = @import("std");

const hash = @import("hash.zig");
const zval_mod = @import("zval.zig");

const types = @import("types.zig");
pub const zval = types.zval;

// High-level ergonomic layer: thin, nullable wrappers over the low-level
// primitives in `zval.zig`/`hash.zig`. Every function accepts `?*zval` and
// no-ops on null, mirroring the nullable `return_value` PHP passes to
// handlers. Nothing here hides work — each call delegates visibly.

pub fn returnNull(return_value: ?*zval) void {
    if (return_value) |rv| zval_mod.setNull(rv);
}

pub fn returnTrue(return_value: ?*zval) void {
    if (return_value) |rv| zval_mod.setTrue(rv);
}

pub fn returnFalse(return_value: ?*zval) void {
    if (return_value) |rv| zval_mod.setFalse(rv);
}

pub fn returnLong(return_value: ?*zval, val: i64) void {
    if (return_value) |rv| zval_mod.setLong(rv, val);
}

pub fn returnDouble(return_value: ?*zval, val: f64) void {
    if (return_value) |rv| zval_mod.setDouble(rv, val);
}

/// Returns a binary-safe string.
pub fn returnString(return_value: ?*zval, s: []const u8) void {
    if (return_value) |rv| zval_mod.setString(rv, s);
}

/// Returns a null-terminated string.
pub fn returnStringZ(return_value: ?*zval, s: [*:0]const u8) void {
    returnString(return_value, std.mem.span(s));
}

pub fn returnArray(return_value: ?*zval, reserve: u32) void {
    if (return_value) |rv| zval_mod.setArray(rv, reserve);
}

pub fn arrayPushNull(arr: ?*zval) void {
    if (arr) |a| hash.pushNull(a);
}

pub fn arrayPushBool(arr: ?*zval, val: bool) void {
    if (arr) |a| hash.pushBool(a, val);
}

pub fn arrayPushLong(arr: ?*zval, val: i64) void {
    if (arr) |a| hash.pushLong(a, val);
}

pub fn arrayPushDouble(arr: ?*zval, val: f64) void {
    if (arr) |a| hash.pushDouble(a, val);
}

pub fn arrayPushString(arr: ?*zval, val: []const u8) void {
    if (arr) |a| hash.pushString(a, val);
}

pub fn arrayPushStringZ(arr: ?*zval, val: [*:0]const u8) void {
    if (arr) |a| hash.pushStringZ(a, val);
}

/// Appends `child` to `arr`, keeping `child` usable (takes a new reference).
pub fn arrayPushArray(parent: ?*zval, child: *zval) void {
    if (parent) |p| hash.pushArray(p, child);
}

/// Moves `child` into `arr`; `child` must not be used afterwards.
pub fn arrayPushArrayOwned(parent: ?*zval, child: *zval) void {
    if (parent) |p| hash.pushArrayOwned(p, child);
}

pub fn arraySetNull(arr: ?*zval, key: [*:0]const u8) void {
    if (arr) |a| hash.setNull(a, key);
}

pub fn arraySetBool(arr: ?*zval, key: [*:0]const u8, val: bool) void {
    if (arr) |a| hash.setBool(a, key, val);
}

pub fn arraySetLong(arr: ?*zval, key: [*:0]const u8, val: i64) void {
    if (arr) |a| hash.setLong(a, key, val);
}

pub fn arraySetDouble(arr: ?*zval, key: [*:0]const u8, val: f64) void {
    if (arr) |a| hash.setDouble(a, key, val);
}

pub fn arraySetString(arr: ?*zval, key: [*:0]const u8, val: []const u8) void {
    if (arr) |a| hash.setString(a, key, val);
}

pub fn arraySetStringZ(arr: ?*zval, key: [*:0]const u8, val: [*:0]const u8) void {
    if (arr) |a| hash.setStringZ(a, key, val);
}

/// Assigns `child` under `key`, keeping `child` usable (takes a new reference).
pub fn arraySetArray(parent: ?*zval, key: [*:0]const u8, child: *zval) void {
    if (parent) |p| hash.setArray(p, key, child);
}

/// Moves `child` under `key`; `child` must not be used afterwards.
pub fn arraySetArrayOwned(parent: ?*zval, key: [*:0]const u8, child: *zval) void {
    if (parent) |p| hash.setArrayOwned(p, key, child);
}

/// Creates a new array zval ready to be inserted into another array.
///
/// The returned zval owns one reference; pass it to `arrayPushArray`/
/// `arraySetArray` (which copies) or to `hash.pushArrayOwned` (which moves).
pub fn newArrayZval(reserve: u32) zval {
    var zv: zval = std.mem.zeroes(zval);
    zval_mod.setArray(&zv, reserve);
    return zv;
}
