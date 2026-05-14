const builtin = @import("builtin");

const types = @import("types.zig");
pub const zval = types.zval;
pub const zend_array = types.zend_array;
pub const zend_string = types.zend_string;

pub const HashPosition = u32;

pub const HASH_KEY_IS_STRING: c_int = 1;
pub const HASH_KEY_IS_LONG: c_int = 2;
pub const HASH_KEY_NON_EXISTENT: c_int = 3;

pub extern fn zend_array_count(ht: ?*zend_array) u32;
pub const zend_hash_internal_pointer_reset_ex = if (builtin.os.tag == .windows)
    @extern(*const fn (?*const zend_array, ?*HashPosition) callconv(.c) void, .{ .name = "zend_hash_internal_pointer_reset_ex@@16" })
else
    @extern(*const fn (?*const zend_array, ?*HashPosition) callconv(.c) void, .{ .name = "zend_hash_internal_pointer_reset_ex" });

pub const zend_hash_move_forward_ex = if (builtin.os.tag == .windows)
    @extern(*const fn (?*const zend_array, ?*HashPosition) callconv(.c) c_int, .{ .name = "zend_hash_move_forward_ex@@16" })
else
    @extern(*const fn (?*const zend_array, ?*HashPosition) callconv(.c) c_int, .{ .name = "zend_hash_move_forward_ex" });

pub const zend_hash_get_current_key_type_ex = if (builtin.os.tag == .windows)
    @extern(*const fn (?*const zend_array, ?*const HashPosition) callconv(.c) c_int, .{ .name = "zend_hash_get_current_key_type_ex@@16" })
else
    @extern(*const fn (?*const zend_array, ?*const HashPosition) callconv(.c) c_int, .{ .name = "zend_hash_get_current_key_type_ex" });

pub const zend_hash_get_current_key_zval_ex = if (builtin.os.tag == .windows)
    @extern(*const fn (?*const zend_array, ?*zval, ?*const HashPosition) callconv(.c) void, .{ .name = "zend_hash_get_current_key_zval_ex@@24" })
else
    @extern(*const fn (?*const zend_array, ?*zval, ?*const HashPosition) callconv(.c) void, .{ .name = "zend_hash_get_current_key_zval_ex" });

pub const zend_hash_get_current_data_ex = if (builtin.os.tag == .windows)
    @extern(*const fn (?*const zend_array, ?*const HashPosition) callconv(.c) ?*zval, .{ .name = "zend_hash_get_current_data_ex@@16" })
else
    @extern(*const fn (?*const zend_array, ?*const HashPosition) callconv(.c) ?*zval, .{ .name = "zend_hash_get_current_data_ex" });
pub const ArrayKey = union(enum) {
    index: i64,
    string: []const u8,
};

pub const ArrayIter = struct {
    arr: *zend_array,
    pos: HashPosition,

    pub fn init(arr: *zend_array) ArrayIter {
        var iter = ArrayIter{ .arr = arr, .pos = 0 };
        zend_hash_internal_pointer_reset_ex(iter.arr, &iter.pos);
        return iter;
    }

    pub fn count(self: *ArrayIter) u32 {
        return zend_array_count(self.arr);
    }

    pub fn next(self: *ArrayIter) ?struct { key: ArrayKey, value: *zval } {
        const data = zend_hash_get_current_data_ex(self.arr, &self.pos) orelse return null;

        const key_type = zend_hash_get_current_key_type_ex(self.arr, &self.pos);
        var key_zval: zval = undefined;
        zend_hash_get_current_key_zval_ex(self.arr, &key_zval, &self.pos);

        const key: ArrayKey = if (key_type == HASH_KEY_IS_LONG)
            .{ .index = key_zval.value.lval }
        else blk: {
            const str = key_zval.value.str orelse break :blk .{ .string = "" };
            break :blk .{ .string = str.val[0..str.len] };
        };

        _ = zend_hash_move_forward_ex(self.arr, &self.pos);

        return .{ .key = key, .value = data };
    }
};
