const php = @import("php");

// Reference (`&`) and variadic (`...`) arguments.

const arg_inc = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_LONG),
    php.module.paramInfoByRef("n", php.types.MAY_BE_LONG),
};

fn php_inc(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const arg = php.params.getArg(execute_data, 1) orelse return php.helpers.returnNull(return_value);
    if (!arg.isRef()) return php.helpers.returnFalse(return_value);

    const inner = arg.deref();
    if (php.zval.getType(inner) != php.types.IS_LONG) return php.helpers.returnFalse(return_value);
    php.zval.setLong(inner, inner.value.lval + 1);
    php.helpers.returnTrue(return_value);
}

const arg_swap = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_LONG),
    php.module.paramInfoByRef("a", php.types.MAY_BE_LONG | php.types.MAY_BE_DOUBLE),
    php.module.paramInfoByRef("b", php.types.MAY_BE_LONG | php.types.MAY_BE_DOUBLE),
};

fn php_swap(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const a = php.params.getArg(execute_data, 1) orelse return php.helpers.returnFalse(return_value);
    const b = php.params.getArg(execute_data, 2) orelse return php.helpers.returnFalse(return_value);
    if (!a.isRef() or !b.isRef()) return php.helpers.returnFalse(return_value);

    const va = a.deref();
    const vb = b.deref();
    if (php.zval.getType(va) != php.types.IS_LONG or php.zval.getType(vb) != php.types.IS_LONG)
        return php.helpers.returnFalse(return_value);

    const tmp = va.value.lval;
    php.zval.setLong(va, vb.value.lval);
    php.zval.setLong(vb, tmp);
    php.helpers.returnTrue(return_value);
}

const arg_append = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_LONG),
    php.module.paramInfoByRef("arr", php.types.MAY_BE_ARRAY),
};

fn append_x(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const arg = php.params.getArg(execute_data, 1) orelse return php.helpers.returnFalse(return_value);
    if (!arg.isRef()) return php.helpers.returnFalse(return_value);

    const inner = arg.deref();
    if (php.zval.getType(inner) != php.types.IS_ARRAY) return php.helpers.returnFalse(return_value);
    const n_before = php.hash.count(inner.value.arr.?);
    php.hash.pushString(inner, "x");
    const n_after = php.hash.count(inner.value.arr.?);
    php.helpers.returnLong(return_value, @intCast(n_after - n_before));
}

const arg_nparams = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_LONG),
    php.module.paramInfoVariadic("args", php.types.MAY_BE_LONG),
};

fn nparams(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    // Variadic args arrive as ordinary (1-based) args after any declared ones.
    // Sum them to prove every one was passed through.
    var sum: i64 = 0;
    const count = php.params.getArgCount(execute_data);
    var i: usize = 1;
    while (i <= count) : (i += 1) {
        const arg = php.params.getArg(execute_data, i) orelse break;
        sum += arg.toLong() orelse 0;
    }
    php.helpers.returnLong(return_value, sum);
}

const extension_functions = [_]php.module.zend_function_entry{
    .{
        .fname = "ref_inc",
        .handler = php_inc,
        .arg_info = &arg_inc,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "ref_swap",
        .handler = php_swap,
        .arg_info = &arg_swap,
        .num_args = 2,
        .flags = 0,
    },
    .{
        .fname = "ref_append",
        .handler = append_x,
        .arg_info = &arg_append,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "nparams",
        .handler = nparams,
        .arg_info = &arg_nparams,
        .num_args = 0,
        .flags = 0,
    },
    php.module.function_entry_end,
};

export var my_module_entry = php.module.createModule(.{
    .name = "php_zig_references",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
