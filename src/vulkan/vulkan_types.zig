const vk = @import("vulkan");



pub const Buffer = struct {
    buf: vk.Buffer,
    mem: vk.DeviceMemory,
};
