const php = @import("php");

// Module startup: constant registration and optional parameters with defaults.

fn module_startup(type_: c_int, module_number: c_int) callconv(.c) c_int {
    _ = type_;
    php.constants.registerString("PHP_ZIG_HELLO", "php-zig", module_number);
    php.constants.registerLong("PHP_ZIG_VERSION", 100, module_number);
    php.constants.registerDouble("PHP_ZIG_PI", 3.14159, module_number);
    php.constants.registerBool("PHP_ZIG_READY", true, module_number);
    return 1; // SUCCESS
}

fn module_shutdown(type_: c_int, module_number: c_int) callconv(.c) c_int {
    _ = type_;
    _ = module_number;
    return 1; // SUCCESS
}

const arginfo_greet = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_STRING),
    php.module.paramInfoOptional("name", php.types.MAY_BE_STRING, "\"world\""),
};

fn php_greet(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const name_arg = php.params.getArg(execute_data, 1);
    const name = if (name_arg) |arg| arg.toString() orelse "world" else "world";

    const out = php.string.alloc("Hello, ".len + name.len);
    const val_ptr: [*]u8 = @ptrCast(&out.val[0]);
    const prefix = "Hello, ";
    @memcpy(val_ptr[0..prefix.len], prefix);
    @memcpy(val_ptr[prefix.len .. prefix.len + name.len], name);
    val_ptr[prefix.len + name.len] = 0;

    const rv = return_value orelse return;
    rv.value.str = out;
    rv.u1.type_info = php.zval.typeInfo(php.types.IS_STRING, php.zval.Z_TYPE_FLAG_REFCOUNTED);
}

const arginfo_constant_report = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_ARRAY),
};

fn php_constant_report(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    php.helpers.returnArray(return_value, 4);
    php.helpers.arrayPushStringZ(return_value, "PHP_ZIG_HELLO");
    php.helpers.arrayPushStringZ(return_value, "PHP_ZIG_VERSION");
    php.helpers.arrayPushStringZ(return_value, "PHP_ZIG_PI");
    php.helpers.arrayPushStringZ(return_value, "PHP_ZIG_READY");
}

const extension_functions = [_]php.module.zend_function_entry{
    .{
        .fname = "greet",
        .handler = php_greet,
        .arg_info = &arginfo_greet,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "constant_report",
        .handler = php_constant_report,
        .arg_info = &arginfo_constant_report,
        .num_args = 0,
        .flags = 0,
    },
    php.module.function_entry_end,
};

export var my_module_entry = php.module.createModule(.{
    .name = "php_zig_constants",
    .version = "1.0.0",
    .functions = &extension_functions,
    .module_startup_func = module_startup,
    .module_shutdown_func = module_shutdown,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
