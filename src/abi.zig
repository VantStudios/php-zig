const std = @import("std");
const builtin = @import("builtin");

const types = @import("types.zig");
const zval_mod = @import("zval.zig");
const module_mod = @import("module.zig");

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

    // zend_reference (PHP 8.0): gc + val + sources = 8 + 16 + 8.
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(types.zend_reference));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(types.zend_reference, "gc"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(types.zend_reference, "val"));
    try std.testing.expectEqual(@as(usize, 24), @offsetOf(types.zend_reference, "sources"));

    try std.testing.expectEqual(@as(usize, 8), @offsetOf(types.zend_string, "h"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(types.zend_string, "len"));

    // zend_object (PHP 8.0): gc + handle + ce + handlers + properties + table.
    try std.testing.expectEqual(@as(usize, 56), @sizeOf(types.zend_object));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(types.zend_object, "gc"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(types.zend_object, "handle"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(types.zend_object, "ce"));
    try std.testing.expectEqual(@as(usize, 24), @offsetOf(types.zend_object, "handlers"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(types.zend_object, "properties"));
    try std.testing.expectEqual(@as(usize, 40), @offsetOf(types.zend_object, "properties_table"));

    // zend_class_entry (PHP 8.0, no map_ptr size change): see zend.h.
    try std.testing.expectEqual(@as(usize, 464), @sizeOf(types.zend_class_entry));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(types.zend_class_entry, "name"));
    try std.testing.expectEqual(@as(usize, 16), @offsetOf(types.zend_class_entry, "parent"));
    try std.testing.expectEqual(@as(usize, 28), @offsetOf(types.zend_class_entry, "ce_flags"));
    try std.testing.expectEqual(@as(usize, 64), @offsetOf(types.zend_class_entry, "function_table"));
    try std.testing.expectEqual(@as(usize, 120), @offsetOf(types.zend_class_entry, "properties_info"));
    try std.testing.expectEqual(@as(usize, 176), @offsetOf(types.zend_class_entry, "constants_table"));
    try std.testing.expectEqual(@as(usize, 240), @offsetOf(types.zend_class_entry, "constructor"));
    try std.testing.expectEqual(@as(usize, 344), @offsetOf(types.zend_class_entry, "iterator_funcs_ptr"));
    try std.testing.expectEqual(@as(usize, 352), @offsetOf(types.zend_class_entry, "create_object"));
    try std.testing.expectEqual(@as(usize, 440), @offsetOf(types.zend_class_entry, "info"));

    // zend_execute_data (PHP 8.0): 8 pointers + This zval = 64 + 16.
    try std.testing.expectEqual(@as(usize, 80), @sizeOf(types.zend_execute_data));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(types.zend_execute_data, "opline"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(types.zend_execute_data, "this"));
    try std.testing.expectEqual(@as(usize, 48), @offsetOf(types.zend_execute_data, "prev_execute_data"));
    try std.testing.expectEqual(@as(usize, 72), @offsetOf(types.zend_execute_data, "extra_named_params"));
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
    try std.testing.expectEqual(@as(u8, 9), types.IS_RESOURCE);
    try std.testing.expectEqual(@as(u8, 10), types.IS_REFERENCE);
    try std.testing.expectEqual(@as(u32, 266), types.IS_REFERENCE_EX);

    // Reference GC type_info: IS_REFERENCE | GC_NOT_COLLECTABLE = 10 | 16.
    try std.testing.expectEqual(@as(u32, 26), zval_mod.GC_REFERENCE);

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

test "by-ref and variadic arginfo flags match PHP 8.0" {
    // High bits of zend_internal_arg_info.type_.type_mask (zend_compile.h).
    try std.testing.expectEqual(@as(u32, 1 << 24), module_mod.ZEND_SEND_BY_REF);
    try std.testing.expectEqual(@as(u32, 2 << 24), module_mod.ZEND_SEND_PREFER_REF);
    try std.testing.expectEqual(@as(u32, 1 << 26), module_mod.ZEND_IS_VARIADIC_BIT);

    // A by-ref param carries its send mode in the mask.
    const p = module_mod.paramInfoByRef("n", types.MAY_BE_LONG);
    try std.testing.expectEqual(
        types.MAY_BE_LONG | (1 << 24),
        p.type_.type_mask,
    );
}
