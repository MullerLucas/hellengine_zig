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

// ----------------------------------------------

pub const Renderer = struct {
    allocator: std.mem.Allocator,
    frame_timer: FrameTimer,
    backend: VulkanBackend,

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

    pub fn draw_frame(self: *Renderer, render_data: *const RenderData, program: *const ShaderProgram) !void {
        if (self.frame_timer.is_frame_0()) {
            Logger.debug("Timings - frame (us): {}\n", .{self.frame_timer.avg_frame_time_us()});
        }

        self.frame_timer.start_frame();
        try self.backend.draw_frame(render_data, &program.info, &program.internals);
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
        // TODO(lm): move somewhere else
        try self.backend.shader_acquire_instance_resources(&info, &program.internals, .global, ResourceHandle { .value = 0 });

        return program;
    }

    pub fn destroy_shader_program(self: *Renderer, program: *ShaderProgram) void {
        Logger.debug("destroy shader-program\n", .{});
        self.backend.destroy_shader_internals(&program.internals);
        program.deinit();
        self.allocator.destroy(program);
    }

    // ------------------------------------------
};

