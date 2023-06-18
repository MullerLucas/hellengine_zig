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


pub const ObjParseState = struct {
    var buffer: [1024]u8 = undefined;

    positions: std.ArrayList([3]f32),
    normals:   std.ArrayList([3]f32),
    uvs:       std.ArrayList([2]f32),
    faces:     std.ArrayList(ObjFace),

    position_first_idx: usize,
    normals_first_idx:  usize,
    uvs_first_idx:      usize,

    pub fn init(
        allocator: std.mem.Allocator,
        positions_first_idx: usize,
        normals_first_idx: usize,
        uvs_first_idx: usize,
    ) ObjParseState
    {
        Logger.info("creating parer state '{}' / '{}' / '{}'\n", .{positions_first_idx, normals_first_idx, uvs_first_idx});
        return ObjParseState {
            .positions = std.ArrayList([3]f32) .init(allocator),
            .normals   = std.ArrayList([3]f32) .init(allocator),
            .uvs       = std.ArrayList([2]f32) .init(allocator),
            .faces     = std.ArrayList(ObjFace).init(allocator),

            .position_first_idx = positions_first_idx,
            .normals_first_idx  = normals_first_idx,
            .uvs_first_idx      = uvs_first_idx,
        };
    }

    pub fn deinit(self: *ObjParseState) void {
        self.positions.deinit();
        self.normals.deinit();
        self.uvs.deinit();
        self.faces.deinit();
    }

    pub fn clear(self: *ObjParseState) void {
        self.positions.clearRetainingCapacity();
        self.normals.clearRetainingCapacity();
        self.uvs.clearRetainingCapacity();
        self.faces.clearRetainingCapacity();
    }
};
