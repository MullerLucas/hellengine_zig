const std = @import("std");
const engine = @import("../engine.zig");
const vk = @import("vulkan");

pub const files = @import("files.zig");
pub const Logger = @import("../core/core.zig").log.scoped(.resources);




// ----------------------------------------------

pub const Vertex = struct {
    position: [3]f32 = .{ 0, 0, 0 },
    normal:   [3]f32 = .{ 0, 0, 0 },
    color:    [3]f32 = .{ 1, 1, 1 },
    uv:       [2]f32 = .{ 0, 0 },

    // @Todo: don't use vk stuff in here
    pub fn get_binding_description() vk.VertexInputBindingDescription {
        return vk.VertexInputBindingDescription{
            .binding = 0,
            .stride = @sizeOf(Vertex),
            .input_rate = .vertex,
        };
    }
};

// ----------------------------------------------

pub const Mesh = struct {
    pub const IndexType = u32;

    vertices: []Vertex,
    indices:  []IndexType,
    // TODO(lm): make backend generic
    internals: engine.render.vulkan.resources.MeshInternals = undefined,

    pub fn from_obj_data(allocator: std.mem.Allocator, data: *const files.ObjData) !Mesh {
        var vertices = std.ArrayList(Vertex).init(allocator);
        var indices  = try std.ArrayList(u32).initCapacity(allocator, data.faces.len);

        var face_index_map = std.AutoHashMap(files.ObjFace, u32).init(allocator);
        defer face_index_map.deinit();

        var reused_count: usize = 0;

        for (data.faces) |face| {
            if (face_index_map.get(face)) |reused_idx| {
                try indices.append(reused_idx);
                reused_count += 1;
            } else {
                const new_index = @intCast(u32, vertices.items.len);

                // subtract 1 because obj indices start at 1
                try vertices.append(Vertex {
                    .position = data.positions[face.position_offset - 1],
                    .uv       = data.uvs      [face.uv_offset       - 1],
                    .normal   = data.normals  [face.normal_offset   - 1],
                });

                try face_index_map.put(face, new_index);
                try indices.append(new_index);
            }
        }

        Logger.debug("reused '{}' indices\n", .{ reused_count });

        return Mesh {
            .vertices = try vertices.toOwnedSlice(),
            .indices  = try indices.toOwnedSlice(),
        };
    }

};
