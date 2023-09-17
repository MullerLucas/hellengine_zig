// https://github.com/hexops/mach-glfw/blob/main/src/Window.zig


const engine = @import("../engine.zig");
const render = engine.render;
const Logger = engine.logging.scoped(.hell);
const c      = engine.c;

// ----------------------------------------------------------------------------

pub const Size2D = struct {
    width:  u32,
    height: u32,
};

pub const VKProc = *const fn () callconv(.C) void;

// ----------------------------------------------------------------------------

pub const GlfwWindow = struct {
    handle: ?*c.GLFWwindow = null,
    framebuffer_resized: bool = false,

    pub fn init(width: u32, height: u32, app_name: [*:0]const u8) !GlfwWindow {
        if(c.glfwInit() == c.GLFW_FALSE) {
            @panic("failed to initialize GLFW");
        }

        var result = GlfwWindow{};

        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        result.handle = c.glfwCreateWindow(@intCast(width), @intCast(height), app_name, null, null);
        result.set_window_user_pointer(null);
        result.set_framebuffer_size_callback(framebuffer_resize_callback);

        return result;
    }

    pub inline fn from_c_handle(handle: *anyopaque) GlfwWindow {
        return GlfwWindow {
            .handle = @as(*c.GLFWwindow, @ptrCast(@alignCast(handle))),
            .framebuffer_resized = false,
        };
    }

    pub inline fn deinit(self: *GlfwWindow) void {
        Logger.info("deinitialize Glfw-Window\n", .{});
        c.glfwDestroyWindow(self.handle);
        c.glfwTerminate();
    }

    pub fn get_instance_proc_address(vk_instance: ?*anyopaque, proc_name: [*:0]const u8) callconv(.C) ?VKProc {
        if (c.glfwGetInstanceProcAddress(
            if (vk_instance) |v| @as(c.VkInstance, @ptrCast(v)) else null,
            proc_name
        )) |proc_addr|
        {
            return proc_addr;
        }
        return null;
    }

    pub inline fn should_close(self: *GlfwWindow) bool {
        return c.glfwWindowShouldClose(self.handle) == c.GLFW_TRUE;
    }

    pub inline fn set_should_close(self: *GlfwWindow, value: bool) void {
        const c_value = if (value) c.GLFW_TRUE else c.GLFW_FALSE;
        c.glfeSetWindowShouldClose(self.handle, c_value);
    }

    pub inline fn poll_events() void {
        c.glfwPollEvents();
    }

    pub inline fn wait_events() void {
        c.glfwWaitEvents();
    }

    pub inline fn get_framebuffer_size(self: *GlfwWindow) Size2D {
        var width: c_int = undefined;
        var height: c_int = undefined;
        c.glfwGetFramebufferSize(self.handle.?, &width, &height);

        return .{
            .width  = @intCast(width),
            .height = @intCast(height),
        };
    }

    pub inline fn create_window_surface(self: *GlfwWindow, vk_instance: anytype, vk_allocation_callbacks: anytype, vk_surface_khr: anytype) i32 {
        // zig-vulkan uses enums to represent opaque pointers
        const instance: c.VkInstance = switch(@typeInfo(@TypeOf(vk_instance))) {
            .Enum => @as(c.VkInstance, @ptrFromInt(@intFromEnum(vk_instance))),
            else  => @as(c.VkInstance, @ptrCast(vk_instance)),
        };

        return c.glfwCreateWindowSurface(
            instance,
            self.handle,
            if (vk_allocation_callbacks == null) null else @as(*const c.VkAllocationCallbacks, @ptrCast(@alignCast(vk_allocation_callbacks))),
            @as(*c.VkSurfaceKHR, @ptrCast(@alignCast(vk_surface_khr)))
        );
    }

    pub inline fn get_required_instance_extensions() ?[][*:0]const u8 {
        var count: u32 = 0;
        if (c.glfwGetRequiredInstanceExtensions(&count)) |extensions| {
            return @as([*][*:0]const u8, @ptrCast(extensions))[0..count];
        }
        return null;
    }

    pub inline fn set_window_user_pointer(self: *GlfwWindow, pointer: ?*anyopaque) void {
        c.glfwSetWindowUserPointer(self.handle, pointer);
    }

    pub inline fn set_framebuffer_size_callback(self: *GlfwWindow, comptime callback: ?fn (window: *GlfwWindow, width: u32, height: u32) void) void {
        if (callback) |user_callback| {
            const CWrapper = struct {
                pub fn framebufferSizeCallbackWrapper(handle: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
                    var window = from_c_handle(handle.?);
                    @call(.always_inline, user_callback, .{
                        &window,
                        @as(u32, @intCast(width)),
                        @as(u32, @intCast(height)),
                    });
                }
            };

            if (c.glfwSetFramebufferSizeCallback(self.handle, CWrapper.framebufferSizeCallbackWrapper) != null) { return; }
        } else {
            if (c.glfwSetFramebufferSizeCallback(self.handle, null) != null) { return; }
        }
    }

    fn framebuffer_resize_callback(window: *GlfwWindow, _: u32, _: u32) void {
        window.framebuffer_resized = true;
    }
};

