pub usingnamespace @cImport({
    @cInclude("stb_image.h");

    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cDefine("GLFW_INCLUDE_NONE", "1");
    @cDefine("GLFW_EXPOSE_NATIVE_X11", "1");
    @cInclude("GLFW/glfw3.h");
    @cInclude("GLFW/glfw3native.h");
});

const vk = @import("vulkan");
const c  = @This();


// pub extern fn glfwInit() c_int;
// pub extern fn glfwCreateWindow(width: c_int, height: c_int, title: [*:0]const u8, monitor: *c.GLFWmonitor, share: *c.GLFWwindow) *c.GLFWwindow;
// pub extern fn glfwTerminate() void;
// pub extern fn glfwPollEvent() void;
// pub extern fn glfwWaitEvent() void;
// pub extern fn glfwGetFramebufferSize(window: *c.GLFWwindow, width: *c_int, height: *c_int) void;
// pub extern fn glfwSetWindowUserPointer(window: *c.GLFWwindow, pointer: ?*anyopaque) void;
// pub extern fn glfwGetInstanceProcAddress(instance: vk.Instance, procname: [*:0]const u8) vk.PfnVoidFunction;
// pub extern fn glfwGetPhysicalDevicePresentationSupport(instance: vk.Instance, pdef: vk.PhysicalDevice, queuefamily: u32) c_int;
// pub extern fn glfwCreateWindowSurface(instance: vk.Instance, window: *c.GLFWwindow, allocation_callbacks: ?*const vk.AllocationCallbacks, surface: *vk.SurfaceKHR) vk.Result;
