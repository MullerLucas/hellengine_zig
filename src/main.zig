const std = @import("std");
const RendererFrontend = @import("renderer/renderer_frontend.zig").RendererFrontend;
const Logger = @import("core/log.zig").scoped(.hell);
const GlfwWindow = @import("glfw_window.zig");


const APP_NAME = "hell-app";
const WIDTH: u32 = 800;
const HEIGHT: u32 = 600;



pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) std.log.err("MemLeak", .{});
    }
    const allocator = gpa.allocator();

    var window = try GlfwWindow.init(WIDTH, HEIGHT, APP_NAME);
    defer window.deinit();

    var renderer = RendererFrontend.init(allocator, &window) catch |err| {
        Logger.err("application failed to init with error: {any}", .{err});
        return;
    };
    defer renderer.deinit();

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
        try renderer.drawFrame();
    }

    try renderer.deviceWaitIdle();
}

