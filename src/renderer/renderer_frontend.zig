const std = @import("std");
const VulkanBackend = @import("../vulkan/vulkan_backend.zig").VulkanBackend;
const Logger = @import("../core/log.zig").scoped(.renderer);
const GlfwWindow = @import("../glfw_window.zig");




pub const RendererFrontend = struct {
    backend: VulkanBackend = undefined,


    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !RendererFrontend {
        Logger.info("Initializing renderer frontend", .{});

        var result = RendererFrontend{};
        result.backend = try VulkanBackend.init(allocator, window);
        try result.backend.run();
        return result;
    }

    pub fn deinit(self: *RendererFrontend) void {
        Logger.info("Deinitializing renderer frontend\n", .{});
        self.backend.deinit();
    }

    pub fn drawFrame(self: *RendererFrontend) !void {
        try self.backend.drawFrame();
    }

    pub fn deviceWaitIdle(self: *RendererFrontend) !void {
        try self.backend.waitDeviceIdle();
    }
};
