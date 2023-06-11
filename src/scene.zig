const std = @import("std");

const engine     = @import("engine/engine.zig");
const render     = engine.render;
const Renderer   = render.Renderer;
const Mesh       = render.Mesh;
const MeshList   = render.MeshList;
const RenderData = render.RenderData;
const Vertex     = render.Vertex;

const core   = engine.core;
const Logger = core.log.scoped(.app);
const ResourceHandle = core.ResourceHandle;

const ShaderInfo  = render.ShaderInfo;
const ShaderProgram = render.ShaderProgram;
const ShaderScope   = render.shader.ShaderScope;

const za = @import("zalgebra");

// ----------------------------------------------g

pub const TestScene = struct {
    const mesh_limit: usize = 1024;

    renderer:   *Renderer,
    program:    *ShaderProgram    = undefined,
    textures_h: [4]ResourceHandle = undefined,
    meshes_h:   [1]ResourceHandle = undefined,

    pub fn init(allocator: std.mem.Allocator, renderer: *Renderer) !TestScene {
        Logger.info("initializing test-scene\n", .{});

        var timer = try core.time.SimpleTimer.init();
        defer Logger.debug("test-scene initialized in {} us\n", .{timer.read_us()});

        var self = TestScene {
            .renderer    = renderer,
        };

        // create shader-program
        {
            var shader_info = ShaderInfo { };
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 0); // position
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 1); // normal
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 2); // color
            shader_info.add_attribute(.r32g32_sfloat,    0, 3); // uv

            // global
            try shader_info.add_uniform_buffer (allocator, .global, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .global, "proj",  @sizeOf(za.Mat4));
            // scene
            try shader_info.add_uniform_buffer (allocator, .scene, "model", @sizeOf(za.Mat4));
            // material
            try shader_info.add_uniform_sampler(allocator, .material, "my_sampler");
            // object
            try shader_info.add_uniform_buffer (allocator, .object, "object_idx", @sizeOf(usize));

            self.program = try self.renderer.create_shader_program(shader_info);

            // @Todo: handle differently
            _ = try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .global, Renderer.get_default_material());
            _ = try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .scene,  Renderer.get_default_material());

            _ = try self.renderer.create_material_instance(self.program);
        }

        // update shader
        {
            self.textures_h[0] = try self.renderer.create_texture("resources/texture_v1.jpg");
            self.textures_h[1] = try self.renderer.create_texture("resources/texture_v2.jpg");
            self.textures_h[2] = try self.renderer.create_texture("resources/texture_v3.jpg");
            self.textures_h[3] = try self.renderer.create_texture("resources/texture_v4.jpg");

            // @Todo: this is shit
            const texture = self.renderer.get_texture(self.textures_h[0]);
            const texture_update = [_]ResourceHandle { texture.internals_h };

            // update .unit textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .material, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, &texture_update);
        }

        // create meshes
        {
            self.meshes_h[0] = try self.renderer.create_mesh_from_file("art/simple_box.obj", self.textures_h[0]);
        }


        return self;
    }

    pub fn deinit(self: *TestScene) void {
        Logger.info("deinitializing test-scene\n", .{});

        for (self.meshes_h) |mesh_h| {
            self.renderer.destroy_mesh(mesh_h);
        }

        for (self.textures_h) |texture_h| {
            self.renderer.destroy_texture(texture_h);
        }

        self.renderer.destroy_shader_program(self.program);
        self.program = undefined;
    }

    pub fn render_scene(self: *const TestScene) !void {
        try self.renderer.draw_meshes(self.meshes_h[0..], self.program);
    }
};

