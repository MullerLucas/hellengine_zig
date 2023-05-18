const std = @import("std");
const vk = @import("vulkan");
const c = @import("c.zig");
const shaders = @import("shaders");
const GraphicsContext = @import("graphics_context.zig").GraphicsContext;
const Swapchain = @import("swapchain.zig").Swapchain;
const Allocator = std.mem.Allocator;
const math = @import("math.zig");
const Vertex = math.Vertex;
const win = @import("window.zig");
const HellWindow = win.HellWindow;


const app_name = "vulkan-zig triangle example";

const vertices = [_]Vertex{
    .{ .pos = .{ 0, -0.5 }, .color = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 1, 1, 0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0, 0, 1 } },
};

pub fn main() !void {
    var extent = vk.Extent2D{ .width = 800, .height = 600 };

    c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
    var window = HellWindow.init("hell-app", .{
        .width = extent.width,
        .height = extent.height,
    }) catch return error.WindowInitFailed;
    defer window.deinit();

    while (!window.shouldClose()) {
        const ext = window.getExtent();
        _ = ext;
        window.pollEvents();
    }
}
