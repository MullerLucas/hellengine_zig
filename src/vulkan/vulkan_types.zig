const std = @import("std");
const vk  = @import("vulkan");



pub const Buffer = struct {
    buf: vk.Buffer,
    mem: vk.DeviceMemory,
};

pub const BufferList = std.MultiArrayList(Buffer);

