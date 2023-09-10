const std = @import("std");

const engine     = @import("engine/engine.zig");
const render     = engine.render;
const Renderer   = render.Renderer;
const RenderData = render.RenderData;
const Vertex     = render.Vertex;

const core   = engine.core;
const Logger = core.log.scoped(.app);
const ResourceHandle = core.ResourceHandle;

const ShaderInfo    = render.shader.ShaderInfo;
const ShaderProgram = render.shader.ShaderProgram;
const ShaderScope   = render.shader.ShaderScope;

const za = @import("zalgebra");

// ----------------------------------------------g

pub const TestScene = struct {

    renderer:    *Renderer,
    program_h:   ResourceHandle = ResourceHandle.invalid,
    meshes_h:    core.StackArray(ResourceHandle, 64) = .{},

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

            self.program_h = try self.renderer.create_shader_program(shader_info);
        }

        // create materials
        // {
        //     // @Hack
        //     const program = self.renderer.get_shader_program_mut(self.program_h);
        //     _ = try self.renderer.backend.shader_acquire_instance_resources(&program.info, &program.internals, .global, Renderer.get_default_material());
        //     _ = try self.renderer.backend.shader_acquire_instance_resources(&program.info, &program.internals, .scene,  Renderer.get_default_material());
        //
        //     // self.materials_h[0] = try self.renderer.create_material(self.program_h, "test_mat_1", "resources/misc/texture_v1.jpg");
        //     // self.materials_h[1] = try self.renderer.create_material(self.program_h, "test_mat_2", "resources/misc/texture_v2.jpg");
        //     //
        //     // self.materials_h[2] = try self.renderer.create_material(self.program_h, "Black",  "resources/misc/texture_v2.jpg");
        //     // self.materials_h[3] = try self.renderer.create_material(self.program_h, "Lights", "resources/misc/texture_v2.jpg");
        //     // self.materials_h[4] = try self.renderer.create_material(self.program_h, "Green",  "resources/misc/texture_v2.jpg");
        // }

        // create meshes
        {
            const meshes_h = try self.renderer.create_geometries_from_file("resources/double_box/double_box.obj", self.program_h);
            // const meshes_h = try self.renderer.create_geometries_from_file("resources/toy_tank/toy_tank.obj");
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
            self.renderer.destroy_geometry(mesh_h);
        }

        self.renderer.destroy_shader_program(self.program_h);
        self.program_h = ResourceHandle.invalid;
    }

    pub fn render_scene(self: *const TestScene) !void {
        self.renderer.begin_frame();
        const program = self.renderer.get_shader_program_mut(self.program_h);
        try self.renderer.draw_geometries(self.meshes_h.as_slice(), program);
        self.renderer.end_frame();
    }
};

