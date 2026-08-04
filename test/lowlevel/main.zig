const std = @import("std");

const php = @import("php");

// Low-level API demo: raw FFI calls, hand-built zval structs, explicit
// refcounts, and ownership transfer. Nothing here is hidden behind helpers.

const arginfo_raw_build = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_ARRAY),
};

fn php_raw_build(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    const rv = return_value orelse return;

    // Inner array via the ergonomic helpers.
    var inner = php.newArrayZval(2);
    php.arrayPushLong(&inner, 7);
    php.arrayPushStringZ(&inner, "seven");

    // Outer array built by hand: zeroed zval + explicit type_info.
    var outer: php.types.zval = std.mem.zeroes(php.types.zval);
    outer.value.arr = php.ffi._zend_new_array(3);
    outer.u1.type_info = php.zval.typeInfo(
        php.IS_ARRAY,
        php.Z_TYPE_FLAG_REFCOUNTED | php.Z_TYPE_FLAG_COLLECTABLE,
    );

    php.arraySetLong(&outer, "answer", 42);

    // Move the inner array in: no copy, ownership transfers.
    php.hash.pushArrayOwned(&outer, &inner);

    // Insert a raw string under "data" using the FFI layer directly.
    const str = php.string.dup("raw bytes") orelse return php.returnNull(return_value);
    var sv: php.types.zval = std.mem.zeroes(php.types.zval);
    sv.value.str = str;
    sv.u1.type_info = php.zval.typeInfo(php.IS_STRING, php.Z_TYPE_FLAG_REFCOUNTED);
    _ = php.ffi.zend_hash_str_update(outer.value.arr, "data", 4, &sv);

    // Hand the built zval to the return slot (outer owns the references).
    rv.* = outer;
}

const arginfo_raw_find = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_STRING | php.MAY_BE_NULL),
    php.paramInfo("arr", php.MAY_BE_ARRAY),
};

fn php_raw_find(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const arr = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const found = php.hash.findStringKey(arr.raw(), "data") orelse
        return php.returnNull(return_value);

    // Copy the borrowed zval into the return slot (takes a new reference).
    php.zval.copy(return_value.?, found);
}

const arginfo_raw_refcount = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_ARRAY),
    php.paramInfo("s", php.MAY_BE_STRING),
};

fn php_raw_refcount(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const s = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const sv = s.toString() orelse return php.returnNull(return_value);

    var zv: php.types.zval = std.mem.zeroes(php.types.zval);
    php.zval.setString(&zv, sv); // string with refcount 1
    const before = zv.value.str.?.gc.refcount;

    php.zval.addRef(&zv); // explicit +1
    const after = zv.value.str.?.gc.refcount;

    php.zval.release(&zv); // back to 1; zv must not be touched afterwards

    php.returnArray(return_value, 2);
    php.arrayPushLong(return_value, before);
    php.arrayPushLong(return_value, after);
}

const arginfo_raw_manipulate = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG | php.MAY_BE_NULL),
    php.paramInfo("x", php.MAY_BE_LONG),
};

fn php_raw_manipulate(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const arg = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    if (php.zval.getType(arg.raw()) != php.IS_LONG) return php.returnNull(return_value);

    // Raw union read straight from the zval.
    php.returnLong(return_value, arg.raw().value.lval * 2);
}

const arginfo_raw_argcount = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_LONG),
};

fn php_raw_argcount(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    php.returnLong(return_value, php.getArgCount(execute_data));
}

const extension_functions = [_]php.zend_function_entry{
    .{
        .fname = "raw_build",
        .handler = php_raw_build,
        .arg_info = &arginfo_raw_build,
        .num_args = 0,
        .flags = 0,
    },
    .{
        .fname = "raw_find",
        .handler = php_raw_find,
        .arg_info = &arginfo_raw_find,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "raw_refcount",
        .handler = php_raw_refcount,
        .arg_info = &arginfo_raw_refcount,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "raw_manipulate",
        .handler = php_raw_manipulate,
        .arg_info = &arginfo_raw_manipulate,
        .num_args = 1,
        .flags = 0,
    },
    .{
        .fname = "raw_argcount",
        .handler = php_raw_argcount,
        .arg_info = &arginfo_raw_argcount,
        .num_args = 0,
        .flags = 0,
    },
    php.function_entry_end,
};

export var my_module_entry = php.createModule(.{
    .name = "php_zig_lowlevel",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.zend_module_entry {
    return &my_module_entry;
}
