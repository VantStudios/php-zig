const php = @import("php");
const defs = php.defs;
const std = @import("std");

// Exercises interfaces declared with real method signatures (defs.signature).
// An interface is registered externally (visible to PHP userland code), so it
// can be implemented from two sides:
//   1. internally, by a Zig `defs.Class` declaring `.implements` (with
//      `defs.method` bodies for each signature);
//   2. externally, by a PHP userland `class Foo implements GreeterContract`.
// The PHP engine enforces that every implementing class provides a body for
// each abstract method (a fatal otherwise).

const GreeterContract = defs.Interface("GreeterContract", .{
    .methods = .{
        .greet = defs.signature(fn (name: []const u8) []const u8, .{}),
        .version = defs.signature(fn () i64, .{}),
    },
});

const ZigGreeter = defs.Class(.{
    .name = "ZigGreeter",
    .implements = .{GreeterContract},
    .methods = .{
        .greet = defs.method(greet, .{}),
        .version = defs.method(version, .{}),
    },
});

fn greet(self: anytype, name: []const u8) []const u8 {
    _ = self;
    // Build "Hello, <name>" into a refcounted zend_string; `writeReturn` copies
    // the returned slice (via string.dup) before the handler returns, so the
    // emallocated string never escapes the extension boundary.
    const prefix = "Hello, ";
    const str1 = php.string.alloc(prefix.len + name.len);
    const dst: [*]u8 = @ptrCast(&str1.val[0]);
    @memcpy(dst[0..prefix.len], prefix);
    @memcpy(dst[prefix.len..], name);
    return dst[0 .. prefix.len + name.len];
}

fn version(self: anytype) i64 {
    _ = self;
    return 2;
}

fn module_startup(type_: c_int, module_number: c_int) callconv(.c) c_int {
    _ = type_;
    _ = module_number;
    // Interface-first ordering: the contract registers before the class.
    const iface_ce = GreeterContract.register(&my_module_entry);
    const greeter_reg = ZigGreeter.register(&my_module_entry);

    // Acceptance (runtime, in the extension itself): one implemented interface,
    // pointing at the registered contract's class entry.
    std.debug.assert(greeter_reg.ce.num_interfaces == 1);
    const iface_table: [*]*php.types.zend_class_entry = @ptrCast(@alignCast(greeter_reg.ce.interfaces.?));
    std.debug.assert(iface_table[0] == iface_ce);
    return 1;
}

export var my_module_entry = php.module.createModule(.{
    .name = "php_zig_interface",
    .version = "1.0.0",
    .module_startup_func = module_startup,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
