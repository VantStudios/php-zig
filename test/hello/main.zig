const php = @import("php");

// Minimal extension: module entry, function table, arginfo, arguments and
// scalar returns through the high-level helpers.

const arginfo_hello_world = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_STRING),
};

fn php_hello_world(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    php.returnString(return_value, "Hello from Zig!");
}

const arginfo_hello_add = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
    php.paramInfo("a", php.MAY_BE_LONG),
    php.paramInfo("b", php.MAY_BE_LONG),
};

fn php_hello_add(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const a = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const b = php.getArg(execute_data, 2) orelse return php.returnNull(return_value);

    const av = a.toLong() orelse return php.returnNull(return_value);
    const bv = b.toLong() orelse return php.returnNull(return_value);
    php.returnLong(return_value, av + bv);
}

const arginfo_hello_truthy = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_FALSE | php.MAY_BE_TRUE),
    php.paramInfo("value", php.MAY_BE_FALSE | php.MAY_BE_TRUE | php.MAY_BE_NULL),
};

fn php_hello_truthy(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const value = php.getArg(execute_data, 1) orelse return php.returnFalse(return_value);
    if (value.toBool()) |b| {
        if (b) return php.returnTrue(return_value) else return php.returnFalse(return_value);
    }
    php.returnFalse(return_value);
}

const extension_functions = [_]php.zend_function_entry{
    .{
        .fname = "hello_world",
        .handler = php_hello_world,
        .arg_info = &arginfo_hello_world,
        .num_args = 0,
        .flags = 0,
    },
    .{
        .fname = "hello_add",
        .handler = php_hello_add,
        .arg_info = &arginfo_hello_add,
        .num_args = 2,
        .flags = 0,
    },
    .{
        .fname = "hello_truthy",
        .handler = php_hello_truthy,
        .arg_info = &arginfo_hello_truthy,
        .num_args = 1,
        .flags = 0,
    },
    php.function_entry_end,
};

export var my_module_entry = php.createModule(.{
    .name = "php_zig_hello",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.zend_module_entry {
    return &my_module_entry;
}
