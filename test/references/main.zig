const php = @import("php");

// Reference (`&`) and variadic (`...`) arguments.

const arg_inc = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
    php.paramInfoByRef("n", php.MAY_BE_LONG),
};

fn php_inc(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const arg = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    if (!arg.isRef()) return php.returnFalse(return_value);

    const inner = arg.deref();
    if (php.zval.getType(inner) != php.IS_LONG) return php.returnFalse(return_value);
    php.zval.setLong(inner, inner.value.lval + 1);
    php.returnTrue(return_value);
}

const arg_swap = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
    php.paramInfoByRef("a", php.MAY_BE_LONG | php.MAY_BE_DOUBLE),
    php.paramInfoByRef("b", php.MAY_BE_LONG | php.MAY_BE_DOUBLE),
};

fn php_swap(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const a = php.getArg(execute_data, 1) orelse return php.returnFalse(return_value);
    const b = php.getArg(execute_data, 2) orelse return php.returnFalse(return_value);
    if (!a.isRef() or !b.isRef()) return php.returnFalse(return_value);

    const va = a.deref();
    const vb = b.deref();
    if (php.zval.getType(va) != php.IS_LONG or php.zval.getType(vb) != php.IS_LONG)
        return php.returnFalse(return_value);

    const tmp = va.value.lval;
    php.zval.setLong(va, vb.value.lval);
    php.zval.setLong(vb, tmp);
    php.returnTrue(return_value);
}

const arg_append = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
    php.paramInfoByRef("arr", php.MAY_BE_ARRAY),
};

fn append_x(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const arg = php.getArg(execute_data, 1) orelse return php.returnFalse(return_value);
    if (!arg.isRef()) return php.returnFalse(return_value);

    const inner = arg.deref();
    if (php.zval.getType(inner) != php.IS_ARRAY) return php.returnFalse(return_value);
    const n_before = php.hash.count(inner.value.arr.?);
    php.hash.pushString(inner, "x");
    const n_after = php.hash.count(inner.value.arr.?);
    php.returnLong(return_value, @intCast(n_after - n_before));
}

const arg_nparams = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
    php.paramInfoVariadic("args", php.MAY_BE_LONG),
};

fn nparams(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    // Variadic args arrive as ordinary (1-based) args after any declared ones.
    // Sum them to prove every one was passed through.
    var sum: i64 = 0;
    const count = php.getArgCount(execute_data);
    var i: usize = 1;
    while (i <= count) : (i += 1) {
        const arg = php.getArg(execute_data, i) orelse break;
        sum += arg.toLong() orelse 0;
    }
    php.returnLong(return_value, sum);
}

const extension_functions = [_]php.zend_function_entry{
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
    php.function_entry_end,
};

export var my_module_entry = php.createModule(.{
    .name = "php_zig_references",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.zend_module_entry {
    return &my_module_entry;
}
