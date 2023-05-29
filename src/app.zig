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

const ShaderConfig  = render.ShaderInfo;
const ShaderProgram = render.ShaderProgram;
const ShaderScope   = render.shader.ShaderScope;

// ----------------------------------------------g

pub const TestScene = struct {
    renderer: *Renderer,
    meshes: MeshList,
    render_data: RenderData,
    program: ShaderProgram = undefined,

    pub fn init(allocator: std.mem.Allocator, renderer: *Renderer) !TestScene {
        Logger.info("initializing test-scene\n", .{});

        var timer = try core.time.SimpleTimer.init();
        defer Logger.debug("test-scene initialized in {} us\n", .{timer.read_us()});

        var self = TestScene {
            .renderer    = renderer,
            .meshes      = try MeshList.initCapacity(allocator, 3),
            .render_data = RenderData {},
        };

        // create render-data
        {
            try self.meshes.append(try self.createQuadMesh1());
            try self.meshes.append(try self.createQuadMesh2());
            try self.meshes.append(try self.createQuadMesh3());

            self.render_data = RenderData {};
            self.render_data.add_mesh(&self.meshes.items[0]);
            self.render_data.add_mesh(&self.meshes.items[1]);
            self.render_data.add_mesh(&self.meshes.items[2]);
        }

        // create shader-program
        {
            var shader_config = ShaderConfig { };
            shader_config.add_attribute(.r32g32b32_sfloat, 0, 0);
            shader_config.add_attribute(.r32g32b32_sfloat, 0, 1);
            shader_config.add_attribute(.r32g32_sfloat,    0, 2);

            try shader_config.add_uniform(allocator, .global, "my_ubo", @sizeOf(render.UniformBufferObject));
            try shader_config.add_sampler(allocator, .global, "my_sampler", @sizeOf(render.UniformBufferObject));

            self.program = try self.renderer.create_shader_program(shader_config, self.meshes.items[0].texture);
        }

        return self;
    }

    pub fn deinit(self: *TestScene) void {
        Logger.info("deinitializing test-scene\n", .{});

        for (self.meshes.items) |mesh| {
            self.renderer.backend.free_buffer_h(mesh.vertex_buffer);
            self.renderer.backend.free_buffer_h(mesh.index_buffer);
            self.renderer.backend.free_image(mesh.texture);
        }

        self.meshes.deinit();

        self.renderer.destroy_shader_program(&self.program);
        self.program = undefined;
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

