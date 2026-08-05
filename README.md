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
const arginfo_hello = [_]php.module.zend_internal_arg_info{
    php.module.returnInfo(php.types.MAY_BE_STRING),
    php.module.paramInfo("name", php.types.MAY_BE_STRING),
};

// --- Handler ---
fn php_hello(
    execute_data: ?*php.types.zend_execute_data,
    return_value: ?*php.types.zval,
) callconv(.c) void {
    const param = php.params.getArg(execute_data, 1) orelse
        return php.helpers.returnNull(return_value);
    const name = param.toString() orelse return php.helpers.returnNull(return_value);
    php.helpers.returnString(return_value, name);
}

// --- Function table ---
const extension_functions = [_]php.module.zend_function_entry{
    .{
        .fname = "hello",
        .handler = php_hello,
        .arg_info = &arginfo_hello,
        .num_args = 1,
        .flags = 0,
    },
    php.module.function_entry_end,
};

// --- Module entry ---
export var my_module_entry = php.module.createModule(.{
    .name = "my_extension",
    .version = "1.0.0",
    .functions = &extension_functions,
});

export fn get_module() *php.module.zend_module_entry {
    return &my_module_entry;
}
```

| Symbol               | Lives at                                            |
| -------------------- | --------------------------------------------------- |
| `zval` type          | `php.types.zval`                                    |
| `IS_*` constants     | `php.types.IS_LONG`, ...                            |
| `MAY_BE_*` constants | `php.types.MAY_BE_STRING`                           |
| arginfo helpers      | `php.module.returnInfo`, `php.module.paramInfo*`    |
| zval operations      | `php.zval.setLong`, ...                             |
| ergonomic wrappers   | `php.helpers.returnLong`, ...                       |
| argument access      | `php.params.getArg`, `php.params.getArgCount`       |
| hash tables          | `php.hash.pushString`, ...                          |
| errors/exceptions    | `php.errors.throwException`, `php.errors.E_WARNING` |
| constants            | `php.constants.registerLong`                        |
| raw FFI              | `php.ffi._emalloc`, ...                             |

## API Reference

### Types

| Type                     | Lives at                            | Description            |
| ------------------------ | ----------------------------------- | ---------------------- |
| `zval`                   | `php.types.zval`                    | PHP value container    |
| `zend_array`             | `php.types.zend_array`              | PHP array / HashTable  |
| `zend_string`            | `php.types.zend_string`             | PHP string             |
| `zend_execute_data`      | `php.types.zend_execute_data`       | Function call context  |
| `zend_module_entry`      | `php.module.zend_module_entry`      | Module descriptor      |
| `zend_function_entry`    | `php.module.zend_function_entry`    | Function descriptor    |
| `zend_internal_arg_info` | `php.module.zend_internal_arg_info` | Argument type info     |
| `zend_reference`         | `php.types.zend_reference`          | Reference box (`&`)    |
| `Param`                  | `php.params.Param`                  | Borrowed argument view |
| `ArrayIter`              | `php.hash.ArrayIter`                | Array iterator         |

### Type Constants

```zig
php.types.IS_NULL, IS_FALSE, IS_TRUE, IS_LONG, IS_DOUBLE, IS_STRING,
php.types.IS_ARRAY, IS_OBJECT, IS_RESOURCE, IS_REFERENCE
```

`zval.u1.type_info` packs `type | (flags << 8)` — use
`php.zval.typeInfo(type, flags)` instead of hardcoding values.

### MAY*BE*\* Constants (for arginfo)

```zig
php.types.MAY_BE_NULL, MAY_BE_FALSE, MAY_BE_TRUE, MAY_BE_LONG,
php.types.MAY_BE_DOUBLE, MAY_BE_STRING, MAY_BE_ARRAY, MAY_BE_OBJECT
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
pub fn paramInfoByRef(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info
pub fn paramInfoByRefOptional(name: [*:0]const u8, type_mask: u32, default_value: [*:0]const u8) zend_internal_arg_info
pub fn paramInfoVariadic(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info
pub fn paramInfoVariadicByRef(name: [*:0]const u8, type_mask: u32) zend_internal_arg_info

// Sentinel to end the function table
pub const function_entry_end: zend_function_entry
```

By-reference (`&$arg`) and variadic (`...$arg`) parameters encode send-mode/variadic
markers in the high bits of the type mask (`ZEND_SEND_BY_REF = 1<<24`,
`ZEND_PREFER_REF = 2<<24`, `ZEND_IS_VARIADIC_BIT = 1<<26`). Reflection reports
these faithfully (`ReflectionParameter::isPassedByReference()`, `isVariadic()`).

### References (`zval` primitives)

```zig
// zval reference helpers
php.zval.isRef;          // zval.u1.v.type == IS_REFERENCE
php.zval.makeRef;        // ZVAL_MAKE_REF — box zv in place (_emalloc)
php.zval.derefValue;     // pointer to the boxed zval
php.zval.GC_REFERENCE;   // 26 = IS_REFERENCE | GC_NOT_COLLECTABLE
```

`zend_reference` is a 32-byte box (`gc` + `val` + `sources`) built by hand with
`_emalloc` — PHP 8.0 does not export a `zend_make_ref` symbol. `makeRef` moves the
zval's current payload into the box without an incref. `Param` gains `isRef()` /
`deref()` / `toRef()` for by-ref arguments.

### Return Helpers

```zig
php.helpers.returnNull(return_value: ?*zval) void
php.helpers.returnTrue(return_value: ?*zval) void
php.helpers.returnFalse(return_value: ?*zval) void
php.helpers.returnLong(return_value: ?*zval, val: i64) void
php.helpers.returnDouble(return_value: ?*zval, val: f64) void
php.helpers.returnString(return_value: ?*zval, s: []const u8) void
php.helpers.returnStringZ(return_value: ?*zval, s: [*:0]const u8) void
php.helpers.returnArray(return_value: ?*zval, reserve: u32) void
```

### Array Helpers (numeric index)

```zig
php.helpers.arrayPushNull(arr: ?*zval) void
php.helpers.arrayPushBool(arr: ?*zval, val: bool) void
php.helpers.arrayPushLong(arr: ?*zval, val: i64) void
php.helpers.arrayPushDouble(arr: ?*zval, val: f64) void
php.helpers.arrayPushString(arr: ?*zval, val: []const u8) void   // binary-safe
php.helpers.arrayPushStringZ(arr: ?*zval, val: [*:0]const u8) void
php.helpers.arrayPushArray(parent: ?*zval, child: *zval) void
```

### Array Helpers (string key)

```zig
php.helpers.arraySetNull(arr: ?*zval, key: []const u8) void
php.helpers.arraySetBool(arr: ?*zval, key: []const u8, val: bool) void
php.helpers.arraySetLong(arr: ?*zval, key: []const u8, val: i64) void
php.helpers.arraySetDouble(arr: ?*zval, key: []const u8, val: f64) void
php.helpers.arraySetString(arr: ?*zval, key: []const u8, val: []const u8) void
php.helpers.arraySetStringZ(arr: ?*zval, key: []const u8, val: [*:0]const u8) void
php.helpers.arraySetArray(parent: ?*zval, key: []const u8, child: *zval) void
```

String values are binary-safe (`[]const u8`); the `*Z` variants take null-terminated C
strings. Keys are binary-safe `[]const u8` (PHP array keys may contain `\0`).

### Array Creation

```zig
// Create a new zval of type array ready to insert into another array
php.helpers.newArrayZval(reserve: u32) zval
```

The returned zval owns one reference. Pass it to `arrayPushArray` /
`arraySetArray` (which take a copy, keeping it usable) or to `php.hash.pushArrayOwned` /
`php.hash.setArrayOwned` (which move it).

### Reading Parameters

```zig
// Get argument N (1-based) from execute_data
php.params.getArg(execute_data: ?*zend_execute_data, n: usize) ?Param

// Get number of arguments passed by PHP
php.params.getArgCount(execute_data: ?*zend_execute_data) u32

// Param methods:
pub fn paramType(self: Param) ParamType
pub fn toLong(self: Param) ?i64
pub fn toDouble(self: Param) ?f64
pub fn toBool(self: Param) ?bool
pub fn toString(self: Param) ?[]const u8
pub fn toArray(self: Param) ?*zend_array
pub fn isRef(self: Param) bool
pub fn deref(self: Param) *zval
pub fn toRef(self: Param) ?*zend_reference
pub fn raw(self: Param) *zval
```

### Array Iteration

```zig
var iter = php.hash.ArrayIter.init(arr);
while (iter.next()) |entry| {
    // entry.key  — ArrayKey (.index: i64 or .string: []const u8)
    // entry.value — *zval
}

pub fn count(self: *ArrayIter) u32
```

Iteration order is PHP's hash-table order. `ArrayEntry` is the named type of
each yielded element.

### Constants

Register constants from `module_startup_func`:

```zig
php.constants.registerLong(name: [*:0]const u8, value: i64, module_number: c_int) void
php.constants.registerDouble(name: [*:0]const u8, value: f64, module_number: c_int) void
php.constants.registerString(name: [*:0]const u8, value: [*:0]const u8, module_number: c_int) void
php.constants.registerBool(name: [*:0]const u8, value: bool, module_number: c_int) void
```

Example:

```zig
fn module_startup(type_: c_int, module_number: c_int) callconv(.c) c_int {
    _ = type_;
    php.constants.registerLong("MY_EXT_VERSION", 1, module_number);
    php.constants.registerString("MY_EXT_NAME", "my_extension", module_number);
    return 1;
}
```

## Low-Level API

The helpers above are thin wrappers — nothing is hidden. Every submodule is
public and exposes the raw primitives for power users:

| Module          | Contents                                                                                                                                                                                 |
| --------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `php.ffi`       | Every raw `extern fn` / `@extern` against PHP (cross-platform names, incl. Windows `@@N` decoration). `externDecl` resolves a symbol name per-OS.                                        |
| `php.types`     | Hand-rolled `extern struct`s matching the PHP 8.0 ZTS ABI + `IS_*`/`MAY_BE_*` constants. The `zval` type lives here.                                                                     |
| `php.zval`      | zval operations: `setNull/True/False/Long/Double/String/Array`, `getType`, `typeInfo`, `copy`, `addRef`, `release`, `isRefcounted`, `isRef`, `makeRef`, `derefValue`.                    |
| `php.string`    | `zend_string` allocation/viewing: `alloc`, `dup`, `free`, `slice`. Strings are built with `_emalloc`/`_efree` because `zend_string_init` is not exported by the Linux PHP 8.0 binary.    |
| `php.hash`      | Hash-table ops: `push*`/`set*`, `pushArrayOwned`/`setArrayOwned` (move), `findString` (binary-safe keys), `findIndex`, `count`, `ArrayIter`, `ArrayKey`, `ArrayEntry`.                   |
| `php.params`    | `Param` (borrowed zval view), `getArg`, `getArgCount`, `isRef`/`deref`/`toRef`. Argument lookup derives the offset from `@sizeOf(types.zend_execute_data)` — the single source of truth. |
| `php.module`    | `zend_module_entry`, `zend_function_entry`, `zend_internal_arg_info`, `createModule`, arginfo helpers (incl. by-ref/variadic), `ZEND_API`/`BUILD_ID`.                                    |
| `php.constants` | `registerLong/Double/String/Bool`, `CONST_CS`, `CONST_PERSISTENT`.                                                                                                                       |
| `php.errors`    | Error levels (`E_WARNING`, ...), `throwException/throwError/throwTypeError/throwValueError`, `phpError`. Uses the built-in `Exception`/`Error` class entries.                            |

### Ownership model

- `php.zval.isRefcounted`, `php.zval.addRef`, `php.zval.release` are the explicit reference primitives.
- `arrayPushArray`/`arraySetArray` copy via `php.zval.copy` (the array takes a new
  reference; your zval stays valid).
- `php.hash.pushArrayOwned`/`php.hash.setArrayOwned` transfer ownership (the array owns
  the reference; do not touch the source afterwards).
- `newArrayZval` returns a zval you own; hand it to a `*Owned` helper to move it.
- `php.zval.makeRef` moves the current payload into a reference box without an incref.

## Tests

Comptime ABI-layout checks (no PHP needed):

```sh
zig build test
```

The `test/` folder holds seven runnable PHP extensions (each with a
`main.zig` + `test.php` consumer), covering the helper layer and the
low-level primitives:

| Extension    | Exercises                                                              |
| ------------ | ---------------------------------------------------------------------- |
| `hello`      | module entry, arginfo, scalar returns, arguments                       |
| `arrays`     | array build/push/set, `ArrayIter`, lookups, owned moves                |
| `strings`    | binary-safe returns, hand-allocated `zend_string`s                     |
| `constants`  | constant registration in module startup, optional params               |
| `lowlevel`   | raw FFI calls, hand-built zvals, explicit refcounts                    |
| `errors`     | throwing exceptions/errors, `phpError` levels via a user error handler |
| `references` | by-ref mutation (`&`), variadic args, reflection reporting             |

Run them against the local PHP 8.0 ZTS binary. You must have the PHP 8.0
binaries available — the same ones used for development, from
[PHP-Binaries](https://github.com/Benedikt05/PHP-Binaries) (BetterAltay's PHP 8.0
builds). Place them in the repo root in a folder named after your platform:

| Platform | Repo-root folder | Expected layout inside                        |
| -------- | ---------------- | --------------------------------------------- |
| Linux    | `linux-bin/`     | `linux-bin/php7/bin/php` (8.0.13 ZTS binary)  |
| Windows  | `win-bin/`       | `win-bin/php/` — the dev pack (`php.exe`, `dev/php8ts.lib`) |

Then run:

```sh
zig build test-ext
```

Or invoke one by hand from the repo root:

```sh
php -n -d extension=./zig-out/lib/libphp_zig_hello.so test/hello/test.php
```

## Cross-Platform Notes

php-zig handles symbol name differences between Linux and Windows automatically. On Windows you need to provide the path to the PHP development pack containing `php8ts.lib`. On Linux symbols are resolved at runtime by the PHP loader.

## License

MIT © [VantStudios](https://github.com/VantStudios)
