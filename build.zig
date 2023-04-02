const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mecha = b.addModule("mecha", .{
        .source_file = .{ .path = "src/mecha/mecha.zig" },
    });

    const exe = b.addExecutable(.{
        .name = "browse-vim",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("mecha", mecha);

    exe.install();
    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/parser.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe_tests.addModule("mecha", mecha);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.run().step);
}
