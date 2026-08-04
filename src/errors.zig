const ffi = @import("ffi.zig");

// Error and exception reporting for PHP extensions.

// Error levels from Zend/zend_errors.h (stable ABI values).
pub const E_ERROR: c_int = 1;
pub const E_WARNING: c_int = 2;
pub const E_PARSE: c_int = 4;
pub const E_NOTICE: c_int = 8;
pub const E_CORE_ERROR: c_int = 16;
pub const E_CORE_WARNING: c_int = 32;
pub const E_COMPILE_ERROR: c_int = 64;
pub const E_COMPILE_WARNING: c_int = 128;
pub const E_USER_ERROR: c_int = 256;
pub const E_USER_WARNING: c_int = 512;
pub const E_USER_NOTICE: c_int = 1024;
pub const E_RECOVERABLE_ERROR: c_int = 4096;
pub const E_DEPRECATED: c_int = 8192;
pub const E_USER_DEPRECATED: c_int = 16384;
pub const E_ALL: c_int = 32767;

/// Throws an `Exception` with the given message and code. Execution stops here.
///
/// `message` must be NUL-terminated: string literals and slices from
/// `string.slice` (PHP strings are NUL-terminated internally) both qualify.
pub fn throwException(message: []const u8, code: i64) void {
    ffi.zend_throw_exception(ffi.zend_ce_exception, @ptrCast(message.ptr), code);
}

/// Throws a `TypeError`. Execution stops here. See `throwException` for the
/// NUL-termination requirement.
pub fn throwTypeError(message: []const u8) void {
    ffi.zend_throw_error(ffi.zend_ce_type_error, @ptrCast(message.ptr));
}

/// Throws a `ValueError`. Execution stops here. See `throwException` for the
/// NUL-termination requirement.
pub fn throwValueError(message: []const u8) void {
    ffi.zend_throw_error(ffi.zend_ce_value_error, @ptrCast(message.ptr));
}

/// Throws an `Error`. Execution stops here. See `throwException` for the
/// NUL-termination requirement.
pub fn throwError(message: []const u8) void {
    ffi.zend_throw_error(ffi.zend_ce_error, @ptrCast(message.ptr));
}

/// Emits a PHP error/warning/notice at the given level (e.g. `E_WARNING`).
/// Safe for any slice: the message is passed with an explicit length.
pub fn phpError(level: c_int, message: []const u8) void {
    const ptr: [*:0]const u8 = @ptrCast(message.ptr);
    ffi.zend_error(level, "%.*s", @as(c_int, @intCast(message.len)), ptr);
}
