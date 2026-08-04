const php = @import("php");

// Array building and reading: returnArray/arrayPush*/arraySet*, nested arrays,
// ArrayIter iteration, and low-level hash lookups.

const arginfo_build_array = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_ARRAY),
};

fn php_build_array(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;

    php.returnArray(return_value, 8);
    php.arrayPushLong(return_value, 10);
    php.arrayPushString(return_value, "first");
    php.arrayPushBool(return_value, true);
    php.arrayPushNull(return_value);
    php.arraySetString(return_value, "name", "php-zig");
    php.arraySetDouble(return_value, "pi", 3.14159);
    php.arraySetLong(return_value, "answer", 42);

    // Nested array: build a child and move it in (no copy).
    var child = php.newArrayZval(2);
    php.arrayPushString(&child, "nested-a");
    php.arrayPushString(&child, "nested-b");
    php.arrayPushArrayOwned(return_value, &child);

    // Same, but under a string key.
    var child2 = php.newArrayZval(1);
    php.arrayPushLong(&child2, 99);
    php.arraySetArrayOwned(return_value, "child2", &child2);
}

const arginfo_array_sum_plus = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
    php.paramInfo("xs", php.MAY_BE_ARRAY),
    php.paramInfo("extra", php.MAY_BE_LONG),
};

fn php_array_sum_plus(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const xs = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const extra = php.getArg(execute_data, 2) orelse return php.returnNull(return_value);

    const arr = xs.toArray() orelse return php.returnNull(return_value);
    const extra_value = extra.toLong() orelse 0;

    // Iterate with ArrayIter; read long values through the raw union.
    var iter = php.ArrayIter.init(arr);
    var sum: i64 = extra_value;
    while (iter.next()) |entry| {
        if (php.zval.getType(entry.value) != php.IS_LONG) continue;
        sum += entry.value.value.lval;
    }
    php.returnLong(return_value, sum);
}

const arginfo_array_first = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG | php.MAY_BE_NULL),
    php.paramInfo("xs", php.MAY_BE_ARRAY),
};

fn php_array_first(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const xs = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const found = php.hash.findIndex(xs.raw(), 0) orelse return php.returnNull(return_value);
    if (php.zval.getType(found) != php.IS_LONG) return php.returnNull(return_value);
    php.returnLong(return_value, found.value.lval);
}

const arginfo_array_lookup = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_STRING | php.MAY_BE_NULL),
    php.paramInfo("xs", php.MAY_BE_ARRAY),
    php.paramInfo("key", php.MAY_BE_STRING),
};

fn php_array_lookup(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const xs = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const key = php.getArg(execute_data, 2) orelse return php.returnNull(return_value);
    const key_str = key.toString() orelse return php.returnNull(return_value);

    // PHP strings are NUL-terminated internally, so viewing the slice as a
    // `[*:0]const u8` is safe here (visible low-level cast).
    const found = php.hash.findStringKey(xs.raw(), @ptrCast(key_str.ptr)) orelse
        return php.returnNull(return_value);

    php.zval.copy(return_value.?, found);
}

const extension_functions = [_]php.zend_function_entry{
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
    php.function_entry_end,
};

export var my_module_entry = php.createModule(.{
    .name = "php_zig_arrays",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.zend_module_entry {
    return &my_module_entry;
}
