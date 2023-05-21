const std           = @import("std");
const VulkanBackend = @import("../vulkan/vulkan_backend.zig").VulkanBackend;
const Logger        = @import("../core/log.zig").scoped(.render);
const GlfwWindow    = @import("../GlfwWindow.zig");
const render_types  = @import("render_types.zig");
const Mesh          = render_types.Mesh;
const MeshList      = render_types.MeshList;
const Vertex        = render_types.Vertex;
const RenderData    = render_types.RenderData;



pub const RendererFrontend = struct {
    backend: VulkanBackend,

    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !RendererFrontend {
        Logger.info("initializing renderer-frontend\n", .{});

        return RendererFrontend {
            .backend = try VulkanBackend.init(allocator, window),
        };
    }

    pub fn deinit(self: *RendererFrontend) void {
        Logger.info("deinitializing renderer-frontend\n", .{});
        self.backend.deinit();
    }

    pub fn drawFrame(self: *RendererFrontend, render_data: *const RenderData) !void {
        try self.backend.drawFrame(render_data);
    }

    pub fn deviceWaitIdle(self: *RendererFrontend) !void {
        try self.backend.waitDeviceIdle();
    }

};

