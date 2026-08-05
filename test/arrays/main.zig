const php = @import("php");

// Array building and reading: returnArray/arrayPush*/arraySet*, nested arrays,
// ArrayIter iteration, and low-level hash lookups.

const arginfo_build_array = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_ARRAY),
};

fn php_build_array(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;

    php.helpers.returnArray(return_value, 8);
    php.helpers.arrayPushLong(return_value, 10);
    php.helpers.arrayPushString(return_value, "first");
    php.helpers.arrayPushBool(return_value, true);
    php.helpers.arrayPushNull(return_value);
    php.helpers.arraySetString(return_value, "name", "php-zig");
    php.helpers.arraySetDouble(return_value, "pi", 3.14159);
    php.helpers.arraySetLong(return_value, "answer", 42);

    // Nested array: build a child and move it in (no copy).
    var child = php.helpers.newArrayZval(2);
    php.helpers.arrayPushString(&child, "nested-a");
    php.helpers.arrayPushString(&child, "nested-b");
    php.helpers.arrayPushArrayOwned(return_value, &child);

    // Same, but under a string key.
    var child2 = php.helpers.newArrayZval(1);
    php.helpers.arrayPushLong(&child2, 99);
    php.helpers.arraySetArrayOwned(return_value, "child2", &child2);
}

const arginfo_array_sum_plus = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_LONG),
    php.module.paramInfo("xs", php.types.MAY_BE_ARRAY),
    php.module.paramInfo("extra", php.types.MAY_BE_LONG),
};

fn php_array_sum_plus(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const xs = php.params.getArg(execute_data, 1) orelse return php.helpers.returnNull(return_value);
    const extra = php.params.getArg(execute_data, 2) orelse return php.helpers.returnNull(return_value);

    const arr = xs.toArray() orelse return php.helpers.returnNull(return_value);
    const extra_value = extra.toLong() orelse 0;

    // Iterate with ArrayIter; read long values through the raw union.
    var iter = php.hash.ArrayIter.init(arr);
    var sum: i64 = extra_value;
    while (iter.next()) |entry| {
        if (php.zval.getType(entry.value) != php.types.IS_LONG) continue;
        sum += entry.value.value.lval;
    }
    php.helpers.returnLong(return_value, sum);
}

const arginfo_array_first = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_LONG | php.types.MAY_BE_NULL),
    php.module.paramInfo("xs", php.types.MAY_BE_ARRAY),
};

fn php_array_first(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const xs = php.params.getArg(execute_data, 1) orelse return php.helpers.returnNull(return_value);
    const found = php.hash.findIndex(xs.raw(), 0) orelse return php.helpers.returnNull(return_value);
    if (php.zval.getType(found) != php.types.IS_LONG) return php.helpers.returnNull(return_value);
    php.helpers.returnLong(return_value, found.value.lval);
}

const arginfo_array_lookup = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_STRING | php.types.MAY_BE_NULL),
    php.module.paramInfo("xs", php.types.MAY_BE_ARRAY),
    php.module.paramInfo("key", php.types.MAY_BE_STRING),
};

fn php_array_lookup(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const xs = php.params.getArg(execute_data, 1) orelse return php.helpers.returnNull(return_value);
    const key = php.params.getArg(execute_data, 2) orelse return php.helpers.returnNull(return_value);
    const key_str = key.toString() orelse return php.helpers.returnNull(return_value);

    // Slice lookup is binary-safe; no NUL-termination requirement on the key.
    const found = php.hash.findString(xs.raw(), key_str) orelse
        return php.helpers.returnNull(return_value);

    php.zval.copy(return_value.?, found);
}

const extension_functions = [_]php.module.zend_function_entry{
    .{
        .fname = "build_array",
        .handler = php_build_array,
        .arg_info = &arginfo_build_array,
        .num_args = 0,
        .flags = 0,
    },
    .{
        .fname = "array_sum_plus",
        .handler = php_array_sum_plus,
        .arg_info = &arginfo_array_sum_plus,
        .num_args = 2,
        .flags = 0,
    },
    .{
        .fname = "array_first",
        .handler = php_array_first,
        .arg_info = &arginfo_array_first,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "array_lookup",
        .handler = php_array_lookup,
        .arg_info = &arginfo_array_lookup,
        .num_args = 2,
        .flags = 0,
    },
    php.module.function_entry_end,
};

export var my_module_entry = php.module.createModule(.{
    .name = "php_zig_arrays",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
