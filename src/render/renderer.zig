const std = @import("std");

const GlfwWindow = @import("../GlfwWindow.zig");

const core   = @import("../core/core.zig");
const ResourceHandle = core.ResourceHandle;

const vulkan        = @import("./vulkan/vulkan.zig");
const VulkanBackend = vulkan.VulkanBackend;

const render     = @import("render.zig");
const Logger     = render.Logger;
const RenderData = render.RenderData;

// ----------------------------------------------

pub const Renderer = struct {
    backend: VulkanBackend,

    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !Renderer {
        Logger.info("initializing renderer-frontend\n", .{});

        return Renderer {
            .backend = try VulkanBackend.init(allocator, window),
        };
    }

    pub fn late_init(self: *Renderer, texture_image_handle: ResourceHandle) !void {
        try self.backend.late_init(texture_image_handle);
    }

    pub fn deinit(self: *Renderer) void {
        Logger.info("deinitializing renderer-frontend\n", .{});
        self.backend.deinit();
    }

    pub fn drawFrame(self: *Renderer, render_data: *const RenderData) !void {
        try self.backend.drawFrame(render_data);
    }

    pub fn deviceWaitIdle(self: *Renderer) !void {
        try self.backend.waitDeviceIdle();
    }
};

