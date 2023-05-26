const std = @import("std");


const config = @import("config.zig");

const core   = @import("./core/core.zig");
const Logger = core.log.scoped(.app);

const render   = @import("render/render.zig");
const Renderer = render.Renderer;

const GlfwWindow = @import("GlfwWindow.zig");

const app       = @import("app.zig");
const TestScene = app.TestScene;

// ----------------------------------------------

pub fn main() !void {
    Logger.info("starting appliation\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) std.log.err("MemLeak", .{});
    }
    const allocator = gpa.allocator();

    var window = try GlfwWindow.init(config.WIDTH, config.HEIGHT, config.APP_NAME);
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

    while (!window.should_close()) {
        GlfwWindow.poll_events();
        try renderer.draw_frame(&scene.render_data);
    }

    try renderer.device_wait_idle();

    Logger.info("exiting appliation\n", .{});
}

