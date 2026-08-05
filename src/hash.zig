const ffi = @import("ffi.zig");
const string = @import("string.zig");
const zval_mod = @import("zval.zig");

const types = @import("types.zig");
const zval = types.zval;
const zend_array = types.zend_array;
const zend_string = types.zend_string;

pub const HashPosition = ffi.HashPosition;
pub const HASH_KEY_IS_STRING = ffi.HASH_KEY_IS_STRING;
pub const HASH_KEY_IS_LONG = ffi.HASH_KEY_IS_LONG;
pub const HASH_KEY_NON_EXISTENT = ffi.HASH_KEY_NON_EXISTENT;

/// Appends a value by the next numeric index.
pub fn pushNull(arr: *zval) void {
    _ = ffi.add_next_index_null(arr);
}

pub fn pushBool(arr: *zval, val: bool) void {
    _ = ffi.add_next_index_bool(arr, if (val) 1 else 0);
}

pub fn pushLong(arr: *zval, val: i64) void {
    _ = ffi.add_next_index_long(arr, val);
}

pub fn pushDouble(arr: *zval, val: f64) void {
    _ = ffi.add_next_index_double(arr, val);
}

/// Appends a binary-safe string value.
pub fn pushString(arr: *zval, val: []const u8) void {
    _ = ffi.add_next_index_stringl(arr, val.ptr, val.len);
}

/// Appends a null-terminated string value.
pub fn pushStringZ(arr: *zval, val: [*:0]const u8) void {
    _ = ffi.add_next_index_string(arr, val);
}

/// Inserts `child` by numeric index, taking a new reference (caller keeps
/// ownership of `child`).
pub fn pushArray(arr: *zval, child: *zval) void {
    const target = arr.value.arr orelse return;
    var child_copy: zval = undefined;
    zval_mod.copy(&child_copy, child);
    _ = ffi.zend_hash_next_index_insert(target, &child_copy);
}

/// Moves `child` into `arr`; ownership transfers, `child` must not be reused.
pub fn pushArrayOwned(arr: *zval, child: *zval) void {
    const target = arr.value.arr orelse return;
    _ = ffi.zend_hash_next_index_insert(target, child);
}

/// Assigns `key => value`. Keys are binary-safe slices.
pub fn setNull(arr: *zval, key: []const u8) void {
    _ = ffi.add_assoc_null_ex(arr, key.ptr, key.len);
}

pub fn setBool(arr: *zval, key: []const u8, val: bool) void {
    _ = ffi.add_assoc_bool_ex(arr, key.ptr, key.len, if (val) 1 else 0);
}

pub fn setLong(arr: *zval, key: []const u8, val: i64) void {
    _ = ffi.add_assoc_long_ex(arr, key.ptr, key.len, val);
}

pub fn setDouble(arr: *zval, key: []const u8, val: f64) void {
    _ = ffi.add_assoc_double_ex(arr, key.ptr, key.len, val);
}

/// Assigns a binary-safe string value under `key`.
pub fn setString(arr: *zval, key: []const u8, val: []const u8) void {
    _ = ffi.add_assoc_stringl_ex(arr, key.ptr, key.len, val.ptr, val.len);
}

/// Assigns a null-terminated string value under `key`.
pub fn setStringZ(arr: *zval, key: []const u8, val: [*:0]const u8) void {
    _ = ffi.add_assoc_string_ex(arr, key.ptr, key.len, val);
}

/// Assigns `child` under `key`, taking a new reference (caller keeps ownership).
pub fn setArray(arr: *zval, key: []const u8, child: *zval) void {
    const target = arr.value.arr orelse return;
    var child_copy: zval = undefined;
    zval_mod.copy(&child_copy, child);
    _ = ffi.zend_hash_str_update(target, key.ptr, key.len, &child_copy);
}

/// Moves `child` under `key`; ownership transfers, `child` must not be reused.
pub fn setArrayOwned(arr: *zval, key: []const u8, child: *zval) void {
    const target = arr.value.arr orelse return;
    _ = ffi.zend_hash_str_update(target, key.ptr, key.len, child);
}

/// Returns the value under binary-safe string `key`, or null.
pub fn findString(arr: *const zval, key: []const u8) ?*zval {
    const target = arr.value.arr orelse return null;
    return ffi.zend_hash_str_find(target, key.ptr, key.len);
}

/// Returns the value under numeric `index`, or null.
pub fn findIndex(arr: *const zval, index: u64) ?*zval {
    const target = arr.value.arr orelse return null;
    return ffi.zend_hash_index_find(target, index);
}

/// Returns the number of elements in `arr`.
pub fn count(arr: *const zend_array) u32 {
    return ffi.zend_array_count(arr);
}

pub const ArrayKey = union(enum) {
    index: i64,
    string: []const u8,
};

pub const ArrayEntry = struct {
    key: ArrayKey,
    value: *zval,
};

/// Iterates a PHP array in hash-table order using the pointer-position API.
pub const ArrayIter = struct {
    arr: *const zend_array,
    pos: HashPosition,

    pub fn init(arr: *const zend_array) ArrayIter {
        var iter = ArrayIter{ .arr = arr, .pos = 0 };
        ffi.zend_hash_internal_pointer_reset_ex(iter.arr, &iter.pos);
        return iter;
    }

    pub fn count(self: *ArrayIter) u32 {
        return ffi.zend_array_count(self.arr);
    }

    pub fn next(self: *ArrayIter) ?ArrayEntry {
        const data = ffi.zend_hash_get_current_data_ex(self.arr, &self.pos) orelse return null;

        const key_type = ffi.zend_hash_get_current_key_type_ex(self.arr, &self.pos);
        var key_zval: zval = undefined;
        ffi.zend_hash_get_current_key_zval_ex(self.arr, &key_zval, &self.pos);

        const key: ArrayKey = if (key_type == HASH_KEY_IS_LONG)
            .{ .index = key_zval.value.lval }
        else blk: {
            const str = key_zval.value.str orelse break :blk .{ .string = "" };
            break :blk .{ .string = string.slice(str) };
        };

        _ = ffi.zend_hash_move_forward_ex(self.arr, &self.pos);

        return .{ .key = key, .value = data };
    }
};
