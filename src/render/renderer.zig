const std = @import("std");

const GlfwWindow = @import("../GlfwWindow.zig");

const core   = @import("../core/core.zig");
const ResourceHandle = core.ResourceHandle;

const vulkan        = @import("./vulkan/vulkan.zig");
const VulkanBackend = vulkan.VulkanBackend;

const render     = @import("render.zig");
const Logger     = render.Logger;
const RenderData = render.RenderData;

const ShaderProgram = render.ShaderProgram;
const ShaderConfig = render.ShaderConfig;

// ----------------------------------------------

pub const Renderer = struct {
    backend: VulkanBackend,

    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !Renderer {
        Logger.info("initializing renderer-frontend\n", .{});

        return Renderer {
            .backend = try VulkanBackend.init(allocator, window),
        };
    }

    pub fn deinit(self: *Renderer) void {
        Logger.info("deinitializing renderer-frontend\n", .{});
        self.backend.deinit();
    }

    pub fn draw_frame(self: *Renderer, render_data: *const RenderData, program: *const ShaderProgram) !void {
        try self.backend.draw_frame(render_data, program.internals_h);
    }

    pub fn device_wait_idle(self: *Renderer) !void {
        try self.backend.wait_device_idle();
    }

    // ------------------------------------------

    pub fn create_shader_program(self: *Renderer, config: ShaderConfig, texture_h: ResourceHandle) !ShaderProgram {
        Logger.debug("creating shader-program\n", .{});
        const internals = try self.backend.create_shader_internals(&config, texture_h);

        return ShaderProgram {
            .config = config,
            .internals_h = internals,
        };
    }

    pub fn destroy_shader_program(self: *Renderer, program: *ShaderProgram) void {
        Logger.debug("destroy shader-program\n", .{});
        self.backend.destroy_shader_internals(program.internals_h);
    }

    // ------------------------------------------
};

