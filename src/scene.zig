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

        // create meshes
        {
            self.meshes_h[0] = try self.renderer.create_mesh_from_file("art/simple_box.obj", "resources/texture.jpg");
        }

        // create shader-program
        {
            var shader_info = ShaderInfo { };
            // position
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 0);
            // normal
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 1);
            // color
            shader_info.add_attribute(.r32g32b32_sfloat, 0, 2);
            // uv
            shader_info.add_attribute(.r32g32_sfloat,    0, 3);

            try shader_info.add_uniform_buffer (allocator, .global, "model", @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .global, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .global, "proj",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_sampler(allocator, .global, "my_sampler");

            try shader_info.add_uniform_buffer (allocator, .scene, "model", @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .scene, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .scene, "proj",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_sampler(allocator, .scene, "my_sampler");

            try shader_info.add_uniform_buffer (allocator, .material, "model", @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .material, "view",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_buffer (allocator, .material, "proj",  @sizeOf(za.Mat4));
            try shader_info.add_uniform_sampler(allocator, .material, "my_sampler");

            try shader_info.add_uniform_buffer(allocator, .object, "local_idx", @sizeOf(usize));

            self.program = try self.renderer.create_shader_program(shader_info);

            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .global,   ResourceHandle.zero);
            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .scene,    ResourceHandle.zero);
            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .material, ResourceHandle.zero);
            try self.renderer.backend.shader_acquire_instance_resources(&shader_info, &self.program.internals, .object,   ResourceHandle.zero);
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

            // update .module textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .scene, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, self.textures_h[1..2]);

            // update .unit textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .material, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, self.textures_h[2..3]);

            // update .object textures
            self.renderer.backend.shader_bind_scope(&self.program.internals, .object, ResourceHandle.zero);
            self.renderer.backend.shader_set_uniform_sampler(&self.program.internals, self.textures_h[3..4]);
        }

        return self;
    }

    pub fn deinit(self: *TestScene) void {
        Logger.info("deinitializing test-scene\n", .{});

        for (self.meshes_h) |mesh_h| {
            self.renderer.deinit_mesh(mesh_h);
        }

        for (self.textures_h) |texture_h| {
            // TODO(lm): go through renderer, not backend
            self.renderer.backend.free_image(texture_h);
        }

        self.renderer.destroy_shader_program(self.program);
        self.program = undefined;
    }

    pub fn render_scene(self: *const TestScene) !void {
        try self.renderer.draw_meshes(self.meshes_h[0..], self.program);
    }
};

