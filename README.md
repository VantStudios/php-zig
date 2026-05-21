# php-zig 

A Zig library for building PHP extensions. Provides cross-platform bindings and helpers for PHP 8.0 internals without requiring PHP headers.

> **Note:** This library has been tested exclusively with **PHP 8.0 ZTS** (Thread Safe) on Linux and Windows x86_64. NTS builds and other PHP versions have not been tested and may require adjustments.

## Requirements

- Zig 0.16.0+
- PHP 8.0 ZTS
- On Windows: `php8ts.lib` from the PHP development pack

## PHP Binaries

The PHP binaries used to develop and test this library:
[https://github.com/Benedikt05/PHP-Binaries](https://github.com/Benedikt05/PHP-Binaries)

## Installation

Add `php-zig` as a dependency in your `build.zig.zon`:

```zig
.dependencies = .{
    .@"php-zig" = .{
        .url = "https://github.com/VantStudios/php-zig/archive/refs/tags/v0.1.0.tar.gz",
        .hash = "...",
        // or locally:
        // .path = "../php-zig",
    },
},
```

In your `build.zig`:

```zig
const std = @import("std");
const php_zig = @import("php-zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "my_extension",
        .linkage = .dynamic,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const php_dep = b.dependency("php-zig", .{
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("php", php_dep.module("php"));

    // Handles cross-platform linking automatically
    if (target.result.os.tag == .windows) {
        php_zig.link(b, lib, "path/to/php"); // folder containing php8ts.lib under /dev
    } else {
        php_zig.link(b, lib, "");
    }

    b.installArtifact(lib);
}
```

## Quick Start

```zig
const php = @import("php");

// --- Arginfo ---
const arginfo_hello = [_]php.zend_internal_arg_info{
    php.returnInfo(php.MAY_BE_STRING),
    php.paramInfo("name", php.MAY_BE_STRING),
};

// --- Handler ---
fn php_hello(
    execute_data: ?*php.zend_execute_data,
    return_value: ?*php.zval,
) callconv(.c) void {
    const param = php.getArg(execute_data, 1) orelse return php.returnNull(return_value);
    const name = param.toString() orelse return php.returnNull(return_value);
    php.returnString(return_value, name);
}

// --- Function table ---
const extension_functions = [_]php.zend_function_entry{
    .{
        .fname = "hello",
        .handler = php_hello,
        .arg_info = @ptrCast(&arginfo_hello),
        .num_args = 1,
        .flags = 0,
    },
    php.function_entry_end,
};

// --- Module entry ---
export var my_module_entry = php.createModule(.{
    .name = "my_extension",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.zend_module_entry {
    return &my_module_entry;
}
```

## API Reference

### Types

| Type | Description |
|------|-------------|
| `zval` | PHP value container |
| `zend_array` | PHP array / HashTable |
| `zend_string` | PHP string |
| `zend_execute_data` | Function call context |
| `zend_module_entry` | Module descriptor |
| `zend_function_entry` | Function descriptor |
| `zend_internal_arg_info` | Argument type info |

### Type Constants

```zig
IS_NULL, IS_FALSE, IS_TRUE, IS_LONG, IS_DOUBLE, IS_STRING, IS_ARRAY, IS_OBJECT
IS_ARRAY_EX, IS_STRING_EX, IS_STRING_INTERNED
```

### MAY_BE_* Constants (for arginfo)

```zig
MAY_BE_NULL, MAY_BE_FALSE, MAY_BE_TRUE, MAY_BE_LONG,
MAY_BE_DOUBLE, MAY_BE_STRING, MAY_BE_ARRAY, MAY_BE_OBJECT
```

### Module

```zig
// Create a module entry
pub fn createModule(opts: ModuleOptions) zend_module_entry

// ModuleOptions fields:
// .name                    — extension name
// .version                 — extension version
// .functions               — pointer to function table
// .zts                     — thread safety (default: 1)
// .module_startup_func     — called on module load (optional)
// .module_shutdown_func    — called on module unload (optional)
// .request_startup_func    — called on each request start (optional)
// .request_shutdown_func   — called on each request end (optional)

// Arginfo helpers
pub fn returnInfo(type_mask: u32) zend_internal_arg_info
pub fn paramInfo(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info
pub fn paramInfoOptional(name: [*:0]const u8, type_mask: u32, default_value: [*:0]const u8) zend_internal_arg_info

// Sentinel to end the function table
pub const function_entry_end: zend_function_entry
```

### Return Helpers

```zig
pub fn returnNull(return_value: ?*zval) void
pub fn returnTrue(return_value: ?*zval) void
pub fn returnFalse(return_value: ?*zval) void
pub fn returnLong(return_value: ?*zval, val: i64) void
pub fn returnDouble(return_value: ?*zval, val: f64) void
pub fn returnString(return_value: ?*zval, s: []const u8) void
pub fn returnStringZ(return_value: ?*zval, s: [*:0]const u8) void
pub fn returnArray(return_value: ?*zval, reserve: u32) void
```

### Array Helpers (numeric index)

```zig
pub fn arrayPushNull(arr: ?*zval) void
pub fn arrayPushBool(arr: ?*zval, val: bool) void
pub fn arrayPushLong(arr: ?*zval, val: i64) void
pub fn arrayPushDouble(arr: ?*zval, val: f64) void
pub fn arrayPushString(arr: ?*zval, val: [*:0]const u8) void
pub fn arrayPushArray(parent: ?*zval, child: *zval) void
pub fn arrayPushBinary(arr: ?*zval, val: []const u8) void
```

### Array Helpers (string key)

```zig
pub fn arraySetNull(arr: ?*zval, key: [*:0]const u8) void
pub fn arraySetBool(arr: ?*zval, key: [*:0]const u8, val: bool) void
pub fn arraySetLong(arr: ?*zval, key: [*:0]const u8, val: i64) void
pub fn arraySetDouble(arr: ?*zval, key: [*:0]const u8, val: f64) void
pub fn arraySetString(arr: ?*zval, key: [*:0]const u8, val: [*:0]const u8) void
pub fn arraySetArray(parent: ?*zval, key: [*:0]const u8, child: *zval) void
pub fn arraySetBinary(arr: ?*zval, key: [*:0]const u8, val: []const u8) void
```

### Array Creation

```zig
// Create a new zval of type array ready to insert into another array
pub fn newArrayZval(reserve: u32) zval
```

### Reading Parameters

```zig
// Get argument N (1-based) from execute_data
pub fn getArg(execute_data: ?*zend_execute_data, n: usize) ?Param

// Get number of arguments passed by PHP
pub fn getArgCount(execute_data: ?*zend_execute_data) u32

// Param methods:
pub fn paramType(self: Param) ParamType
pub fn toLong(self: Param) ?i64
pub fn toDouble(self: Param) ?f64
pub fn toBool(self: Param) ?bool
pub fn toString(self: Param) ?[]const u8
pub fn toArray(self: Param) ?*zend_array
pub fn raw(self: Param) *zval
```

### Array Iteration

```zig
var iter = ArrayIter.init(arr);
while (iter.next()) |entry| {
    // entry.key  — ArrayKey (.index: i64 or .string: []const u8)
    // entry.value — *zval
}

pub fn count(self: *ArrayIter) u32
```

### Constants

Register constants from `module_startup_func`:

```zig
pub fn registerLong(name: [*:0]const u8, value: i64, module_number: c_int) void
pub fn registerDouble(name: [*:0]const u8, value: f64, module_number: c_int) void
pub fn registerString(name: [*:0]const u8, value: [*:0]const u8, module_number: c_int) void
pub fn registerBool(name: [*:0]const u8, value: bool, module_number: c_int) void
```

Example:

```zig
fn module_startup(type_: c_int, module_number: c_int) callconv(.c) c_int {
    _ = type_;
    php.registerLong("MY_EXT_VERSION", 1, module_number);
    php.registerString("MY_EXT_NAME", "my_extension", module_number);
    return 1;
}
```

## Cross-Platform Notes

php-zig handles symbol name differences between Linux and Windows automatically. On Windows you need to provide the path to the PHP development pack containing `php8ts.lib`. On Linux symbols are resolved at runtime by the PHP loader.

## License

MIT © [VantStudios](https://github.com/VantStudios)
