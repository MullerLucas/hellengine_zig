const std = @import("std");
const deps = @import("deps.zig");
const ShaderCompileStep = @import("vulkan-zig").ShaderCompileStep;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "grid_game",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // add corez
    {
        const corez = b.addModule("corez", .{
            .source_file = .{ .path = "lib/corez/src/main.zig" }
        });
        exe.addModule("corez", corez);
    }

    // add vulkan-zig
    {
        const vkzig_dep = b.dependency("vulkan-zig", .{
            .registry = @as([]const u8, b.pathFromRoot("vk.xml")),
        });
        const vkzig_bindings = vkzig_dep.module("vulkan-zig");
        exe.addModule("vulkan-zig", vkzig_bindings);
    }

    // add shaders
    {
        const shaders = ShaderCompileStep.create(
            b,
            &[_][]const u8 { "glslc", "--target-env=vulkan1.2" },
            "-o",
        );
        shaders.add("vert_27", "src/engine/shaders/27_shader_depth.vert", .{});
        shaders.add("frag_27", "src/engine/shaders/27_shader_depth.frag", .{});
        exe.addModule("resources", shaders.getModule());
    }

    // add stb
    {
        const stb_path = std.Build.LazyPath.relative("lib/stb/include");
        exe.addIncludePath(stb_path);

        exe.addCSourceFile(.{
            .file  = std.Build.LazyPath.relative("lib/stb/stb_impl.c"),
            .flags = &.{"-std=c99"},
        });
    }

    // add zigmod dependencies
    {
        deps.addAllTo(exe);
    }

    // link libraries
    {
        exe.linkLibC();
        exe.linkSystemLibrary("glfw3");
    }

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);


    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
