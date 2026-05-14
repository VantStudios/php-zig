const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("php", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const mod_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);

    _ = mod;
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
