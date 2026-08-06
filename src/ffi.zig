const builtin = @import("builtin");

const types = @import("types.zig");
const zval = types.zval;
const zend_array = types.zend_array;
const zend_string = types.zend_string;
const zend_object = types.zend_object;

/// Hash table iteration position and key kinds (see PHP zend_hash.h).
pub const HashPosition = u32;
pub const HASH_KEY_IS_STRING: c_int = 1;
pub const HASH_KEY_IS_LONG: c_int = 2;
pub const HASH_KEY_NON_EXISTENT: c_int = 3;

/// Declares a PHP symbol whose name differs between platforms.
///
/// Windows exports C++-style decorated names (`_zend_new_array@@8`, ...); the
/// Linux PHP binary exports the plain name. `name` must be comptime-known.
pub fn externDecl(
    comptime T: type,
    comptime linux_name: [:0]const u8,
    comptime win_name: [:0]const u8,
) T {
    return if (builtin.os.tag == .windows)
        @extern(T, .{ .name = win_name })
    else
        @extern(T, .{ .name = linux_name });
}

// Memory and string allocation.
//
// `zend_string_init`/`zend_string_alloc` are not exported by the Linux PHP 8.0
// binary, so strings are built with `_emalloc`/`_efree` and the struct fields
// are filled by hand (see `src/string.zig`).
//
// Contract: `_emalloc` and `_zend_new_array` never return null. Zend's
// allocator bails out (terminates the request) on out-of-memory instead of
// failing, so the pointers are declared non-nullable and callers must not
// check them.
pub const _zend_new_array = externDecl(
    *const fn (u32) callconv(.c) *zend_array,
    "_zend_new_array",
    "_zend_new_array@@8",
);
pub const _emalloc = externDecl(
    *const fn (usize) callconv(.c) *anyopaque,
    "_emalloc",
    "_emalloc@@8",
);
pub const _efree = externDecl(
    *const fn (?*anyopaque) callconv(.c) void,
    "_efree",
    "_efree@@8",
);

/// Destroys a zval, releasing its refcounted payload if any.
pub extern fn zval_ptr_dtor(zv: ?*zval) void;

// Hash table manipulation (zend_hash.h).
pub const zend_hash_next_index_insert = externDecl(
    *const fn (?*zend_array, ?*zval) callconv(.c) ?*zval,
    "zend_hash_next_index_insert",
    "zend_hash_next_index_insert@@16",
);
pub const zend_hash_str_update = externDecl(
    *const fn (?*zend_array, [*]const u8, usize, ?*zval) callconv(.c) ?*zval,
    "zend_hash_str_update",
    "zend_hash_str_update@@32",
);
pub const zend_hash_str_find = externDecl(
    *const fn (?*const zend_array, [*]const u8, usize) callconv(.c) ?*zval,
    "zend_hash_str_find",
    "zend_hash_str_find@@24",
);
pub const zend_hash_index_find = externDecl(
    *const fn (?*const zend_array, u64) callconv(.c) ?*zval,
    "zend_hash_index_find",
    "zend_hash_index_find@@16",
);
pub extern fn zend_array_count(ht: ?*const zend_array) u32;

// Append by numeric index (zend_API.h `add_next_index_*`).
pub extern fn add_next_index_string(zv: ?*zval, str: [*:0]const u8) c_int;
pub extern fn add_next_index_stringl(zv: ?*zval, str: [*]const u8, len: usize) c_int;
pub extern fn add_next_index_long(zv: ?*zval, val: i64) c_int;
pub extern fn add_next_index_double(zv: ?*zval, val: f64) c_int;
pub extern fn add_next_index_bool(zv: ?*zval, val: c_int) c_int;
pub extern fn add_next_index_null(zv: ?*zval) c_int;

