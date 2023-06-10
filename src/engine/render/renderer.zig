const std = @import("std");

const GlfwWindow = @import("../GlfwWindow.zig");

const core   = @import("../core/core.zig");
const ResourceHandle = core.ResourceHandle;
const FrameTimer = core.time.FrameTimer(4096);

const vulkan        = @import("./vulkan/vulkan.zig");
const VulkanBackend = vulkan.VulkanBackend;

const render     = @import("render.zig");
const Logger     = render.Logger;
const RenderData = render.RenderData;

const ShaderProgram = render.ShaderProgram;
const ShaderInfo = render.ShaderInfo;

const engine = @import("../engine.zig");
const Mesh = engine.resources.Mesh;

// ----------------------------------------------

pub const Renderer = struct {
    const mesh_limit: usize = 1024;

    allocator: std.mem.Allocator,
    frame_timer: FrameTimer,
    backend: VulkanBackend,
    meshes: core.StackArray(Mesh, mesh_limit) = .{},


    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !Renderer {
        Logger.info("initializing renderer-frontend\n", .{});

        var timer = try core.time.SimpleTimer.init();
        defer Logger.debug("renderer initialized in {} us\n", .{timer.read_us()});

        return Renderer {
            .allocator   = allocator,
            .frame_timer = try FrameTimer.init(),
            .backend     = try VulkanBackend.init(allocator, window),
        };
    }

    pub fn deinit(self: *Renderer) void {
        Logger.info("deinitializing renderer-frontend\n", .{});
        self.backend.deinit();
    }

    pub fn draw_meshes(self: *Renderer, meshes_h: []const ResourceHandle, program: *ShaderProgram) !void {
        if (self.frame_timer.is_frame_0()) {
            Logger.debug("Timings - frame (us): {}\n", .{self.frame_timer.avg_frame_time_us()});
        }

        // @Performance: order meshes in a useful way
        var render_data = RenderData {};
        for (meshes_h) |mesh_h| {
            render_data.meshes.push(self.get_mesh(mesh_h));
        }

        self.frame_timer.start_frame();
        try self.backend.draw_render_data(&render_data, &program.info, &program.internals);
        self.frame_timer.stop_frame();
    }

    pub fn device_wait_idle(self: *Renderer) !void {
        try self.backend.wait_device_idle();
    }

    // ------------------------------------------

    pub fn create_shader_program(self: *Renderer, info: ShaderInfo) !*ShaderProgram {
        Logger.debug("creating shader-program\n", .{});

        var program = try self.allocator.create(ShaderProgram);
        program.* = ShaderProgram {
            .info = info,
        };

        try self.backend.create_shader_internals(&info, &program.internals);
        return program;
    }

    pub fn destroy_shader_program(self: *Renderer, program: *ShaderProgram) void {
        Logger.debug("destroy shader-program\n", .{});
        self.backend.destroy_shader_internals(&program.internals);
        program.deinit();
        self.allocator.destroy(program);
    }

    // ------------------------------------------

    pub fn create_mesh_from_file(self: *Renderer, mesh_path: []const u8, texture_path: [*:0]const u8) !ResourceHandle {
        Logger.debug("creating mesh '{}' from file '{s}'\n", .{self.meshes.len, mesh_path});

        const obj_file = try std.fs.cwd().openFile(mesh_path, .{});
        defer obj_file.close();
        var reader = std.io.bufferedReader(obj_file.reader());

        // TODO(lm): think about using out variable instead of copying
        var obj_data = try engine.resources.files.ObjData.parse_file(self.allocator, reader.reader());
        defer obj_data.deinit();

        var mesh       = try engine.resources.Mesh.from_obj_data(self.allocator, &obj_data);
        try self.backend.create_mesh_internals(&mesh, texture_path);

        self.meshes.push(mesh);
        return ResourceHandle { .value = self.meshes.len - 1 };
    }

    pub fn deinit_mesh(self: *Renderer, mesh_h: ResourceHandle) void {
        const mesh = self.get_mesh_mut(mesh_h);

        self.backend.deinit_mesh_internals(mesh);

        self.allocator.free(mesh.vertices);
        self.allocator.free(mesh.indices);
    }

    pub fn get_mesh(self: *const Renderer, mesh_h: ResourceHandle) *const Mesh {
        return self.meshes.get(mesh_h.value);
    }

    pub fn get_mesh_mut(self: *Renderer, mesh_h: ResourceHandle) *Mesh {
        return self.meshes.get_mut(mesh_h.value);
    }

    // ------------------------------------------
};

