const builtin = @import("builtin");

const types = @import("types.zig");
const zval = types.zval;
const zend_type = types.zend_type;
const zend_execute_data = types.zend_execute_data;

pub const BUILD_ID = if (builtin.os.tag == .windows) "API20240924,TS,VS16" else "API20240924,TS";
pub const ZEND_API = 20240924;

pub const zend_internal_arg_info = extern struct {
    name: [*:0]const u8,
    type_: zend_type,
    default_value: ?[*:0]const u8,
};

pub const zend_function_entry = extern struct {
    fname: ?[*:0]const u8,
    handler: ?*const fn (?*zend_execute_data, ?*zval) callconv(.c) void,
    arg_info: ?[*]const zend_internal_arg_info,
    num_args: u32,
    flags: u32,
};

pub const zend_module_entry = extern struct {
    size: u16,
    zend_api: u32,
    zend_debug: u8,
    zts: u8,
    ini_entry: ?*const anyopaque,
    deps: ?*const anyopaque,
    name: ?[*:0]const u8,
    functions: ?[*]const zend_function_entry,
    module_startup_func: ?*const fn (c_int, c_int) callconv(.c) c_int,
    module_shutdown_func: ?*const fn (c_int, c_int) callconv(.c) c_int,
    request_startup_func: ?*const fn (c_int, c_int) callconv(.c) c_int,
    request_shutdown_func: ?*const fn (c_int, c_int) callconv(.c) c_int,
    info_func: ?*const fn (?*anyopaque) callconv(.c) void,
    version: ?[*:0]const u8,
    globals_size: usize,
    globals_ptr: ?*anyopaque,
    globals_ctor: ?*const anyopaque,
    globals_dtor: ?*const anyopaque,
    post_deactivate_func: ?*const fn () callconv(.c) c_int,
    module_started: c_int,
    type: u8,
    handle: ?*anyopaque,
    module_number: c_int,
    build_id: ?[*:0]const u8,
};

pub const ModuleOptions = struct {
    name: [*:0]const u8,
    version: [*:0]const u8,
    functions: ?[*]const zend_function_entry = null,
    zts: u8 = 1,
    module_startup_func: ?*const fn (c_int, c_int) callconv(.c) c_int = null,
    module_shutdown_func: ?*const fn (c_int, c_int) callconv(.c) c_int = null,
    request_startup_func: ?*const fn (c_int, c_int) callconv(.c) c_int = null,
    request_shutdown_func: ?*const fn (c_int, c_int) callconv(.c) c_int = null,
};

/// First `zend_internal_arg_info` entry describes the return type, marked with
/// the magic name `(const char*)-1`; without it the return type is ignored.
/// The pointer is never dereferenced — only its value is compared.
pub const RETURN_INFO_MARKER: [*:0]const u8 = @ptrFromInt(~@as(usize, 0));

pub fn returnInfoNamed(name_marker: [*:0]const u8, type_mask: u32) zend_internal_arg_info {
    return .{
        .name = name_marker,
        .type_ = .{ .ptr = null, .type_mask = type_mask },
        .default_value = null,
    };
}

pub fn returnInfo(type_mask: u32) zend_internal_arg_info {
    // Required-minimum defaults to all params when the marker is `-1`. Keep
    // `returnInfo` as the `required == total` case.
    return returnInfoNamed(RETURN_INFO_MARKER, type_mask);
}

pub fn paramInfo(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info {
    return .{
        .name = name,
        .type_ = .{ .ptr = null, .type_mask = type_mask },
        .default_value = null,
    };
}

pub fn paramInfoOptional(
    name: [*:0]const u8,
    type_mask: u32,
    default_value: [*:0]const u8,
) zend_internal_arg_info {
    return .{
        .name = name,
        .type_ = .{ .ptr = null, .type_mask = type_mask },
        .default_value = default_value,
    };
}

pub const function_entry_end = zend_function_entry{
    .fname = null,
    .handler = null,
    .arg_info = null,
    .num_args = 0,
    .flags = 0,
};

// Send-mode and variadic markers packed into the high bits of
// `zend_internal_arg_info.type_.type_mask` (see PHP `zend_compile.h`):
//   send-mode is at bits 24-25 (ZEND_SEND_BY_VAL=0, BY_REF=1, PREFER_REF=2)
//   variadic is bit 26 (_ZEND_IS_VARIADIC_BIT = 1 << 26)
pub const ZEND_SEND_MODE_SHIFT: u5 = 24;
pub const ZEND_SEND_BY_VAL: u32 = 0;
pub const ZEND_SEND_BY_REF: u32 = 1 << ZEND_SEND_MODE_SHIFT;
pub const ZEND_SEND_PREFER_REF: u32 = 2 << ZEND_SEND_MODE_SHIFT;
pub const ZEND_IS_VARIADIC_BIT: u32 = 1 << 26;

fn maskWith(extra: u32, type_mask: u32) u32 {
    return type_mask | extra;
}

/// Parameter passed by reference (`&$name`).
pub fn paramInfoByRef(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info {
    return paramInfo(name, maskWith(ZEND_SEND_BY_REF, type_mask));
}

/// By-reference parameter with a default value.
pub fn paramInfoByRefOptional(
    name: [*:0]const u8,
    type_mask: u32,
    default_value: [*:0]const u8,
) zend_internal_arg_info {
    return paramInfoOptional(name, maskWith(ZEND_SEND_BY_REF, type_mask), default_value);
}

/// Variadic parameter (`...$name`).
pub fn paramInfoVariadic(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info {
    return paramInfo(name, maskWith(ZEND_IS_VARIADIC_BIT, type_mask));
}

/// Variadic by-reference parameter (`...&$name`).
pub fn paramInfoVariadicByRef(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info {
    return paramInfo(name, maskWith(ZEND_SEND_BY_REF | ZEND_IS_VARIADIC_BIT, type_mask));
}

pub fn createModule(opts: ModuleOptions) zend_module_entry {
    return zend_module_entry{
        .size = @sizeOf(zend_module_entry),
        .zend_api = ZEND_API,
        .zend_debug = 0,
        .zts = opts.zts,
        .ini_entry = null,
        .deps = null,
        .name = opts.name,
        .functions = opts.functions,
        .module_startup_func = opts.module_startup_func,
        .module_shutdown_func = opts.module_shutdown_func,
        .request_startup_func = opts.request_startup_func,
        .request_shutdown_func = opts.request_shutdown_func,
        .info_func = null,
        .version = opts.version,
        .globals_size = 0,
        .globals_ptr = null,
        .globals_ctor = null,
        .globals_dtor = null,
        .post_deactivate_func = null,
        .module_started = 0,
        .type = 0,
        .handle = null,
        .module_number = 0,
        .build_id = BUILD_ID,
    };
}
