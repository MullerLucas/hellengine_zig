// [Wafefront .obj file](https://en.wikipedia.org/wiki/Wavefront_.obj_file)
// https://github.com/JoshuaMasci/zig-obj/blob/main/src/lib.zig

const std = @import("std");
const resources = @import("resources.zig");
const Mesh = resources.Mesh;
const Logger = resources.Logger;

const Face = struct {
    /// starts at 1, not 0
    position: u32,
    /// starts at 1, not 0
    normal: u32,
    /// starts at 1, not 0
    uv: u32,
};

pub fn parse_obj_file(allocator: std.mem.Allocator, reader: anytype) !Mesh {
    Logger.info("parsing obj file\n", .{});

    var buffer: [1024]u8 = undefined;

    var obj_positions = std.ArrayList([3]f32).init(allocator);
    defer obj_positions.deinit();

    var obj_normals = std.ArrayList([3]f32).init(allocator);
    defer obj_normals.deinit();

    var obj_uvs = std.ArrayList([2]f32).init(allocator);
    defer obj_uvs .deinit();

    var obj_faces = std.ArrayList(Face).init(allocator);
    defer obj_faces .deinit();

    while(try reader.readUntilDelimiterOrEof(&buffer, '\n')) |raw_line| {
        const line = std.mem.trimLeft(u8, raw_line, " \t");
        Logger.debug("parsing line '{s}'\n", .{line});

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
            Logger.debug("processing vt\n", .{});
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
            const face_1 = try parse_face(splits.next().?);
            const face_2 = try parse_face(splits.next().?);
            const face_3 = try parse_face(splits.next().?);
            try obj_faces.appendSlice(&[_]Face {face_1, face_2, face_3});
        }
        else {
            Logger.warn("ignoring line starting with '{s}'\n", .{op});
            continue;
        }
    }

    var positions = std.ArrayList([3]f32).init(allocator);
    var uvs       = std.ArrayList([2]f32).init(allocator);
    var normals   = std.ArrayList([3]f32).init(allocator);
    var indices   = try std.ArrayList(u32).initCapacity(allocator, obj_faces.items.len);

    var vertex_to_index_map = std.AutoHashMap(Face, u32).init(allocator);
    defer vertex_to_index_map.deinit();


    var reused_count: usize = 0;

    for (obj_faces.items) |face| {
        if (vertex_to_index_map.get(face)) |reused_idx| {
            try indices.append(reused_idx);
            reused_count += 1;
        } else {
            const new_index = @intCast(u32, positions.items.len);

            try positions.append(obj_positions.items[face.position - 1]);
            try uvs      .append(obj_uvs      .items[face.uv       - 1]);
            try normals  .append(obj_normals  .items[face.normal   - 1]);

            try vertex_to_index_map.put(face, new_index);
            try indices.append(new_index);
        }
    }

    return Mesh {
        .allocator = allocator,
        .vertices = try positions.toOwnedSlice(),
        .uvs      = try uvs.toOwnedSlice(),
        .normals  = try normals.toOwnedSlice(),
        .indices  = try indices.toOwnedSlice(),
    };
}

fn parse_face(face_str: []const u8) !Face {
    var split = std.mem.tokenize(u8, face_str, "/");
    const position = try std.fmt.parseInt(u32, split.next().?, 10);
    const uv       = try std.fmt.parseInt(u32, split.next().?, 10);
    const normal   = try std.fmt.parseInt(u32, split.next().?, 10);

    return Face {
        .position = position,
        .uv = uv,
        .normal = normal,
    };
}
