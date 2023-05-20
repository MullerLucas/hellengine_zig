const std           = @import("std");
const VulkanBackend = @import("../vulkan/vulkan_backend.zig").VulkanBackend;
const Logger        = @import("../core/log.zig").scoped(.renderer);
const GlfwWindow    = @import("../GlfwWindow.zig");
const render_types  = @import("render_types.zig");
const Mesh          = render_types.Mesh;
const Vertex        = render_types.Vertex;




pub const RendererFrontend = struct {
    backend: VulkanBackend = undefined,
    mesh: Mesh = undefined,


    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !RendererFrontend {
        Logger.info("Initializing renderer frontend", .{});

        var self = RendererFrontend {
            .mesh = RendererFrontend.createQuadMesh(),
        };

        self.backend = try VulkanBackend.init(allocator, window);
        _ = try self.backend.createVertexBuffer(self.mesh.vertices[0..]);
        _ = try self.backend.createIndexBuffer (self.mesh.indices[0..]);
        return self;
    }

    pub fn deinit(self: *RendererFrontend) void {
        Logger.info("Deinitializing renderer frontend\n", .{});
        self.backend.deinit();
    }

    pub fn drawFrame(self: *RendererFrontend) !void {
        try self.backend.drawFrame(&self.mesh);
    }

    pub fn deviceWaitIdle(self: *RendererFrontend) !void {
        try self.backend.waitDeviceIdle();
    }

    pub fn createQuadMesh() Mesh {
        return Mesh {
            .vertices = [_]Vertex {
                .{ .pos = .{ -0.5, -0.5, 0.0 }, .color = .{ 1, 0, 0 }, .tex_coord = .{ 0, 0 } },
                .{ .pos = .{ 0.5, -0.5, 0.0 }, .color = .{ 0, 1, 0 }, .tex_coord = .{ 1, 0 } },
                .{ .pos = .{ 0.5, 0.5, 0.0 }, .color = .{ 0, 0, 1 }, .tex_coord = .{ 1, 1 } },
                .{ .pos = .{ -0.5, 0.5, 0.0 }, .color = .{ 1, 1, 1 }, .tex_coord = .{ 0, 1 } },

                .{ .pos = .{ -0.5, -0.5, -0.5 }, .color = .{ 1, 0, 0 }, .tex_coord = .{ 0, 0 } },
                .{ .pos = .{ 0.5, -0.5, -0.5 }, .color = .{ 0, 1, 0 }, .tex_coord = .{ 1, 0 } },
                .{ .pos = .{ 0.5, 0.5, -0.5 }, .color = .{ 0, 0, 1 }, .tex_coord = .{ 1, 1 } },
                .{ .pos = .{ -0.5, 0.5, -0.5 }, .color = .{ 1, 1, 1 }, .tex_coord = .{ 0, 1 } },
            },

            .indices = [_]u16 {
                0, 1, 2, 2, 3, 0, //
                4, 5, 6, 6, 7, 4, //
            },
        };
    }
};
