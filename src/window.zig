const glfw = @import("glfw");
const vk = @import("vulkan");
// const c = @import("c.zig");

pub const VKProc = *const fn () callconv(.C) void;

pub const GlfwWindow = struct {
    const Self = @This();

    window: ?glfw.Window = null,
    framebuffer_resized: bool = false,

    pub fn init(width: u32, height: u32, app_name: [*:0]const u8) !Self {
        if(!glfw.init(.{})) {
            @panic("failed to initialize GLFW");
        }

        var result = Self{};

        result.window = glfw.Window.create(width, height, app_name, null, null, .{
            .client_api = .no_api,
        });
        result.window.?.setUserPointer(&result);
        result.window.?.setFramebufferSizeCallback(framebufferResizeCallback);

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.window.?.destroy();
        glfw.terminate();
    }

    pub fn getInstanceProcAddress(vk_instance: ?*anyopaque, proc_name: [*:0]const u8) callconv(.C) ?VKProc {
        return glfw.getInstanceProcAddress(vk_instance, proc_name);
    }

    pub fn shouldClose(self: *Self) bool {
        return self.window.?.shouldClose();
    }

    pub fn pollEvents() void {
        glfw.pollEvents();
    }

    pub fn waitEvents() void {
        glfw.waitEvents();
    }

    pub fn getFramebufferSize(self: *Self) glfw.Window.Size {
        return glfw.Window.getFramebufferSize(self.window.?);
    }

    pub fn createWindowSurface(self: *Self, instance: vk.Instance, surface: *vk.SurfaceKHR) i32 {
        return glfw.createWindowSurface(instance, self.window.?, null, surface);
    }
    pub fn getRequiredInstanceExtensions() ?[][*:0]const u8 {
        return glfw.getRequiredInstanceExtensions();
    }
};

fn framebufferResizeCallback(window: glfw.Window, _: u32, _: u32) void {
    var self = window.getUserPointer(GlfwWindow);
    if (self != null) {
        self.?.framebuffer_resized = true;
    }
}