// Assign by string key (zend_API.h `add_assoc_*`). Keys are binary-safe: the
// explicit `key_len` gives the byte length, so the pointer is NOT sentinel-
// terminated.
pub extern fn add_assoc_string_ex(
    zv: ?*zval,
    key: [*]const u8,
    key_len: usize,
    str: [*:0]const u8,
) c_int;
pub extern fn add_assoc_stringl_ex(
    zv: ?*zval,
    key: [*]const u8,
    key_len: usize,
    str: [*]const u8,
    len: usize,
) c_int;
pub extern fn add_assoc_long_ex(zv: ?*zval, key: [*]const u8, key_len: usize, val: i64) c_int;
pub extern fn add_assoc_double_ex(zv: ?*zval, key: [*]const u8, key_len: usize, val: f64) c_int;
pub extern fn add_assoc_bool_ex(zv: ?*zval, key: [*]const u8, key_len: usize, val: c_int) c_int;
pub extern fn add_assoc_null_ex(zv: ?*zval, key: [*]const u8, key_len: usize) c_int;
pub extern fn add_assoc_zval_ex(zv: ?*zval, key: [*]const u8, key_len: usize, val: ?*zval) c_int;

// Hash iteration (zend_hash.h `*_ex` pointer-position API).
pub const zend_hash_internal_pointer_reset_ex = externDecl(
    *const fn (?*const zend_array, ?*HashPosition) callconv(.c) void,
    "zend_hash_internal_pointer_reset_ex",
    "zend_hash_internal_pointer_reset_ex@@16",
);
pub const zend_hash_move_forward_ex = externDecl(
    *const fn (?*const zend_array, ?*HashPosition) callconv(.c) c_int,
    "zend_hash_move_forward_ex",
    "zend_hash_move_forward_ex@@16",
);
pub const zend_hash_get_current_key_type_ex = externDecl(
    *const fn (?*const zend_array, ?*const HashPosition) callconv(.c) c_int,
    "zend_hash_get_current_key_type_ex",
    "zend_hash_get_current_key_type_ex@@16",
);
pub const zend_hash_get_current_key_zval_ex = externDecl(
    *const fn (?*const zend_array, ?*zval, ?*const HashPosition) callconv(.c) void,
    "zend_hash_get_current_key_zval_ex",
    "zend_hash_get_current_key_zval_ex@@24",
);
pub const zend_hash_get_current_data_ex = externDecl(
    *const fn (?*const zend_array, ?*const HashPosition) callconv(.c) ?*zval,
    "zend_hash_get_current_data_ex",
    "zend_hash_get_current_data_ex@@16",
);

