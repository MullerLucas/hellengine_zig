const std = @import("std");

const GlfwWindow = @import("../GlfwWindow.zig");

const core   = @import("../core/core.zig");
const ResourceHandle = core.ResourceHandle;
const FrameTimer = core.time.FrameTimer(4096);

const vulkan        = @import("./vulkan/vulkan.zig");
const VulkanBackend = vulkan.VulkanBackend;

const render     = @import("render.zig");
const Logger     = render.Logger;
const RenderData = render.RenderData;

const ShaderProgram = render.ShaderProgram;
const ShaderInfo = render.ShaderInfo;
const ShaderScope = render.shader.ShaderScope;

const engine = @import("../engine.zig");
const Mesh = engine.resources.Mesh;
const Vertex = engine.resources.Vertex;

const ObjFace = engine.resources.files.ObjFace;

// ----------------------------------------------

pub const Renderer = struct {
    const mesh_limit: usize = 1024;

    allocator: std.mem.Allocator,
    frame_timer: FrameTimer,
    backend: VulkanBackend,
    meshes: core.StackArray(Mesh, mesh_limit) = .{},


    pub fn init(allocator: std.mem.Allocator, window: *GlfwWindow) !Renderer {
        Logger.info("initializing renderer-frontend\n", .{});

        var timer = try core.time.SimpleTimer.init();
        defer Logger.debug("renderer initialized in {} us\n", .{timer.read_us()});

        var self = Renderer {
            .allocator   = allocator,
            .frame_timer = try FrameTimer.init(),
            .backend     = try VulkanBackend.init(allocator, window),
        };

        try self.create_default_material();

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        Logger.info("deinitializing renderer-frontend\n", .{});
        self.backend.deinit();
    }

    pub fn draw_meshes(self: *Renderer, meshes_h: []const ResourceHandle, program: *ShaderProgram) !void {
        if (self.frame_timer.is_frame_0()) {
            Logger.debug("Timings - frame (us): {}\n", .{self.frame_timer.avg_frame_time_us()});
        }

        // @Performance: order meshes in a useful way
        var render_data = RenderData {};
        for (meshes_h) |mesh_h| {
            render_data.meshes.push(self.get_mesh(mesh_h));
        }

        self.frame_timer.start_frame();
        try self.backend.draw_render_data(&render_data, &program.info, &program.internals);
        self.frame_timer.stop_frame();
    }

    pub fn device_wait_idle(self: *Renderer) !void {
        try self.backend.wait_device_idle();
    }

    // ------------------------------------------

    pub fn create_shader_program(self: *Renderer, info: ShaderInfo) !*ShaderProgram {
        Logger.debug("creating shader-program\n", .{});

        var program = try self.allocator.create(ShaderProgram);
        program.* = ShaderProgram {
            .info = info,
        };

        try self.backend.create_shader_internals(&info, &program.internals);
        return program;
    }

    pub fn destroy_shader_program(self: *Renderer, program: *ShaderProgram) void {
        Logger.debug("destroy shader-program\n", .{});
        self.backend.destroy_shader_internals(&program.internals);
        program.deinit();
        self.allocator.destroy(program);
    }

    // ------------------------------------------

    pub fn create_material_instance(self: *Renderer, program: *ShaderProgram) !ResourceHandle {
        return try self.backend.shader_acquire_instance_resources(
            &program.info,
            &program.internals,
            .material,
            Renderer.get_default_material());
    }

    // @Todo: actually implement
    pub fn create_default_material(_: *Renderer) !void {
        Logger.err("@Todo: create default material\n", .{});
    }

    // @Todo: actually implement
    pub fn get_default_material() ResourceHandle {
        return ResourceHandle.zero;
    }

    // @Todo: actually implement
    pub fn find_material(self: *const Renderer, name: []const u8) ?ResourceHandle {
        _ = self;
        _ = name;
        return null;
    }

    // ------------------------------------------

    pub fn create_mesh_from_file(self: *Renderer, mesh_path: []const u8, texture_path: [*:0]const u8) !ResourceHandle {
        Logger.debug("creating mesh '{}' from file '{s}'\n", .{self.meshes.len, mesh_path});

        const obj_file = try std.fs.cwd().openFile(mesh_path, .{});
        defer obj_file.close();
        var reader = std.io.bufferedReader(obj_file.reader());

        var mesh = try self.parse_obj_file(reader.reader());
        try self.backend.create_mesh_internals(&mesh, texture_path);

        self.meshes.push(mesh);
        return ResourceHandle { .value = self.meshes.len - 1 };
    }

    pub fn deinit_mesh(self: *Renderer, mesh_h: ResourceHandle) void {
        const mesh = self.get_mesh_mut(mesh_h);

        self.backend.deinit_mesh_internals(mesh);

        self.allocator.free(mesh.vertices);
        self.allocator.free(mesh.indices);
    }

    pub fn get_mesh(self: *const Renderer, mesh_h: ResourceHandle) *const Mesh {
        return self.meshes.get(mesh_h.value);
    }

    pub fn get_mesh_mut(self: *Renderer, mesh_h: ResourceHandle) *Mesh {
        return self.meshes.get_mut(mesh_h.value);
    }

    // ------------------------------------------

    pub fn parse_obj_file(self: *const Renderer, reader: anytype) !Mesh {
        Logger.info("parsing obj file\n", .{});

        var buffer: [1024]u8 = undefined;

        var obj_positions = std.ArrayList([3]f32).init(self.allocator);
        defer obj_positions.deinit();

        var obj_normals = std.ArrayList([3]f32).init(self.allocator);
        defer obj_normals.deinit();

        var obj_uvs = std.ArrayList([2]f32).init(self.allocator);
        defer obj_uvs .deinit();

        var obj_faces = std.ArrayList(ObjFace).init(self.allocator);
        defer obj_faces .deinit();

        // parse obj-file
        {
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
                    const face_1 = try Renderer.parse_obj_face(splits.next().?);
                    const face_2 = try Renderer.parse_obj_face(splits.next().?);
                    const face_3 = try Renderer.parse_obj_face(splits.next().?);
                    try obj_faces.appendSlice(&[_]ObjFace {face_1, face_2, face_3});
                }
                // material uses
                else if (std.mem.eql(u8, op, "usemtl")) {
                    const mat_name = splits.next().?;
                    if (self.find_material(mat_name)) |material_h| {
                        Logger.info("material found: '{}'\n", .{material_h});
                    } else {
                        Logger.warn("could not find material with name '{s}'\n", .{mat_name});
                    }
                }
                // named objects
                else if (std.mem.eql(u8, op, "o")) {
                }
                // polygon groups
                else if (std.mem.eql(u8, op, "g")) {
                    Logger.warn("polygon groups 'g' in obj-files are not supported and will be ignored\n", .{});
                }
                else if (std.mem.eql(u8, op, "s")) {
                    Logger.warn("smooth-shading 's' in obj-files are not supported and will be ignored\n", .{});
                }
                else {
                    Logger.warn("ignoring unknown operation in obj-file '{s}'\n", .{op});
                    continue;
                }
            }
        }

        // convert obj-data to mesh
        {
            var vertices = std.ArrayList(Vertex).init(self.allocator);
            var indices  = try std.ArrayList(u32).initCapacity(self.allocator, obj_faces.items.len);
            var face_index_map = std.AutoHashMap(ObjFace, u32).init(self.allocator);
            defer face_index_map.deinit();

            var reused_count: usize = 0;

            for (obj_faces.items) |face| {
                if (face_index_map.get(face)) |reused_idx| {
                    try indices.append(reused_idx);
                    reused_count += 1;
                } else {
                    const new_index = @intCast(u32, vertices.items.len);

                    // subtract 1 because obj indices start at 1
                    try vertices.append(Vertex {
                        .position = obj_positions.items[face.position_offset - 1],
                        .uv       = obj_uvs      .items[face.uv_offset       - 1],
                        .normal   = obj_normals  .items[face.normal_offset   - 1],
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
};

