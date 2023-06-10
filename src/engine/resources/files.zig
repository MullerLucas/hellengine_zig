// [Wafefront .obj file](https://en.wikipedia.org/wiki/Wavefront_.obj_file)
// https://github.com/JoshuaMasci/zig-obj/blob/main/src/lib.zig

const std = @import("std");
const resources = @import("resources.zig");
const Mesh = resources.Mesh;
const Logger = resources.Logger;

/// offsets start @ 1, not 0
pub const ObjFace = struct {
    position_offset: u32,
    normal_offset: u32,
    uv_offset: u32,
};

pub const ObjData = struct {
    allocator: std.mem.Allocator,
    positions: [][3]f32,
    normals:   [][3]f32,
    uvs:       [][2]f32,
    faces:     []ObjFace,

    /// expects input data to be triangulated
    pub fn parse_file(allocator: std.mem.Allocator, reader: anytype) !ObjData {
        Logger.info("parsing obj file\n", .{});

        var buffer: [1024]u8 = undefined;

        var obj_positions = std.ArrayList([3]f32).init(allocator);
        defer obj_positions.deinit();

        var obj_normals = std.ArrayList([3]f32).init(allocator);
        defer obj_normals.deinit();

        var obj_uvs = std.ArrayList([2]f32).init(allocator);
        defer obj_uvs .deinit();

        var obj_faces = std.ArrayList(ObjFace).init(allocator);
        defer obj_faces .deinit();

        while(try reader.readUntilDelimiterOrEof(&buffer, '\n')) |raw_line| {
            const line = std.mem.trimLeft(u8, raw_line, " \t");
            // Logger.debug("parsing line '{s}'\n", .{line});

            if (line[0] == '#') { continue; }

            var splits = std.mem.tokenize(u8, line, " ");
            const op = splits.next().?;


            // positions coordinates
            if (std.mem.eql(u8, op, "v")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                const z = try std.fmt.parseFloat(f32, splits.next().?);
                try obj_positions.append([_]f32 { x, y, z });
            }
            // texture coordinates
            else if (std.mem.eql(u8, op, "vt")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                try obj_uvs.append([_]f32 { x, y });
            }
            // normals
            else if (std.mem.eql(u8, op, "vn")) {
                const x = try std.fmt.parseFloat(f32, splits.next().?);
                const y = try std.fmt.parseFloat(f32, splits.next().?);
                const z = try std.fmt.parseFloat(f32, splits.next().?);
                try obj_normals.append([_]f32 { x, y, z });
            }
            // faces
            else if (std.mem.eql(u8, op, "f")) {
                // @Todo: triangulate ngons
                const face_1 = try ObjData.parse_face(splits.next().?);
                const face_2 = try ObjData.parse_face(splits.next().?);
                const face_3 = try ObjData.parse_face(splits.next().?);
                try obj_faces.appendSlice(&[_]ObjFace {face_1, face_2, face_3});
            }
            else {
                Logger.warn("ignoring line starting with '{s}'\n", .{op});
                continue;
            }
        }

        return ObjData {
            .allocator = allocator,
            .positions = try obj_positions.toOwnedSlice(),
            .normals   = try obj_normals  .toOwnedSlice(),
            .uvs       = try obj_uvs      .toOwnedSlice(),
            .faces     = try obj_faces    .toOwnedSlice(),
        };
    }

    fn parse_face(face_str: []const u8) !ObjFace {
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

    // @Todo: think about inconsistency between creating / destroying ObjData vs. Mesh
    pub fn deinit(self: *ObjData) void {
        self.allocator.free(self.positions);
        self.allocator.free(self.normals);
        self.allocator.free(self.uvs);
        self.allocator.free(self.faces);
    }
};
