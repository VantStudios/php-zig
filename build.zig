const std = @import("std");

const test_extensions = [_]struct { name: []const u8, dir: []const u8 }{
    .{ .name = "php_zig_hello", .dir = "test/hello" },
    .{ .name = "php_zig_arrays", .dir = "test/arrays" },
    .{ .name = "php_zig_strings", .dir = "test/strings" },
    .{ .name = "php_zig_constants", .dir = "test/constants" },
    .{ .name = "php_zig_lowlevel", .dir = "test/lowlevel" },
    .{ .name = "php_zig_errors", .dir = "test/errors" },
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("php", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Cross-platform linking: on Windows the extension links php8ts.lib from
    // <php_path>/dev (defaults to the bundled win-bin dev pack).
    const php_path = b.option([]const u8, "php-path", "Path to the PHP install (Windows dev pack parent)") orelse
        if (target.result.os.tag == .windows) "win-bin/php" else "";

    // Test PHP extensions, one dynamic library per folder under test/.
    for (test_extensions) |ext| {
        const lib = b.addLibrary(.{
            .name = ext.name,
            .linkage = .dynamic,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("{s}/main.zig", .{ext.dir})),
                .target = target,
                .optimize = optimize,
                .link_libc = true,
                .imports = &.{.{ .name = "php", .module = mod }},
            }),
        });
        link(b, lib, php_path);
        b.installArtifact(lib);
    }

    const test_step = b.step("test", "Run tests");

    const mod_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    test_step.dependOn(&run_mod_tests.step);

    const abi_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/abi.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_abi_tests = b.addRunArtifact(abi_tests);
    test_step.dependOn(&run_abi_tests.step);

    // Run every test/<name>/test.php against the local PHP 8.0 binary.
    const php_bin: ?[]const u8 = switch (target.result.os.tag) {
        .linux => "linux-bin/php7/bin/php",
        .windows => "win-bin/php/php.exe",
        else => null,
    };
    if (php_bin) |bin| {
        const run_ext = b.step("test-ext", "Run PHP test extensions");
        run_ext.dependOn(b.getInstallStep());
        for (test_extensions) |ext| {
            const ext_path = if (target.result.os.tag == .windows)
                b.fmt("extension=./zig-out/bin/{s}.dll", .{ext.name})
            else
                b.fmt("extension=./zig-out/lib/lib{s}.so", .{ext.name});
            const cmd = b.addSystemCommand(&.{
                bin,
                "-n",
                "-d",
                ext_path,
                b.fmt("{s}/test.php", .{ext.dir}),
            });
            run_ext.dependOn(&cmd.step);
        }
    }
}

pub fn link(b: *std.Build, lib: *std.Build.Step.Compile, php_path: []const u8) void {
    if (lib.rootModuleTarget().os.tag == .windows) {
        const dev_path = std.fs.path.join(b.allocator, &.{ php_path, "dev" }) catch @panic("OOM");
        lib.root_module.addLibraryPath(.{ .cwd_relative = dev_path });
        lib.root_module.linkSystemLibrary("php8ts", .{});
    } else {
        lib.linker_allow_shlib_undefined = true;
    }
}
