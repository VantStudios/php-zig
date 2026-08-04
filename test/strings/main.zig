const std = @import("std");

const php = @import("php");

// Strings: binary-safe returns, low-level zend_string allocation, and the
// string slice view.

const arginfo_str_len = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
    php.paramInfo("s", php.MAY_BE_STRING),
};

fn php_str_len(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const s = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const sv = s.toString() orelse return php.returnNull(return_value);
    php.returnLong(return_value, @intCast(sv.len));
}

const arginfo_binary_echo = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_STRING),
    php.paramInfo("s", php.MAY_BE_STRING),
};

fn php_binary_echo(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const s = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const sv = s.toString() orelse return php.returnNull(return_value);
    // Slice-based return is binary-safe (embedded NULs survive).
    php.returnString(return_value, sv);
}

const arginfo_repeat_str = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_STRING),
    php.paramInfo("s", php.MAY_BE_STRING),
    php.paramInfo("n", php.MAY_BE_LONG),
};

fn php_repeat_str(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const s = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const n = php.getArg(execute_data, 2) orelse return php.returnNull(return_value);

    const sv = s.toString() orelse return php.returnNull(return_value);
    const n_value = n.toLong() orelse return php.returnNull(return_value);
    if (n_value <= 0 or sv.len == 0) return php.returnString(return_value, "");
    if (n_value > 1024) return php.returnNull(return_value); // cap to avoid overflow

    const n_usize: usize = @intCast(n_value);
    const total = sv.len * n_usize;

    // Low-level path: allocate a zend_string by hand, fill it, and hand the
    // reference directly to the return slot (no copy).
    const out = php.string.alloc(total) orelse return php.returnNull(return_value);
    const val_ptr: [*]u8 = @ptrCast(&out.val[0]);
    var i: usize = 0;
    while (i < n_usize) : (i += 1) {
        @memcpy(val_ptr[(i * sv.len)..((i + 1) * sv.len)], sv);
    }
    val_ptr[total] = 0;

    const rv = return_value orelse return;
    rv.value.str = out;
    rv.u1.type_info = php.zval.typeInfo(php.IS_STRING, php.Z_TYPE_FLAG_REFCOUNTED);
}

const arginfo_concat3 = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_STRING),
    php.paramInfo("a", php.MAY_BE_STRING),
    php.paramInfo("b", php.MAY_BE_STRING),
    php.paramInfo("c", php.MAY_BE_STRING),
};

fn php_concat3(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const a = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const b = php.getArg(execute_data, 2) orelse return php.returnNull(return_value);
    const c = php.getArg(execute_data, 3) orelse return php.returnNull(return_value);

    const av = a.toString() orelse return php.returnNull(return_value);
    const bv = b.toString() orelse return php.returnNull(return_value);
    const cv = c.toString() orelse return php.returnNull(return_value);

    const total = av.len + bv.len + cv.len;
    const out = php.string.alloc(total) orelse return php.returnNull(return_value);
    const val_ptr: [*]u8 = @ptrCast(&out.val[0]);
    @memcpy(val_ptr[0..av.len], av);
    @memcpy(val_ptr[av.len .. av.len + bv.len], bv);
    @memcpy(val_ptr[av.len + bv.len .. total], cv);
    val_ptr[total] = 0;

    const rv = return_value orelse return;
    rv.value.str = out;
    rv.u1.type_info = php.zval.typeInfo(php.IS_STRING, php.Z_TYPE_FLAG_REFCOUNTED);
}

const extension_functions = [_]php.zend_function_entry{
    .{
        .fname = "str_len",
        .handler = php_str_len,
        .arg_info = &arginfo_str_len,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "binary_echo",
        .handler = php_binary_echo,
        .arg_info = &arginfo_binary_echo,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "repeat_str",
        .handler = php_repeat_str,
        .arg_info = &arginfo_repeat_str,
        .num_args = 2,
        .flags = 0,
    },
    .{
        .fname = "concat3",
        .handler = php_concat3,
        .arg_info = &arginfo_concat3,
        .num_args = 3,
        .flags = 0,
    },
    php.function_entry_end,
};

export var my_module_entry = php.createModule(.{
    .name = "php_zig_strings",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.zend_module_entry {
    return &my_module_entry;
}
