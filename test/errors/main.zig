const php = @import("php");

// Exception and error reporting via the `errors` module.

const arginfo_throws_exception = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_NULL),
};

fn php_throws_exception(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    _ = return_value;
    php.errors.throwException("boom from zig", 42);
}

const arginfo_throws_error = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_NULL),
};

fn php_throws_error(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    _ = return_value;
    php.errors.throwError("fatal from zig");
}

const arginfo_throws_type_error = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_NULL),
};

fn php_throws_type_error(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    _ = return_value;
    php.errors.throwTypeError("expected int, got string");
}

const arginfo_throws_value_error = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_NULL),
};

fn php_throws_value_error(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    _ = return_value;
    php.errors.throwValueError("negative length");
}

const arginfo_emit_warning = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_NULL),
    php.module.paramInfo("message", php.types.MAY_BE_STRING),
};

fn php_emit_warning(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = return_value;
    const message = php.params.getArg(execute_data, 1) orelse return;
    const mv = message.toString() orelse return;
    php.errors.phpError(php.errors.E_WARNING, mv);
}

const arginfo_emit_notice = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_NULL),
    php.module.paramInfo("message", php.types.MAY_BE_STRING),
};

fn php_emit_notice(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = return_value;
    const message = php.params.getArg(execute_data, 1) orelse return;
    const mv = message.toString() orelse return;
    php.errors.phpError(php.errors.E_NOTICE, mv);
}

const extension_functions = [_]php.module.zend_function_entry{
    .{
        .fname = "throws_exception",
        .handler = php_throws_exception,
        .arg_info = &arginfo_throws_exception,
        .num_args = 0,
        .flags = 0,
    },
    .{
        .fname = "throws_error",
        .handler = php_throws_error,
        .arg_info = &arginfo_throws_error,
        .num_args = 0,
        .flags = 0,
    },
    .{
        .fname = "throws_type_error",
        .handler = php_throws_type_error,
        .arg_info = &arginfo_throws_type_error,
        .num_args = 0,
        .flags = 0,
    },
    .{
        .fname = "throws_value_error",
        .handler = php_throws_value_error,
        .arg_info = &arginfo_throws_value_error,
        .num_args = 0,
        .flags = 0,
    },
    .{
        .fname = "emit_warning",
        .handler = php_emit_warning,
        .arg_info = &arginfo_emit_warning,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "emit_notice",
        .handler = php_emit_notice,
        .arg_info = &arginfo_emit_notice,
        .num_args = 1,
        .flags = 0,
    },
    php.module.function_entry_end,
};

export var my_module_entry = php.module.createModule(.{
    .name = "php_zig_errors",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
