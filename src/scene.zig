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

    renderer:    *Renderer,
    program:     *ShaderProgram    = undefined,
    meshes_h:    core.StackArray(ResourceHandle, 64) = .{},
    materials_h: [5]ResourceHandle = undefined,

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
        }

        // create materials
        {
            // @Todo: handle differently
            _ = try self.renderer.backend.shader_acquire_instance_resources(&self.program.info, &self.program.internals, .global, Renderer.get_default_material());
            _ = try self.renderer.backend.shader_acquire_instance_resources(&self.program.info, &self.program.internals, .scene,  Renderer.get_default_material());

            self.materials_h[0] = try self.renderer.create_material(self.program, "test_mat_1", "resources/texture_v1.jpg");
            self.materials_h[1] = try self.renderer.create_material(self.program, "test_mat_2", "resources/texture_v2.jpg");

            self.materials_h[2] = try self.renderer.create_material(self.program, "Black",  "resources/texture_v2.jpg");
            self.materials_h[3] = try self.renderer.create_material(self.program, "Lights", "resources/texture_v2.jpg");
            self.materials_h[4] = try self.renderer.create_material(self.program, "Green",  "resources/texture_v2.jpg");
        }

        // create meshes
        {
            // const meshes_h = try self.renderer.create_meshes_from_file("art/tank.obj");
            const meshes_h = try self.renderer.create_meshes_from_file("resources/green_tank.obj");
            defer meshes_h.deinit();

            for (meshes_h.items) |mesh_h| {
                self.meshes_h.push(mesh_h);
            }
        }

        return self;
    }

    pub fn deinit(self: *TestScene) void {
        Logger.info("deinitializing test-scene\n", .{});

        for (self.meshes_h.as_slice()) |mesh_h| {
            self.renderer.destroy_mesh(mesh_h);
        }

        for (self.materials_h) |material_h| {
            self.renderer.destroy_material(self.program, material_h);
        }

        self.renderer.destroy_shader_program(self.program);
        self.program = undefined;
    }

    pub fn render_scene(self: *const TestScene) !void {
        Logger.info("render '{}\n' meshes", .{self.meshes_h.len});

        self.renderer.begin_frame();
        try self.renderer.draw_meshes(self.meshes_h.as_slice(), self.program);
        self.renderer.end_frame();
    }
};

