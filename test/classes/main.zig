const php = @import("php");
const defs = php.defs;
const std = @import("std");

// High-level declarative class: no manual arginfo, class entries or method
// tables. Each handler takes the per-class `Greeter.Self` as its first
// parameter (which carries `$this` for instance methods and static storage for
// static ones) and returns a plain Zig value. Properties/constants and the
// optional `flags` (final/abstract), `.parent` and `.implements` are declared
// from the spec.

// Interfaces must be registered (called in module_startup) BEFORE any class
// that implements them, hence an interface type is declared first and
// registered first.
const GreeterIface = defs.Interface("GreeterLike", .{});

const Greeter = defs.Class(.{
    .name = "Greeter",
    .implements = .{GreeterIface},
    .props = .{
        .name = "world",
        .greeting = "Hello",
    },
    .static_props = .{
        .count = 0,
    },
    .consts = .{ .VERSION = 100 },
    .methods = .{
        .__construct = defs.method(ctor, .{}),
        .greet = defs.method(greet, .{}),
        .bump = defs.method(bump, .{ .static = true }),
        .kind = defs.method(kind, .{ .static = true }),
    },
});

const FinalCounter = defs.Class(.{
    .name = "FinalCounter",
    .flags = .{ .final = true },
    .static_props = .{ .count = 0 },
    .methods = .{
        .tick = defs.method(tick, .{ .static = true }),
    },
});

const AbsBase = defs.Class(.{
    .name = "AbsBase",
    .flags = .{ .abstract = true },
    .props = .{ .value = 0 },
    .methods = .{},
});

fn ctor(self: anytype, name: ?[]const u8) void {
    self.prop("name").set(name orelse "world");
}

fn greet(self: anytype) void {
    const greeting = self.prop("greeting").get([]const u8) orelse "Hello";
    const name = self.prop("name").get([]const u8) orelse "?";

    var sw = self.return_string();
    sw.append(greeting);
    sw.append(" ");
    sw.append(name);
    sw.finish();
}

fn bump(self: anytype) i64 {
    const count = self.prop("count").ptr();
    count.value.lval += 1;
    return count.value.lval;
}

fn kind(self: anytype) []const u8 {
    _ = self;
    return "static";
}

fn tick(self: anytype) i64 {
    const count = self.prop("count").ptr();
    count.value.lval += 1;
    return count.value.lval;
}

fn module_startup(type_: c_int, module_number: c_int) callconv(.c) c_int {
    _ = type_;
    _ = module_number;
    // Interface-first ordering: `GreeterLike` registers before `Greeter`.
    const iface_ce = GreeterIface.register(&my_module_entry);
    const greeter_reg = Greeter.register(&my_module_entry);
    const counter_reg = FinalCounter.register(&my_module_entry);
    _ = AbsBase.register(&my_module_entry);

    // Acceptance (runtime, in the extension itself): flags and implemented.
    std.debug.assert(greeter_reg.ce.ce_flags & php.class.ZEND_ACC_FINAL == 0);
    std.debug.assert(counter_reg.ce.ce_flags & php.class.ZEND_ACC_FINAL != 0);
    std.debug.assert(greeter_reg.ce.ce_flags & php.class.ZEND_ACC_ABSTRACT == 0);
    std.debug.assert(greeter_reg.ce.num_interfaces == 1);
    const iface_table: [*]*php.types.zend_class_entry = @ptrCast(@alignCast(greeter_reg.ce.interfaces.?));
    std.debug.assert(iface_table[0] == iface_ce);
    return 1;
}

export var my_module_entry = php.module.createModule(.{
    .name = "php_zig_defs",
    .version = "1.0.0",
    .module_startup_func = module_startup,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
