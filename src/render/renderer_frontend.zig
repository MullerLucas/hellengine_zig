const std           = @import("std");
const VulkanBackend = @import("../vulkan/vulkan_backend.zig").VulkanBackend;
const Logger        = @import("../core/log.zig").scoped(.renderer);
const GlfwWindow    = @import("../GlfwWindow.zig");
const render_types  = @import("render_types.zig");
const Mesh          = render_types.Mesh;
const Vertex        = render_types.Vertex;
const RenderData    = render_types.RenderData;




pub const RendererFrontend = struct {
    backend: VulkanBackend = undefined,
    mesh: Mesh = undefined,
    render_data: RenderData = RenderData{},


    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !RendererFrontend {
        Logger.info("Initializing renderer frontend", .{});

        var self = RendererFrontend { };

        self.backend = try VulkanBackend.init(allocator, window);

        self.mesh = try self.createQuadMesh();

        self.render_data = RenderData {};
        self.render_data.addMesh(&self.mesh);

        return self;
    }

    pub fn deinit(self: *RendererFrontend) void {
        Logger.info("deinitializing renderer frontend\n", .{});
        self.backend.freeBuffer(self.mesh.vertex_buffer);
        self.backend.freeBuffer(self.mesh.index_buffer);
        self.backend.deinit();
    }

    pub fn drawFrame(self: *RendererFrontend) !void {
        try self.backend.drawFrame(&self.render_data);
    }

    pub fn deviceWaitIdle(self: *RendererFrontend) !void {
        try self.backend.waitDeviceIdle();
    }

    pub fn createQuadMesh(self: *RendererFrontend) !Mesh {
        var mesh = Mesh {
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

        mesh.vertex_buffer = try self.backend.createVertexBuffer(mesh.vertices[0..]);
        mesh.index_buffer  = try self.backend.createIndexBuffer (mesh.indices[0..]);

        return mesh;
    }
};
