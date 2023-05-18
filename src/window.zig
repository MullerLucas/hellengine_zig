const std = @import("std");
const c = @import("c.zig");
const vk = @import("vk");
const log = @import("log.zig").scoped(.window);


pub const HellExtent2D = struct {
    width: u32,
    height: u32,
};

pub const HellWindow = struct {
    const Self = @This();

    window: *c.GLFWwindow,

    pub fn init(app_name: [*c]const u8, extent: HellExtent2D) !Self {
        log.info("initializing window '{s}'\n", .{app_name});


        if (c.glfwInit() != c.GLFW_TRUE) return error.GlfwInitFailed;

        if (c.glfwVulkanSupported() != c.GLFW_TRUE) {
            std.log.err("GLFW could not find libvulkan", .{});
            return error.NoVulkan;
        }

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        const window = c.glfwCreateWindow(
            @intCast(c_int, extent.width),
            @intCast(c_int, extent.height),
            app_name,
            null,
            null,
        ) orelse return error.WindowInitFailed;

        return Self {
            .window = window,
        };
    }

    pub fn deinit(self: *Self) void {
        c.glfwTerminate();
        c.glfwDestroyWindow(self.window);
    }

    pub fn shouldClose(self: *Self) bool {
        return c.glfwWindowShouldClose(self.window) == c.GLFW_TRUE;
    }

    pub fn getExtent(self: *Self) HellExtent2D {
        var w: c_int = undefined;
        var h: c_int = undefined;
        c.glfwGetWindowSize(self.window, &w, &h);

        return HellExtent2D {
            .width  = @intCast(u32, w),
            .height = @intCast(u32, w),
        };
    }

    pub fn pollEvents(_: *Self) void {
        c.glfwPollEvents();
    }
};
