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
const ObjParseState = engine.resources.files.ObjParseState;
const Texture  = engine.resources.Texture;
const Material = engine.resources.Material;

// ----------------------------------------------

pub const Renderer = struct {
    // @Todo: come up with sensible values
    const mesh_limit:     usize = 1024;
    const texture_limit:  usize = 1024;
    const material_limit: usize = 1024;
    const program_limit:  usize = 1024;

    allocator: std.mem.Allocator,
    frame_timer: FrameTimer,
    backend: VulkanBackend,
    meshes:    core.StackArray(Mesh, mesh_limit) = .{},
    textures:  core.StackArray(Texture, texture_limit) = .{},
    materials: core.StackArray(Material, material_limit) = .{},
    programs:  core.StackArray(*ShaderProgram, program_limit) = .{},

    current_frame: usize = 0,


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

    pub fn begin_frame(self: *Renderer) void {
        self.current_frame += 1;
    }

    pub fn end_frame(self: *Renderer) void {
        _ = self;
    }

    pub fn draw_meshes(self: *Renderer, meshes_h: []const ResourceHandle, program: *ShaderProgram) !void {
        if (self.frame_timer.is_frame_0()) {
            Logger.debug("Timings - frame (us): {}\n", .{self.frame_timer.avg_frame_time_us()});
        }

        // @Perf: order meshes in a useful way
        var render_data = RenderData {};
        for (meshes_h) |mesh_h| {
            render_data.meshes.push(self.get_mesh(mesh_h));
        }

        // start frame
        self.frame_timer.start_frame();
        try self.backend.start_render_pass(&program.info, &program.internals);

        // iterate meshes
        for (render_data.meshes.as_slice(), 0..) |mesh, idx| {
            try self.backend.upload_shader_data(&program.internals, mesh, idx);

            // iterate sub-meshes
            // @Todo: bind material used by sub-mesh
            for (mesh.sub_meshes.as_slice()) |sub_mesh| {
                // @Perf: don't switch materials on a per sub-mesh basis
                const material = self.get_material_mut(sub_mesh.material_h);
                try self.backend.shader_apply_material(program, material, self.current_frame);

                // @Bug: There is a Bug if you try to render the materials in order 4 - 3 - 4
                try self.backend.draw_mesh(&sub_mesh);
            }
        }

        // end frame
        try self.backend.submit_render_pass();
        self.frame_timer.stop_frame();
    }

    pub fn device_wait_idle(self: *Renderer) !void {
        try self.backend.wait_device_idle();
    }

    // ------------------------------------------

    pub fn create_shader_program(self: *Renderer, info: ShaderInfo) !ResourceHandle {
        const program_h = ResourceHandle { .value = self.programs.len };
        Logger.debug("creating shader-program '{}'\n", .{program_h.value});

        var program = try self.allocator.create(ShaderProgram);
        program.* = ShaderProgram {
            .info = info,
        };
        self.programs.push(program);

        try self.backend.create_shader_internals(&info, &program.internals);
        return program_h;
    }

    pub fn destroy_shader_program(self: *Renderer, program_h: ResourceHandle) void {
        Logger.debug("destroy shader-program\n", .{});

        const program = self.get_shader_program_mut(program_h);
        self.backend.destroy_shader_internals(&program.internals);
        program.deinit();
        self.allocator.destroy(program);
    }

    pub fn get_shader_program(self: *const Renderer, program_h: ResourceHandle) *const ShaderProgram {
        return self.programs.get(program_h.value).*;
    }

    pub fn get_shader_program_mut(self: *Renderer, program_h: ResourceHandle) *ShaderProgram {
        return self.programs.get_mut(program_h.value).*;
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

    pub fn create_material(self: *Renderer, program_h: ResourceHandle, material_name: []const u8, texture_path: [*:0]const u8) !ResourceHandle {
        const material_h = ResourceHandle { .value = self.materials.len };
        Logger.debug("creating material '{}'", .{material_h.value});

        self.materials.push(Material {
            .name      = Material.MaterialName.from_slice(material_name),
            .program_h = program_h,
        });
        const material = self.get_material_mut(material_h);

        // @Hack
        material.textures_h[0] = try self.create_texture(texture_path);

        const program = self.get_shader_program_mut(program_h);
        try self.backend.create_material_internals(program, material, Renderer.get_default_material());

        const texture = self.get_texture(material.textures_h[0]);
        self.backend.shader_set_material_texture_image(&program.internals, &material.internals, &texture.internals);

        return material_h;
    }

    pub fn destroy_material(self: *Renderer, material_h: ResourceHandle) void {
        Logger.debug("destroying material '{}'\n", .{material_h.value});
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
    pub fn find_material(self: *const Renderer, material_name: []const u8) ?ResourceHandle {
        for (self.materials.as_slice(), 0..) |material, idx| {
            if (material.name.eql_slice(material_name)) {
                // @Hack
                return ResourceHandle { .value = idx };
            }
        }
        return null;
    }

    // ------------------------------------------

    pub fn create_meshes_from_file(self: *Renderer, mesh_path: []const u8) !std.ArrayList(ResourceHandle) {
        Logger.debug("creating mesh '{}' from file '{s}'\n", .{self.meshes.len, mesh_path});

        const obj_file = try std.fs.cwd().openFile(mesh_path, .{});
        defer obj_file.close();
        var reader = std.io.bufferedReader(obj_file.reader());

        // @Perf:
        var meshes = try self.parse_obj_file(reader.reader());
        defer meshes.deinit();
        var meshes_h = try std.ArrayList(ResourceHandle).initCapacity(self.allocator, meshes.items.len);

        for (0..meshes.items.len) |idx| {
            Logger.warn("i: {}\n", .{idx});
            var mesh = meshes.items[idx];
            try self.backend.create_mesh_internals(&mesh);
            self.meshes.push(mesh);
            try meshes_h.append(ResourceHandle { .value = self.meshes.len - 1 });
        }

        return meshes_h;
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

    // @Perf:
    pub fn parse_obj_file(self: *const Renderer, reader: anytype) !std.ArrayList(Mesh) {
        Logger.info("parsing obj file\n", .{});

        var buffer: [1024]u8 = undefined;

        var state = ObjParseState.init(self.allocator, 0, 0, 0);
        defer state.deinit();

        var meshes = std.ArrayList(Mesh).init(self.allocator);
        // defer meshes.deinit();

        var curr_material_h = ResourceHandle.invalid;



        while(try reader.readUntilDelimiterOrEof(&buffer, '\n')) |raw_line| {
            const line = std.mem.trimLeft(u8, raw_line, " \t");

            if (line[0] == '#') { continue; }

            var splits = std.mem.tokenize(u8, line, " ");
            const op = splits.next().?;

            // named objects
            if (std.mem.eql(u8, op, "o")) {
                Logger.debug("parsing o - '{s}'\n", .{splits.next().?});

                // if this is not the first object, create a mesh from the current state
                if (state.positions.items.len > 0) {
                    try meshes.append(try self.create_mesh_from_obj_data(&state));

                    // reset state
                    state.position_first_idx = state.positions.items.len;
                    state.normals_first_idx  = state.normals.items.len;
                    state.uvs_first_idx      = state.uvs.items.len;
                    state.clear();
                }
            }
            // polygon groups
            else if (std.mem.eql(u8, op, "g")) {
                Logger.warn("polygon groups 'g' in obj-files are not supported and will be ignored\n", .{});
                continue;
            }
            else if (std.mem.eql(u8, op, "s")) {
                Logger.warn("smooth-shading 's' in obj-files are not supported and will be ignored\n", .{});
                continue;
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
                const face_1 = try Renderer.parse_obj_face(splits.next().?, curr_material_h);
                const face_2 = try Renderer.parse_obj_face(splits.next().?, curr_material_h);
                const face_3 = try Renderer.parse_obj_face(splits.next().?, curr_material_h);
                try state.faces.appendSlice(&[_]ObjFace {face_1, face_2, face_3});
            }
            // material uses
            else if (std.mem.eql(u8, op, "usemtl")) {
                const mat_name = splits.next().?;
                if (self.find_material(mat_name)) |mh| {
                    curr_material_h = mh;
                } else {
                    Logger.err("could not find material with name '{s}'\n", .{mat_name});
                }
            }
            else {
                Logger.warn("ignoring unknown operation in obj-file '{s}'\n", .{op});
                continue;
            }
        }

        // create a mesh from the current state
        if (state.positions.items.len > 0) {
            try meshes.append(try self.create_mesh_from_obj_data(&state));
        }

        std.debug.assert(meshes.items.len > 0);
        Logger.info("created '{}' meshes\n {}\n", .{meshes.items.len, meshes});

        return meshes;
    }

    fn create_mesh_from_obj_data(self: *const Renderer, state: *ObjParseState) !Mesh {
        var vertices = std.ArrayList(Vertex).init(self.allocator);
        var indices  = try std.ArrayList(u32).initCapacity(self.allocator, state.faces.items.len);
        var face_index_map = std.AutoHashMap(ObjFace, u32).init(self.allocator);
        defer face_index_map.deinit();

        var reused_count: usize = 0;
        std.debug.assert(state.faces.items.len > 0);
        var curr_material_h: ResourceHandle = state.faces.items[0].material_h;
        var first_index: usize = 0;

        var mesh = Mesh {
            .vertices = undefined,
            .indices  = undefined,
        };

        for (state.faces.items) |face| {
            // @Perf: fix hashing to filter out reused indices
            // if (face_index_map.get(face)) |reused_idx| {
            //     try indices.append(reused_idx);
            //     reused_count += 1;
            // } else
        {
                const new_index = @intCast(u32, vertices.items.len);

                if (!face.material_h.eql(curr_material_h)) {
                    std.debug.assert(curr_material_h.is_valid());

                    mesh.sub_meshes.push(SubMesh {
                        .first_index = first_index,
                        .index_count = indices.items.len - first_index,
                        .material_h = curr_material_h,
                    });

                    first_index     = indices.items.len;
                    curr_material_h = face.material_h;
                }

                // subtract 1 because obj indices start at 1
                try vertices.append(Vertex {
                    .position = state.positions.items[face.position_offset - 1 - state.position_first_idx],
                    .normal   = state.normals  .items[face.normal_offset   - 1 - state.normals_first_idx ],
                    .uv       = state.uvs      .items[face.uv_offset       - 1 - state.uvs_first_idx     ],
                });

                try face_index_map.put(face, new_index);
                try indices.append(new_index);
            }
        }

        std.debug.assert(curr_material_h.is_valid());
        mesh.sub_meshes.push(SubMesh {
            .first_index = first_index,
            .index_count = indices.items.len - first_index,
            .material_h  = curr_material_h,
        });

        mesh.vertices = try vertices.toOwnedSlice();
        mesh.indices  = try indices.toOwnedSlice();

        Logger.debug("reused '{}' indices\n", .{ reused_count });

        return mesh;
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

