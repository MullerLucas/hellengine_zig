const std = @import("std");


const core   = @import("./core/core.zig");
const Logger = core.log.scoped(.app);

const render   = @import("render/render.zig");
const Renderer = render.Renderer;

const GlfwWindow = @import("GlfwWindow.zig");

const app       = @import("app.zig");
const TestScene = app.TestScene;

// ----------------------------------------------

const APP_NAME    = "hell-app";
const WIDTH:  u32 = 800;
const HEIGHT: u32 = 600;

// ----------------------------------------------

pub fn main() !void {
    Logger.info("starting appliation\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) std.log.err("MemLeak", .{});
    }
    const allocator = gpa.allocator();

    var window = try GlfwWindow.init(WIDTH, HEIGHT, APP_NAME);
    defer window.deinit();

    var renderer = Renderer.init(allocator, &window) catch |err| {
        Logger.err("application failed to init with error: {any}", .{err});
        return;
    };
    defer renderer.deinit();

    var scene = try TestScene.init(allocator, &renderer);
    defer scene.deinit();

    try renderer.late_init(scene.render_data.meshes[0].texture);

    // var app = VulkanBackend.init(allocator) catch |err| {
    //     std.log.err("application failed to init with error: {any}", .{err});
    //     return;
    // };
    // defer app.deinit();
    // app.run() catch |err| {
    //     std.log.err("application exited with error: {any}", .{err});
    //     return;
    // };

    while (!window.shouldClose()) {
        GlfwWindow.pollEvents();
        try renderer.drawFrame(&scene.render_data);
    }

    try renderer.deviceWaitIdle();

    Logger.info("exiting appliation\n", .{});
}

