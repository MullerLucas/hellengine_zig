const std = @import("std");
const c = @import("../c.zig");


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
const Mesh     = engine.resources.Mesh;
const SubMesh  = engine.resources.SubMesh;
const Vertex   = engine.resources.Vertex;
const ObjFace  = engine.resources.files.ObjFace;
const Texture  = engine.resources.Texture;
const Material = engine.resources.Material;

// ----------------------------------------------

pub const Renderer = struct {
    // @Todo: come up with sensible values
    const mesh_limit:     usize = 1024;
    const texture_limit:  usize = 1024;
    const material_limit: usize = 1024;

    allocator: std.mem.Allocator,
    frame_timer: FrameTimer,
    backend: VulkanBackend,
    meshes: core.StackArray(Mesh, mesh_limit) = .{},
    textures: core.StackArray(Texture, texture_limit) = .{},
    materials: core.StackArray(Material, material_limit) = .{},


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

        // @Hack
        for (0..self.textures.len) |idx| {
            self.destroy_texture(ResourceHandle { .value = idx });
        }

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

    // @Todo: move somewhere else
    pub fn create_raw_image_from_file(path: [*:0]const u8) !engine.resources.RawImage {
        var width:    c_int = undefined;
        var height:   c_int = undefined;
        var channels: c_int = undefined;

        var pixels: ?[*]u8 = c.stbi_load(path, &width, &height, &channels, c.STBI_rgb_alpha);
        errdefer c.stbi_image_free(pixels);

        if (pixels == null) {
            Logger.err("failed to load image '{s}'\n", .{path});
            return error.ImageLoadFailure;
        }

        return engine.resources.RawImage {
            .width  = @intCast(u32, width),
            .height = @intCast(u32, height),
            .pixels = pixels.?,
        };
    }

    // @Todo: move somewhere else
    pub fn destroy_raw_image(image: *engine.resources.RawImage) void {
        c.stbi_image_free(image.pixels);
    }

    pub fn create_texture(self: *Renderer, path: [*:0]const u8) !ResourceHandle {
        const texture_h = ResourceHandle { .value = self.textures.len };
        Logger.debug("create texture '{}' from path '{s}", .{texture_h.value, path});

        self.textures.push(Texture { });
        const texture = self.get_texture_mut(texture_h);

        // create internals
        {
            var raw_image = try Renderer.create_raw_image_from_file(path);
            defer Renderer.destroy_raw_image(&raw_image);
            try self.backend.create_texture_internals(texture, &raw_image);
        }

        // @Todo: think about using a string
        // set path
        {
            const path_len = std.mem.indexOfSentinel(u8, 0, path);
            std.debug.assert(path_len <= Texture.name_limit);
            @memcpy(texture.path[0..path_len], path[0..path_len]);
        }

        return texture_h;
    }

    pub fn destroy_texture(self: *Renderer, texture_h: ResourceHandle) void {
        Logger.debug("destroy texture '{}'\n", .{texture_h.value});
        const texture = self.get_texture_mut(texture_h);
        self.backend.destroy_texture_internals(texture);
    }

    pub fn get_texture(self: *const Renderer, texture_h: ResourceHandle) *const Texture {
        return self.textures.get(texture_h.value);
    }

    pub fn get_texture_mut(self: *Renderer, texture_h: ResourceHandle) *Texture {
        return self.textures.get_mut(texture_h.value);
    }

    // ------------------------------------------

    pub fn create_material(self: *Renderer, program: *ShaderProgram) !ResourceHandle {
        const material_h = ResourceHandle { .value = self.materials.len };
        Logger.debug("creating material '{}'", .{material_h.value});

        self.materials.push(Material { });
        const material = self.get_material_mut(material_h);

        // @Hack
        material.textures[0] = try self.create_texture("resources/texture_v1.jpg");
        const texture = self.get_texture(material.textures[0]);

        try self.backend.create_material_internals(program, material, Renderer.get_default_material());

        self.backend.shader_set_material_texture_image(&program.internals, &texture.internals);

        return material_h;
    }

    pub fn destroy_material(self: *Renderer, _: *ShaderProgram, material_h: ResourceHandle) void {
        const material = self.get_material_mut(material_h);
        self.backend.destroy_material_internals(material);
        material.internals = undefined;
    }

    // @Todo: actually implement
    pub fn create_default_material(_: *Renderer) !void {
        Logger.err("@Todo: create default material\n", .{});
    }

    // @Todo: actually implement
    pub fn get_default_material() ResourceHandle {
        return ResourceHandle.zero;
    }

    pub fn get_material(self: *Renderer, material_h: ResourceHandle) *const Material {
        return self.materials.get(material_h.value);
    }

    pub fn get_material_mut(self: *Renderer, material_h: ResourceHandle) *Material {
        return self.materials.get_mut(material_h.value);
    }

    // @Todo: actually implement
    pub fn find_material(self: *const Renderer, name: []const u8) ?ResourceHandle {
        _ = self;
        _ = name;
        return null;
    }

    // ------------------------------------------

    pub fn create_mesh_from_file(self: *Renderer, mesh_path: []const u8) !ResourceHandle {
        Logger.debug("creating mesh '{}' from file '{s}'\n", .{self.meshes.len, mesh_path});

        const obj_file = try std.fs.cwd().openFile(mesh_path, .{});
        defer obj_file.close();
        var reader = std.io.bufferedReader(obj_file.reader());

        var mesh = try self.parse_obj_file(reader.reader());
        try self.backend.create_mesh_internals(&mesh);

        self.meshes.push(mesh);
        return ResourceHandle { .value = self.meshes.len - 1 };
    }

    pub fn destroy_mesh(self: *Renderer, mesh_h: ResourceHandle) void {
        const mesh = self.get_mesh_mut(mesh_h);

        self.backend.destroy_mesh_internals(mesh);

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
            var material_h = ResourceHandle.invalid;

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
                    const face_1 = try Renderer.parse_obj_face(splits.next().?, material_h);
                    const face_2 = try Renderer.parse_obj_face(splits.next().?, material_h);
                    const face_3 = try Renderer.parse_obj_face(splits.next().?, material_h);
                    try obj_faces.appendSlice(&[_]ObjFace {face_1, face_2, face_3});
                }
                // material uses
                else if (std.mem.eql(u8, op, "usemtl")) {
                    const mat_name = splits.next().?;
                    if (self.find_material(mat_name)) |mh| {
                        material_h = mh;
                    } else {
                        Logger.err("could not find material with name '{s}'\n", .{mat_name});
                    }
                }
                // named objects
                else if (std.mem.eql(u8, op, "o")) {
                    Logger.err("@Todo: implement 'o' support\n", .{});
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

            var mesh = Mesh {
                .vertices = try vertices.toOwnedSlice(),
                .indices  = try indices.toOwnedSlice(),
            };

            // @Todo: actually implement
            mesh.sub_meshes.push(SubMesh {
                .first_index = 0,
                .index_count = mesh.indices.len,
            });

            return mesh;
        }
    }

    fn parse_obj_face(face_str: []const u8, material_h: ResourceHandle) !ObjFace {
        var split = std.mem.tokenize(u8, face_str, "/");
        const position_offset = try std.fmt.parseInt(u32, split.next().?, 10);
        const uv_offset       = try std.fmt.parseInt(u32, split.next().?, 10);
        const normal_offset   = try std.fmt.parseInt(u32, split.next().?, 10);

        return ObjFace {
            .position_offset = position_offset,
            .uv_offset       = uv_offset,
            .normal_offset   = normal_offset,
            .material_h      = material_h,
        };
    }
};

