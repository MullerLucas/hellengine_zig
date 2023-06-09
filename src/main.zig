const std = @import("std");


const engine = @import("engine/engine.zig");
const core = engine.core;
const Logger = core.log.scoped(.app);
const Renderer = engine.render.Renderer;

const GlfwWindow = engine.GlfwWindow;

const app       = @import("app.zig");
const TestScene = app.TestScene;

const resources = @import("engine/resources/resources.zig");

// ----------------------------------------------

pub fn main() !void {
    Logger.info("starting appliation\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) std.log.err("MemLeak", .{});
    }
    var allocator = gpa.allocator();

    const obj_file = try std.fs.cwd().openFile("art/simple_box.obj", .{});
    defer obj_file.close();

    var reader = std.io.bufferedReader(obj_file.reader());
    var mesh = try resources.obj_file_loader.parse_obj_file(allocator, reader.reader());
    defer mesh.deinit();
    Logger.info("Mesh: {}\n", .{mesh});

    var window = try GlfwWindow.init(engine.config.WIDTH, engine.config.HEIGHT, engine.config.APP_NAME);
    defer window.deinit();

    var renderer = Renderer.init(allocator, &window) catch |err| {
        Logger.err("application failed to init with error: {any}", .{err});
        return;
    };
    defer renderer.deinit();

    var scene = try TestScene.init(allocator, &renderer);
    defer scene.deinit();

    while (!window.should_close()) {
        GlfwWindow.poll_events();
        try renderer.draw_frame(&scene.render_data, scene.program);
    }

    try renderer.device_wait_idle();

    Logger.info("exiting appliation\n", .{});
}

