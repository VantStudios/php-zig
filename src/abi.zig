const std = @import("std");
const builtin = @import("builtin");

const types = @import("types.zig");
const zval_mod = @import("zval.zig");

test "PHP 8.0 ZTS x86_64 core struct layout" {
    // Layout guarantees that keep hand-written structs safe against the
    // real PHP 8.0 ZTS ABI on the only tested platform.
    if (builtin.cpu.arch != .x86_64) return;

    try std.testing.expectEqual(@as(usize, 8), @sizeOf(types.zend_refcounted_h));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(types.zval));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(types.zend_string));
    try std.testing.expectEqual(@as(usize, 56), @sizeOf(types.zend_array));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(types.Bucket));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(types.zend_type));

    try std.testing.expectEqual(@as(usize, 0), @offsetOf(types.zval, "value"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(types.zval, "u1"));
    try std.testing.expectEqual(@as(usize, 12), @offsetOf(types.zval, "u2"));

    try std.testing.expectEqual(@as(usize, 8), @offsetOf(types.zend_string, "h"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(types.zend_string, "len"));
}

test "zval type_info encodes type and flags" {
    // PHP packs `type | (flags << 8)` into zval.u1.type_info. These are the
    // well-known values observed on PHP 8.0 for strings and arrays.
    try std.testing.expectEqual(
        @as(u32, 6),
        zval_mod.typeInfo(types.IS_STRING, 0),
    );
    try std.testing.expectEqual(
        @as(u32, 262),
        zval_mod.typeInfo(types.IS_STRING, zval_mod.Z_TYPE_FLAG_REFCOUNTED),
    );
    try std.testing.expectEqual(
        @as(u32, 775),
        zval_mod.typeInfo(
            types.IS_ARRAY,
            zval_mod.Z_TYPE_FLAG_REFCOUNTED | zval_mod.Z_TYPE_FLAG_COLLECTABLE,
        ),
    );
}

test "IS_ and MAY_BE_ constants match PHP 8.0" {
    try std.testing.expectEqual(@as(u8, 0), types.IS_UNDEF);
    try std.testing.expectEqual(@as(u8, 1), types.IS_NULL);
    try std.testing.expectEqual(@as(u8, 2), types.IS_FALSE);
    try std.testing.expectEqual(@as(u8, 3), types.IS_TRUE);
    try std.testing.expectEqual(@as(u8, 4), types.IS_LONG);
    try std.testing.expectEqual(@as(u8, 5), types.IS_DOUBLE);
    try std.testing.expectEqual(@as(u8, 6), types.IS_STRING);
    try std.testing.expectEqual(@as(u8, 7), types.IS_ARRAY);
    try std.testing.expectEqual(@as(u8, 8), types.IS_OBJECT);

    // MAY_BE_* bits match IS_* (PHP arginfo type masks).
    try std.testing.expectEqual(@as(u32, 1 << 1), types.MAY_BE_NULL);
    try std.testing.expectEqual(@as(u32, 1 << 2), types.MAY_BE_FALSE);
    try std.testing.expectEqual(@as(u32, 1 << 3), types.MAY_BE_TRUE);
    try std.testing.expectEqual(@as(u32, 1 << 4), types.MAY_BE_LONG);
    try std.testing.expectEqual(@as(u32, 1 << 5), types.MAY_BE_DOUBLE);
    try std.testing.expectEqual(@as(u32, 1 << 6), types.MAY_BE_STRING);
    try std.testing.expectEqual(@as(u32, 1 << 7), types.MAY_BE_ARRAY);
    try std.testing.expectEqual(@as(u32, 1 << 8), types.MAY_BE_OBJECT);
}
