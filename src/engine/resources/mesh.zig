const std = @import("std");


pub const Mesh = struct {
    allocator: std.mem.Allocator,

    vertices: [][3]f32,
    normals:  [][3]f32,
    uvs:      [][2]f32,
    indices:  []u32,

    pub fn deinit(self: *Mesh) void {
        self.allocator.free(self.vertices);
        self.allocator.free(self.normals);
        self.allocator.free(self.uvs);
        self.allocator.free(self.indices);
    }
};

