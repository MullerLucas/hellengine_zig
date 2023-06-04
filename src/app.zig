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

const ShaderInfo  = render.ShaderInfo;
const ShaderProgram = render.ShaderProgram;
const ShaderScope   = render.shader.ShaderScope;

const za = @import("zalgebra");

// ----------------------------------------------g

pub const TestScene = struct {
    renderer: *Renderer,
    meshes: MeshList,
    render_data: RenderData,
    program: *ShaderProgram = undefined,
    textures_h: [4]ResourceHandle = undefined,

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
            var shader_info = ShaderInfo { };
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 0);
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 1);
            shader_info.add_attribute(.r32g32_sfloat,    0, 2);

            try shader_info.add_uniform_buffer (allocator, .global, "model", @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .global, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .global, "proj",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_sampler(allocator, .global, "my_sampler");

            try shader_info.add_uniform_buffer (allocator, .module, "model", @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .module, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .module, "proj",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_sampler(allocator, .module, "my_sampler");

            try shader_info.add_uniform_buffer (allocator, .unit, "model", @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .unit, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .unit, "proj",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_sampler(allocator, .unit, "my_sampler");

            try shader_info.add_uniform_buffer (allocator, .local, "model", @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .local, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .local, "proj",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_sampler(allocator, .local, "my_sampler");

            self.program = try self.renderer.create_shader_program(shader_info);

            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .global, ResourceHandle.zero);
            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .module, ResourceHandle.zero);
            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .unit,   ResourceHandle.zero);
            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .local,  ResourceHandle.zero);
        }

        // update shader
        {
            self.textures_h[0] = try self.renderer.backend.create_texture_image("resources/texture_v1.jpg");
            self.textures_h[1] = try self.renderer.backend.create_texture_image("resources/texture_v2.jpg");
            self.textures_h[2] = try self.renderer.backend.create_texture_image("resources/texture_v3.jpg");
            self.textures_h[3] = try self.renderer.backend.create_texture_image("resources/texture_v4.jpg");

            // update .global textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .global, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, self.textures_h[0..1]);
            // try self.renderer.backend.shader_apply_uniform_scope(.global, ResourceHandle.zero, &self.program.info, &self.program.internals);

            // update .module textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .module, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, self.textures_h[1..2]);

            // update .unit textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .unit, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, self.textures_h[2..3]);

            // update .local textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .local, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, self.textures_h[3..4]);
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

        for (self.textures_h) |texture_h| {
            self.renderer.backend.free_image(texture_h);
        }

        self.meshes.deinit();

        self.renderer.destroy_shader_program(self.program);
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
        mesh.texture       = try self.renderer.backend.create_texture_image("resources/texture_v1.jpg");

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
        mesh.texture       = try self.renderer.backend.create_texture_image("resources/texture_v1.jpg");

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
        mesh.texture       = try self.renderer.backend.create_texture_image("resources/texture_v1.jpg");

        return mesh;
    }

    // fn update_shader_uniform_buffer(self: *TestScene, info: *const ShaderInfo) !void {
    //     const time: f32 = (@intToFloat(f32, (try std.time.Instant.now()).since(self.start_time)) / @intToFloat(f32, std.time.ns_per_s));
    //
    //     var ubo = UniformBufferObject {
    //         .model = za.Mat4.identity().rotate(time * 90.0, za.Vec3.new(0.0, 0.0, 1.0)),
    //         .view = za.lookAt(za.Vec3.new(2, 2, 2), za.Vec3.new(0, 0, 0), za.Vec3.new(0, 0, 1)),
    //         .proj = za.perspective(45.0, @intToFloat(f32, self.swap_chain_extent.width) / @intToFloat(f32, self.swap_chain_extent.height), 0.1, 10),
    //     };
    //     ubo.proj.data[1][1] *= -1;
    //
    //     const instance_h = ResourceHandle.zero;
    //
    //     // update and bind global scope
    //     {
    //         self.shader_bind_scope(internals, .global, instance_h);
    //         self.shader_set_uniform_buffer(UniformBufferObject, internals, &ubo);
    //         try self.shader_apply_uniform_scope(.global, instance_h, info, internals);
    //     }
    //
    //     // update and bind .module scope
    //     {
    //         self.shader_bind_scope(internals, .module, instance_h);
    //         self.shader_set_uniform_buffer(UniformBufferObject, internals, &ubo);
    //         try self.shader_apply_uniform_scope(.module, instance_h, info, internals);
    //     }
    //
    //     // update and bind .unit scope
    //     {
    //         self.shader_bind_scope(internals, .unit, instance_h);
    //         self.shader_set_uniform_buffer(UniformBufferObject, internals, &ubo);
    //         try self.shader_apply_uniform_scope(.unit, instance_h, info, internals);
    //     }
    //
    //     // update and bind .local scope
    //     {
    //         self.shader_bind_scope(internals, .local, instance_h);
    //         self.shader_set_uniform_buffer(UniformBufferObject, internals, &ubo);
    //         try self.shader_apply_uniform_scope(.local, instance_h, info, internals);
    //     }
    // }
};

