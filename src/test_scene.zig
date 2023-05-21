const std              = @import("std");
const RendererFrontend = @import("render/renderer_frontend.zig").RendererFrontend;
const render_types     = @import("render/render_types.zig");
const Mesh             = render_types.Mesh;
const MeshList         = render_types.MeshList;
const Vertex           = render_types.Vertex;
const RenderData       = render_types.RenderData;
const Logger           = @import("core/log.zig").scoped(.app);



pub const TestScene = struct {
    renderer: *RendererFrontend,
    meshes: MeshList,
    render_data: RenderData,

    pub fn init(allocator: std.mem.Allocator, renderer: *RendererFrontend) !TestScene {
        Logger.info("initializing test-scene\n", .{});

        var self = TestScene {
            .renderer    = renderer,
            .meshes      = try MeshList.initCapacity(allocator, 3),
            .render_data = RenderData {},
        };

        try self.meshes.append(try self.createQuadMesh1());
        try self.meshes.append(try self.createQuadMesh2());
        try self.meshes.append(try self.createQuadMesh3());

        self.render_data = RenderData {};
        self.render_data.addMesh(&self.meshes.items[0]);
        self.render_data.addMesh(&self.meshes.items[1]);
        self.render_data.addMesh(&self.meshes.items[2]);

        return self;
    }

    pub fn deinit(self: *TestScene) void {
        Logger.info("deinitializing test-scene\n", .{});

        for (self.meshes.items) |mesh| {
            self.renderer.backend.freeBuffer(mesh.vertex_buffer);
            self.renderer.backend.freeBuffer(mesh.index_buffer);
        }

        self.meshes.deinit();
    }

    pub fn createQuadMesh1(self: *TestScene) !Mesh {
        var mesh = Mesh {
            .vertices = [_]Vertex {
                .{ .pos = .{ -0.5, -0.5, 0.0 }, .color = .{ 1, 0, 0 }, .tex_coord = .{ 0, 0 } },
                .{ .pos = .{ 0.5, -0.5, 0.0 }, .color = .{ 0, 1, 0 }, .tex_coord = .{ 1, 0 } },
                .{ .pos = .{ 0.5, 0.5, 0.0 }, .color = .{ 0, 0, 1 }, .tex_coord = .{ 1, 1 } },
                .{ .pos = .{ -0.5, 0.5, 0.0 }, .color = .{ 1, 1, 1 }, .tex_coord = .{ 0, 1 } },
            },

            .indices = [_]u16 {
                0, 1, 2, 2, 3, 0, //
            },
        };

        mesh.vertex_buffer = try self.renderer.backend.createVertexBuffer(mesh.vertices[0..]);
        mesh.index_buffer  = try self.renderer.backend.createIndexBuffer (mesh.indices[0..]);

        return mesh;
    }

   pub fn createQuadMesh2(self: *TestScene) !Mesh {
        var mesh = Mesh {
            .vertices = [_]Vertex {
                .{ .pos = .{ -0.5, -0.5, -0.5 }, .color = .{ 1, 0, 0 }, .tex_coord = .{ 0, 0 } },
                .{ .pos = .{ 0.5, -0.5, -0.5 }, .color = .{ 0, 1, 0 }, .tex_coord = .{ 1, 0 } },
                .{ .pos = .{ 0.5, 0.5, -0.5 }, .color = .{ 0, 0, 1 }, .tex_coord = .{ 1, 1 } },
                .{ .pos = .{ -0.5, 0.5, -0.5 }, .color = .{ 1, 1, 1 }, .tex_coord = .{ 0, 1 } },
            },

            .indices = [_]u16 {
                0, 1, 2, 2, 3, 0, //
            },
        };

        mesh.vertex_buffer = try self.renderer.backend.createVertexBuffer(mesh.vertices[0..]);
        mesh.index_buffer  = try self.renderer.backend.createIndexBuffer (mesh.indices[0..]);

        return mesh;
    }

   pub fn createQuadMesh3(self: *TestScene) !Mesh {
        var mesh = Mesh {
            .vertices = [_]Vertex {
                .{ .pos = .{ -0.75, -0.75, -0.75 }, .color = .{ 1, 0, 0 }, .tex_coord = .{ 0, 0 } },
                .{ .pos = .{ 0.75, -0.75, -0.75 }, .color = .{ 0, 1, 0 }, .tex_coord = .{ 1, 0 } },
                .{ .pos = .{ 0.75, 0.75, -0.75 }, .color = .{ 0, 0, 1 }, .tex_coord = .{ 1, 1 } },
                .{ .pos = .{ -0.75, 0.75, -0.75 }, .color = .{ 1, 1, 1 }, .tex_coord = .{ 0, 1 } },
            },

            .indices = [_]u16 {
                0, 1, 2, 2, 3, 0, //
            },
        };

        mesh.vertex_buffer = try self.renderer.backend.createVertexBuffer(mesh.vertices[0..]);
        mesh.index_buffer  = try self.renderer.backend.createIndexBuffer (mesh.indices[0..]);

        return mesh;
    }
};

