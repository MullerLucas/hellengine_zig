// [Wafefront .obj file](https://en.wikipedia.org/wiki/Wavefront_.obj_file)
// https://github.com/JoshuaMasci/zig-obj/blob/main/src/lib.zig

const std = @import("std");
const engine = @import("../engine.zig");
const resources = @import("resources.zig");
const Mesh = resources.Mesh;
const Logger = resources.Logger;

const ResourceHandle = engine.core.ResourceHandle;

/// offsets start @ 1, not 0
pub const ObjFace = struct {
    position_offset: u32,
    normal_offset: u32,
    uv_offset: u32,

    material_h: ResourceHandle,
};
