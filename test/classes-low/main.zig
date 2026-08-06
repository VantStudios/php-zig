const php = @import("php");

// Class registration, instances, properties and class constants.

var greeter_ce: *php.types.zend_class_entry = undefined;

fn module_startup(type_: c_int, module_number: c_int) callconv(.c) c_int {
    _ = type_;
    _ = module_number;

    greeter_ce = php.class.registerClass("Greeter", &greeter_methods);
    php.class.setModule(greeter_ce, &my_module_entry);

    var default_name: php.types.zval = undefined;
    php.zval.setInternedString(&default_name, "world");
    php.class.declareProperty(greeter_ce, "name", &default_name, php.class.ZEND_ACC_PUBLIC);

    var default_greeting: php.types.zval = undefined;
    php.zval.setInternedString(&default_greeting, "Hello");
    php.class.declareProperty(greeter_ce, "greeting", &default_greeting, php.class.ZEND_ACC_PUBLIC);

    var zero: php.types.zval = undefined;
    php.zval.setLong(&zero, 0);
    php.class.declareProperty(greeter_ce, "count", &zero, php.class.ZEND_ACC_PUBLIC | php.class.ZEND_ACC_STATIC);

    var version: php.types.zval = undefined;
    php.zval.setLong(&version, 100);
    php.class.declareClassConstant(greeter_ce, "VERSION", &version, php.class.ZEND_ACC_PUBLIC);
    return 1;
}

const arginfo_ctor = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(0),
};

fn php_greeter_ctor(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    php.helpers.returnNull(return_value);
    const ed = execute_data orelse return;
    const name = if (php.params.getArgCount(execute_data) > 0)
        php.params.getArg(execute_data, 1) orelse return
    else
        null;
    const name_str = if (name) |a| a.toString() orelse "world" else "world";
    var v: php.types.zval = undefined;
    php.zval.setString(&v, name_str);
    php.object.updateProperty(&ed.this, "name", &v);
}

const arginfo_greet = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_STRING),
};

fn php_greet(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const ed = execute_data orelse return php.helpers.returnNull(return_value);
    var name_rv: php.types.zval = undefined;
    const pv = php.object.readProperty(&ed.this, "name", &name_rv) orelse
        return php.helpers.returnNull(return_value);
    if (php.zval.getType(pv) != php.types.IS_STRING) return php.helpers.returnNull(return_value);
    const name = php.string.slice(pv.value.str orelse return php.helpers.returnNull(return_value));

    var greet_rv: php.types.zval = undefined;
    const gv = php.object.readProperty(&ed.this, "greeting", &greet_rv) orelse
        return php.helpers.returnNull(return_value);
    const greeting = if (php.zval.getType(gv) == php.types.IS_STRING)
        php.string.slice(gv.value.str.?)
    else
        "Hello";

    const out = php.string.alloc(greeting.len + name.len + 1);
    const val_ptr: [*]u8 = @ptrCast(&out.val[0]);
    @memcpy(val_ptr[0..greeting.len], greeting);
    val_ptr[greeting.len] = ' ';
    @memcpy(val_ptr[greeting.len + 1 .. greeting.len + 1 + name.len], name);
    val_ptr[greeting.len + 1 + name.len] = 0;

    const rv = return_value orelse return;
    rv.value.str = out;
    rv.u1.type_info = php.zval.typeInfo(php.types.IS_STRING, php.zval.Z_TYPE_FLAG_REFCOUNTED);
}

const arginfo_bump = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_LONG),
};

fn php_bump(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    const cur = php.object.readStaticProperty(greeter_ce, "count") orelse
        return php.helpers.returnLong(return_value, -1);
    const n = cur.value.lval + 1;
    var v: php.types.zval = undefined;
    php.zval.setLong(&v, n);
    php.object.updateStaticProperty(greeter_ce, "count", &v);
    php.helpers.returnLong(return_value, n);
}

const arginfo_kind = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_STRING),
};

fn php_kind(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    _ = execute_data;
    php.helpers.returnString(return_value, "static");
}

const arginfo_make = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_OBJECT),
    php.module.paramInfo("name", php.types.MAY_BE_STRING),
};

fn php_make_greeter(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const rv = return_value orelse return;
    php.object.init(rv, greeter_ce);
    const arg = php.params.getArg(execute_data, 1);
    if (arg) |a| if (a.toString()) |nm| {
        var v: php.types.zval = undefined;
        php.zval.setString(&v, nm);
        php.object.updateProperty(rv, "name", &v);
    };
}

const greeter_methods = [_]php.module.zend_function_entry{
    php.class.method("__construct", php_greeter_ctor, &arginfo_ctor, php.class.ZEND_ACC_PUBLIC),
    php.class.method("greet", php_greet, &arginfo_greet, php.class.ZEND_ACC_PUBLIC),
    php.class.method("bump", php_bump, &arginfo_bump, php.class.ZEND_ACC_PUBLIC | php.class.ZEND_ACC_STATIC),
    php.class.method("kind", php_kind, &arginfo_kind, php.class.ZEND_ACC_PUBLIC | php.class.ZEND_ACC_STATIC),
    php.module.function_entry_end,
};

const extension_functions = [_]php.module.zend_function_entry{
    .{
        .fname = "make_greeter",
        .handler = php_make_greeter,
        .arg_info = &arginfo_make,
        .num_args = 1,
        .flags = 0,
    },
    php.module.function_entry_end,
};

export var my_module_entry = php.module.createModule(.{
    .name = "php_zig_classes",
    .version = "1.0.0",
    .functions = &extension_functions,
    .module_startup_func = module_startup,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
