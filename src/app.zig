const std = @import("std");

const render     = @import("./render/render.zig");
const Renderer   = render.Renderer;
const Mesh       = render.Mesh;
const MeshList   = render.MeshList;
const RenderData = render.RenderData;
const Vertex     = render.Vertex;

const core   = @import("./core/core.zig");
const Logger = core.log.scoped(.app);
const ResourceHandle = core.ResourceHandle;

// ----------------------------------------------g

pub const TestScene = struct {
    renderer: *Renderer,
    meshes: MeshList,
    render_data: RenderData,
    program: ResourceHandle = ResourceHandle.invalid,

    pub fn init(allocator: std.mem.Allocator, renderer: *Renderer) !TestScene {
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
        self.render_data.add_mesh(&self.meshes.items[0]);
        self.render_data.add_mesh(&self.meshes.items[1]);
        self.render_data.add_mesh(&self.meshes.items[2]);


        self.program = try self.renderer.backend.create_shader_program(self.meshes.items[0].texture);

        return self;
    }

    pub fn deinit(self: *TestScene) void {
        Logger.info("deinitializing test-scene\n", .{});

        for (self.meshes.items) |mesh| {
            self.renderer.backend.free_buffer(mesh.vertex_buffer);
            self.renderer.backend.free_buffer(mesh.index_buffer);
            self.renderer.backend.free_image(mesh.texture);
        }

        self.meshes.deinit();

        self.renderer.backend.destroy_shader_program(self.program);
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

        mesh.vertex_buffer = try self.renderer.backend.create_vertex_buffer(mesh.vertices[0..]);
        mesh.index_buffer  = try self.renderer.backend.createIndexBuffer (mesh.indices[0..]);
        mesh.texture       = try self.renderer.backend.create_texture_image("resources/texture.jpg");

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

        mesh.vertex_buffer = try self.renderer.backend.create_vertex_buffer(mesh.vertices[0..]);
        mesh.index_buffer  = try self.renderer.backend.createIndexBuffer (mesh.indices[0..]);
        mesh.texture       = try self.renderer.backend.create_texture_image("resources/texture.jpg");

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

        mesh.vertex_buffer = try self.renderer.backend.create_vertex_buffer(mesh.vertices[0..]);
        mesh.index_buffer  = try self.renderer.backend.createIndexBuffer (mesh.indices[0..]);
        mesh.texture       = try self.renderer.backend.create_texture_image("resources/texture.jpg");

        return mesh;
    }
};

