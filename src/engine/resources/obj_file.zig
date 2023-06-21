// [Wafefront .obj file](https://en.wikipedia.org/wiki/Wavefront_.obj_file)
// https://github.com/JoshuaMasci/zig-obj/blob/main/src/lib.zig

const std = @import("std");
const engine = @import("../engine.zig");
const resources = @import("resources.zig");
const Geometry = resources.Geometry;
const GeometryConfig = resources.GeometryConfig;
const Logger = resources.Logger;
const Vertex = engine.resources.Vertex;

const ResourceHandle = engine.core.ResourceHandle;

/// offsets start @ 1, not 0
pub const ObjFace = struct {
    position_offset: u32,
    normal_offset: u32,
    uv_offset: u32,
};


pub const ObjFileParseState = struct {

    allocator: std.mem.Allocator,

    positions: std.ArrayList([3]f32),
    normals:   std.ArrayList([3]f32),
    uvs:       std.ArrayList([2]f32),
    faces:     std.ArrayList(ObjFace),

    material_name: [512]u8,
    material_name_len: usize,

    pub fn init(allocator: std.mem.Allocator) ObjFileParseState {
        return ObjFileParseState {
            .allocator = allocator,
            .positions = std.ArrayList([3]f32) .init(allocator),
            .normals   = std.ArrayList([3]f32) .init(allocator),
            .uvs       = std.ArrayList([2]f32) .init(allocator),
            .faces     = std.ArrayList(ObjFace).init(allocator),
            .material_name     = undefined, // @Todo
            .material_name_len = 0,
        };
    }

    pub fn deinit(self: *ObjFileParseState) void {
        self.positions.deinit();
        self.normals.deinit();
        self.uvs.deinit();
        self.faces.deinit();
    }
};

// ----------------------------------------------------------------------------

pub const ObjFileLoader = struct {
    pub fn parse_obj_file(allocator: std.mem.Allocator, reader: anytype) !std.ArrayList(GeometryConfig) {
        Logger.info("parsing obj file\n", .{});

        var line_buffer: [1024]u8 = undefined;

        var state = ObjFileParseState.init(allocator);
        defer state.deinit();

        var geometry_configs = std.ArrayList(GeometryConfig).init(allocator);


        while(try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |raw_line| {
            const line = std.mem.trimLeft(u8, raw_line, " \t");

            if (line.len == 0)  { continue; }
            if (line[0] == '#') { continue; }

            var splits = std.mem.tokenize(u8, line, " ");
            const op = splits.next().?;

            // groups
            if (std.mem.eql(u8, op, "g")) {
                const group_name = splits.next().?;
                Logger.debug("[OBJ] group: '{s}'\n", .{group_name});

                if (state.faces.items.len > 0) {
                    try geometry_configs.append(try ObjFileLoader.create_geometry_config_from_group(&state));
                    state.faces.clearRetainingCapacity();
                }
            }
            // positions coordinates
            else if (std.mem.eql(u8, op, "v")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                const z = try std.fmt.parseFloat(f32, splits.next().?);
                try state.positions.append([_]f32 { x, y, z });
            }
            // texture coordinates
            else if (std.mem.eql(u8, op, "vt")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                try state.uvs.append([_]f32 { x, y });
            }
            // normals
            else if (std.mem.eql(u8, op, "vn")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                const z = try std.fmt.parseFloat(f32, splits.next().?);
                try state.normals.append([_]f32 { x, y, z });
            }
            // faces
            else if (std.mem.eql(u8, op, "f")) {
                // @Todo: triangulate ngons
                const face_1 = try ObjFileLoader.parse_obj_face(splits.next().?);
                const face_2 = try ObjFileLoader.parse_obj_face(splits.next().?);
                const face_3 = try ObjFileLoader.parse_obj_face(splits.next().?);
                try state.faces.appendSlice(&[_]ObjFace {face_1, face_2, face_3});
            }
            // material uses
            else if (std.mem.eql(u8, op, "usemtl")) {
                const mat_name = splits.next().?;
                std.debug.assert(mat_name.len < state.material_name.len);
                @memcpy(state.material_name[0..mat_name.len], mat_name);
                state.material_name_len = mat_name.len;
            }
            else {
                Logger.warn("ignoring unknown operation in obj-file '{s}'\n", .{op});
                continue;
            }
        }

        // create a mesh from the current state
        if (state.positions.items.len > 0) {
            try geometry_configs.append(try ObjFileLoader.create_geometry_config_from_group(&state));
        }

        std.debug.assert(geometry_configs.items.len > 0);
        Logger.info("read '{}' geometry configs from obj file\n", .{geometry_configs.items.len});

        return geometry_configs;
    }

    fn parse_obj_face(face_str: []const u8) !ObjFace {
        var split = std.mem.tokenize(u8, face_str, "/");
        const position_offset = try std.fmt.parseInt(u32, split.next().?, 10);
        const uv_offset       = try std.fmt.parseInt(u32, split.next().?, 10);
        const normal_offset   = try std.fmt.parseInt(u32, split.next().?, 10);

        return ObjFace {
            .position_offset = position_offset,
            .uv_offset       = uv_offset,
            .normal_offset   = normal_offset,
        };
    }

    fn create_geometry_config_from_group(state: *ObjFileParseState) !GeometryConfig {
        var vertices = std.ArrayList(Vertex).init(state.allocator);
        var indices  = try std.ArrayList(u32).initCapacity(state.allocator, state.faces.items.len);
        std.debug.assert(state.faces.items.len > 0);

        for (state.faces.items) |face| {
            const new_index = @intCast(u32, vertices.items.len);

            try vertices.append(Vertex {
                .position = state.positions.items[face.position_offset - 1],
                .normal   = state.normals  .items[face.normal_offset   - 1],
                .uv       = state.uvs      .items[face.uv_offset       - 1],
            });

            try indices.append(new_index);
        }

        return GeometryConfig {
            .vertices = try vertices.toOwnedSlice(),
            .indices  = try indices .toOwnedSlice(),

            .material_name = state.material_name,
            .material_name_len = state.material_name_len,
        };
    }
};
