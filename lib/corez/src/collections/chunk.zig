const std = @import("std");
const assert = std.debug.assert;

pub fn Chunk(comptime T: type, comptime N: usize) type {
    return struct {
        bytes: [byte_count] u8 = undefined,
        len: usize = 0,

        const Self = @This();
        const byte_count: usize = N;

        const Elem = switch (@typeInfo(T)) {
            .Struct => T,
            .Union  => |u| struct {
                pub const Bare = @Type(.{ .Union = .{
                    .layout = u.layout,
                    .tag_type = u.tag_type,
                    .fields = u.fields,
                    .decls = &.{}
                }});
                pub const Tag = u.tag_type orelse @compileError("Union does not support untagged unions");
                tags: Tag,
                data: Bare,

                pub fn from_t(outer: T) @This() {
                    const tag = std.meta.activeTag(outer);
                    return .{
                        .tags = tag,
                        .data = switch (tag) {
                            inline else => |t| @unionInit(Bare, @tagName(t), @field(outer, @tagName(t)))
                        }
                    };
                }

                pub fn to_t(tag: Tag, bare: Bare) T {
                    return switch (tag) {
                        inline else => |t| @unionInit(T, @tagName(t), @field(bare, @tagName(t))),
                    };
                }
            },
            else => @compileError("Chunk only supports structs and unions")
        };

        const fields = std.meta.fields(Elem);

        const capacity: usize = blk: {
            assert(sizes.bytes.len > 0);
            var total_bytes = 0;
            for (sizes.bytes) |size| {
                total_bytes += size;
            }

            const first_percentage   = @as(f32, sizes.bytes[0]) / @as(f32, total_bytes);
            const first_bytes: usize = @intFromFloat(byte_count * first_percentage);
            const first_count        = first_bytes / sizes.bytes[0];

            break :blk first_count;
        };

        /// `sizes.bytes` is an array of @sizeOf each T field. Sorted by alignment, descending.
        /// `sizes.fields` is an array mapping from `sizes.bytes` array index to field index.
        const sizes = blk: {
            const Data = struct {
                size: usize,
                size_index: usize,
                alignment: usize,
            };

            var data: [fields.len]Data = undefined;
            for (fields, 0..) |field_info, i| {
                data[i] = .{
                    .size = @sizeOf(field_info.type),
                    .size_index = i,
                    .alignment = if (@sizeOf(field_info.type) == 0) @alignOf(field_info.type)
                                 else field_info.alignment,
                };
            }

            const Sort = struct {
                fn less_than(context: void, lhs: Data, rhs: Data) bool {
                    _ = context;
                    return lhs.alignment > rhs.alignment;
                }
            };
            std.mem.sort(Data, &data, {}, Sort.less_than);

            var sizes_bytes: [fields.len]usize = undefined;
            var field_indexes: [fields.len]usize = undefined;

            for (data, 0..) |field, i| {
                sizes_bytes[i] = field.size;
                field_indexes[i] = field.size_index;
            }

            break :blk .{
                .bytes  = sizes_bytes,
                .fields = field_indexes,
            };
        };

        pub const Field = std.meta.FieldEnum(Elem);

        pub fn FieldType(comptime field: Field) type {
            return std.meta.fieldInfo(Elem, field).type;
        }

        pub const Slice = struct {
            const capacity: usize = Self.capacity;

            ptrs: [fields.len][*]u8,
            len: usize,

            pub fn items(self_raw: Slice, comptime field: Field) []FieldType(field) {
                const self = self_raw;

                const F = FieldType(field);

                if (Self.capacity == 0) {
                    return &[_]F{};
                }

                const byte_ptr = self.ptrs[@intFromEnum(field)];
                const casted_ptr: [*]F = if (@sizeOf(F) == 0)
                        undefined
                    else
                        @ptrCast(@alignCast(byte_ptr));

                return casted_ptr[0..self.len];
            }

            pub fn set(self: *Slice, idx: usize, elem: T) void {
                const e = switch (@typeInfo(T)) {
                    .Struct => elem,
                    .Union  => Elem.from_t(elem),
                    else    => unreachable,
                };

                inline for (fields, 0..) |field_info, i| {
                    self.items(@as(Field, @enumFromInt(i)))[idx] = @field(e, field_info.name);
                }
            }

            pub fn get(self: Slice, idx: usize) T {
                var s = self;

                var result: Elem = undefined;
                inline for (Self.fields, 0..) |field_info, i| {
                    @field(result, field_info.name) = s.items(@as(Field, @enumFromInt(i)))[idx];
                }
                return switch (@typeInfo(T)) {
                    .Struct => result,
                    .Union  => Elem.to_t(result.tags, result.data),
                    else    => unreachable,
                };
            }
        };

        pub fn is_full(self: *Self) bool {
            return self.len == Self.capacity;
        }

        pub fn slice(self: *Self) Slice {
            var result = Slice {
                .ptrs     = undefined,
                .len      = self.len,
            };

            var ptr: [*]u8 = &self.bytes;
            for (Self.sizes.bytes, Self.sizes.fields) |field_size, i| {
                result.ptrs[i] = ptr;
                ptr += field_size * Self.capacity;
            }

            return result;
        }

        pub fn items(self: *Self, comptime field: Field) []FieldType(field) {
            return self.slice().items(field);
        }

        pub fn set(self: *Self, idx: usize, elem: T) void {
            var slices = self.slice();
            slices.set(idx, elem);
        }

        pub fn get(self: *Self, idx: usize) T {
            return self.slice().get(idx);
        }

        pub fn append(self: *Self, elem: T) void {
            assert(self.len < Self.capacity);
            self.len += 1;
            self.set(self.len - 1, elem);
        }

        pub fn pop(self: *Self) T {
            const val = self.get(self.len - 1);
            self.len -= 1;
            return val;
        }
    };
}
test "basic usage" {
    const Foo = struct {
        a: u32,
        b: []const u8,
        c: u8,
    };

    const FooChunk = Chunk(Foo, 64);
    var chunk = FooChunk{};

    try std.testing.expectEqual(@as(usize, 0), chunk.items(.a).len);

    chunk.append(.{
        .a = 1,
        .b = "one",
        .c = '1',
    });

    chunk.append(.{
        .a = 2,
        .b = "two",
        .c = '2',
    });

    try std.testing.expectEqualSlices(u32, chunk.items(.a), &[_]u32 {1, 2});
    try std.testing.expectEqualSlices(u8,  chunk.items(.c), &[_]u8  {'1', '2'});

    try std.testing.expectEqual(@as(usize, 2), chunk.items(.b).len);
    try std.testing.expectEqualStrings("one", chunk.items(.b)[0]);
    try std.testing.expectEqualStrings("two", chunk.items(.b)[1]);
}