// Constant registration (zend_constants.h).
pub extern fn zend_register_long_constant(
    name: [*:0]const u8,
    name_len: usize,
    lval: i64,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;
pub extern fn zend_register_double_constant(
    name: [*:0]const u8,
    name_len: usize,
    dval: f64,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;
pub extern fn zend_register_string_constant(
    name: [*:0]const u8,
    name_len: usize,
    strval: [*:0]const u8,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;
pub extern fn zend_register_bool_constant(
    name: [*:0]const u8,
    name_len: usize,
    bval: bool,
    flags: c_int,
    module_number: c_int,
) ?*anyopaque;

// Exceptions and error reporting (zend_exceptions.h / zend_error).
//
// Unlike `_zend_new_array@@8` and friends, these exports are *undecorated* on
// Windows too (verified with `objdump -p win-bin/php/php8ts.dll`), so plain
// `extern fn` declarations resolve on both platforms.
pub extern fn zend_throw_exception(ce: ?*anyopaque, message: [*:0]const u8, code: i64) void;
pub extern fn zend_throw_error(ce: ?*anyopaque, message: [*:0]const u8) void;
pub extern fn zend_throw_exception_ex(ce: ?*anyopaque, code: i64, format: [*:0]const u8, ...) void;
pub extern fn zend_error(type_: c_int, format: [*:0]const u8, ...) void;

// Built-in exception/error class entries (data symbols, plain on both OSes).
// Each is a `zend_class_entry *` global, so the extern var holds the pointer
// value. Opaque: the full `zend_class_entry` struct belongs to the classes
// feature.
pub extern var zend_ce_exception: ?*anyopaque;
pub extern var zend_ce_error: ?*anyopaque;
pub extern var zend_ce_type_error: ?*anyopaque;
pub extern var zend_ce_value_error: ?*anyopaque;

// Object/class support (zend_API.h / zend_object_handlers.c).
//
// `zend_register_*`, `zend_declare_*`, `object_init_ex`, property access and
// `zend_std_get_*` are exported *undecorated* on Windows (verified with
// `objdump -p`); only `zend_object_std_init`/`zend_objects_new` use the C++
// decorated names.
pub extern fn zend_register_internal_class(ce: ?*anyopaque) ?*anyopaque;
pub extern fn zend_register_internal_class_ex(ce: ?*anyopaque, parent_ce: ?*anyopaque) ?*anyopaque;
pub extern fn zend_register_internal_interface(ce: ?*anyopaque) ?*anyopaque;
// Attaches an already-registered interface to a class entry
// (`zend_do_implement_interface`, zend_API.h). Undecorated on both binaries.
pub extern fn zend_do_implement_interface(ce: ?*anyopaque, iface: ?*anyopaque) void;
// Declares a *typed* property (PHP 8.0 signature, zend_API.h): 8.0.13 order is
// `(ce, name, property, access_type, doc_comment, type)` with a
// `zend_property_info *` return — the 8.1+ order puts `type` before
// `doc_comment`. `doc_comment` may be null. Undecorated on both binaries.
pub extern fn zend_declare_typed_property(
    ce: ?*anyopaque,
    name: ?*zend_string,
    property: ?*zval,
    access_type: c_int,
    doc_comment: ?*zend_string,
    type_: types.zend_type,
) ?*types.zend_property_info;
pub extern fn zend_declare_property(
    ce: ?*anyopaque,
    name: [*]const u8,
    name_length: usize,
    property: ?*zval,
    access_type: c_int,
) void;
pub extern fn zend_declare_class_constant(
    ce: ?*anyopaque,
    name: [*]const u8,
    name_length: usize,
    value: ?*zval,
    access_type: c_int,
) void;
pub extern fn object_init_ex(arg: ?*zval, ce: ?*anyopaque) c_int;
// Interned, persistent class/constant names. Undecorated on Windows (verified).
// `zend_string_init_interned` is a *function-pointer variable* (ZTS) in 8.0, so
// it is declared as an extern var of function-pointer type and called through.
// Returns a `zend_string *`; must be released with `zend_string_release_ex(., 1)`.
pub extern var zend_string_init_interned: *const fn (
    str: [*]const u8,
    length: usize,
    persistent: c_int,
) callconv(.c) ?*anyopaque;
pub extern fn zend_read_property(
    scope: ?*anyopaque,
    object: ?*zend_object,
    name: [*]const u8,
    name_length: usize,
    silent: bool,
    rv: ?*zval,
) ?*zval;
pub extern fn zend_update_property(
    scope: ?*anyopaque,
    object: ?*zend_object,
    name: [*]const u8,
    name_length: usize,
    value: ?*zval,
) void;
pub extern fn zend_read_static_property(
    scope: ?*anyopaque,
    name: [*]const u8,
    name_length: usize,
    silent: bool,
) ?*zval;
pub extern fn zend_update_static_property(
    scope: ?*anyopaque,
    name: [*]const u8,
    name_length: usize,
    value: ?*zval,
) void;
pub extern fn zend_std_get_properties(object: ?*zend_object) ?*zend_array;
pub extern fn zend_std_get_property_ptr_ptr(
    object: ?*zend_object,
    member: ?*zend_string,
    type_: c_int,
    cache_slot: ?*?*anyopaque,
) ?*zval;

// Default object handlers (opaque; the full struct belongs to custom-handler
// users). Only its address is needed for INIT_CLASS_ENTRY.
pub extern var std_object_handlers: anyopaque;

pub const zend_object_std_init = externDecl(
    *const fn (?*zend_object, ?*anyopaque) callconv(.c) void,
    "zend_object_std_init",
    "zend_object_std_init@@16",
);
pub const zend_objects_new = externDecl(
    *const fn (?*anyopaque) callconv(.c) ?*zend_object,
    "zend_objects_new",
    "zend_objects_new@@8",
);
