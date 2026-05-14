const builtin = @import("builtin");

const types = @import("types.zig");
pub const zval = types.zval;
pub const zend_type = types.zend_type;
pub const zend_execute_data = types.zend_execute_data;

pub const BUILD_ID = if (builtin.os.tag == .windows) "API20200930,TS,VS16" else "API20200930,TS";
pub const ZEND_API = 20200930;

pub const zend_internal_arg_info = extern struct {
    name: [*:0]const u8,
    type_: zend_type,
    default_value: ?[*:0]const u8,
};

pub const zend_frameless_function_info = opaque {};

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
};

pub fn returnInfo(type_mask: u32) zend_internal_arg_info {
    return .{
        .name = "",
        .type_ = .{ .ptr = null, .type_mask = type_mask },
        .default_value = null,
    };
}

pub fn paramInfo(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info {
    return .{
        .name = name,
        .type_ = .{ .ptr = null, .type_mask = type_mask },
        .default_value = null,
    };
}

pub fn paramInfoOptional(name: [*:0]const u8, type_mask: u32, default_value: [*:0]const u8) zend_internal_arg_info {
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
        .module_shutdown_func = null,
        .request_startup_func = null,
        .request_shutdown_func = null,
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
