const ffi = @import("ffi.zig");

const types = @import("types.zig");
const zend_string = types.zend_string;

/// Allocates a `zend_string` of `len` bytes with refcount 1.
///
/// The allocation is `@sizeOf(zend_string) + len` bytes, so the `val` buffer
/// has `len + 1` bytes (including the NUL terminator). The caller owns the
/// returned reference and must eventually call `free`. Never returns null:
/// `_emalloc` bails out on OOM rather than failing.
pub fn alloc(len: usize) *zend_string {
    const size = @sizeOf(zend_string) + len;
    const mem = ffi._emalloc(size);

    const str: *zend_string = @ptrCast(@alignCast(mem));
    str.gc.refcount = 1;
    str.gc.type_info = 0;
    str.h = 0;
    str.len = len;
    return str;
}

/// Allocates a `zend_string` and copies `s` into it (binary-safe, NUL-terminated).
pub fn dup(s: []const u8) *zend_string {
    const str = alloc(s.len);

    const val_ptr: [*]u8 = @ptrCast(&str.val[0]);
    @memcpy(val_ptr[0..s.len], s);
    val_ptr[s.len] = 0;
    return str;
}

/// Releases a `zend_string` allocated by `alloc`/`dup`.
pub fn free(str: *zend_string) void {
    ffi._efree(str);
}

/// Views the string payload as a binary-safe slice.
pub fn slice(str: *const zend_string) []const u8 {
    const val_ptr: [*]const u8 = @ptrCast(&str.val[0]);
    return val_ptr[0..str.len];
}
