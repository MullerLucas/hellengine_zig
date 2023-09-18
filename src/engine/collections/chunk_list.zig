const std         = @import("std");
const collections = @import("../collections.zig");
const Chunk       = collections.Chunk;

pub fn ChunkList(comptime T: type, comptime chunk_size: usize) type {
    return struct {
        alloc:  std.mem.Allocator,
        chunks: std.ArrayList(*ChunkType),

        const Self = @This();
        const ChunkType = Chunk(T, chunk_size);

        pub inline fn init(alloc: std.mem.Allocator) Self {
            return Self {
                .alloc  = alloc,
                .chunks = std.ArrayList(*ChunkType).init(alloc),
            };
        }

        pub inline fn deinit(self: *Self) void {
            for (self.chunks.items) |chunk| {
                self.alloc.destroy(chunk);
            }

            self.chunks.deinit();
        }

        fn append_chunk(self: *Self) !void {
            const chunk = try self.alloc.create(ChunkType);
            chunk.* = .{};
            try self.chunks.append(chunk);
        }

        pub fn append(self: *Self, elem: T) !void {
            const chunk: *ChunkType = blk: {
                for (self.chunks.items) |item| {
                    if (!item.is_full()) {
                        break :blk item;
                    }
                }

                try self.append_chunk();
                break :blk self.chunks.items[self.chunks.items.len - 1];
            };

            chunk.append(elem);
        }

        pub fn ChunkListIterator(comptime field: Self.ChunkType.Field) type {
            return struct {
                const FieldType = Self.ChunkType.FieldType(field);

                list:  *Self,
                slice: ?[]FieldType   = null,
                next_chunk_idx: usize = 0,
                next_slice_idx: usize = 0,

                pub fn init(list: *Self) @This() {
                    return .{
                        .list = list,
                    };
                }

                pub fn next(self: *@This()) ?FieldType {
                    if (self.slice == null) {
                        if (self.next_chunk_idx == self.list.chunks.items.len) {
                            return null;
                        }

                        self.slice = self.list.chunks.items[self.next_chunk_idx].items(field);
                        self.next_chunk_idx += 1;
                    }

                    if (self.next_slice_idx == self.slice.?.len) {
                        self.next_slice_idx = 0;
                        self.slice = null;
                        return self.next();
                    }

                    defer self.next_slice_idx += 1;
                    return self.slice.?[self.next_slice_idx];
                }
            };
        }
    };
}

test "basic_usage" {
    const testing = std.testing;

    const Foo = struct {
        a: usize,
    };

    var list = ChunkList(Foo, 32).init(testing.allocator);
    defer list.deinit();

    for (0..20) |i| {
        try list.append(.{
            .a = i
        });
    }

    {
        var collector_1 = std.ArrayList(usize).init(testing.allocator);
        defer collector_1.deinit();

        var collector_2 = std.ArrayList(usize).init(testing.allocator);
        defer collector_2.deinit();

        for (list.chunks.items, 0..) |c, i| {
            try collector_1.append(i);

            for (c.items(.a)) |s| {
                try collector_2.append(s);
            }
        }

        try testing.expectEqualSlices(usize, collector_1.items, &[_]usize{0, 1, 2, 3, 4});
        try testing.expectEqualSlices(usize, collector_2.items, &[_]usize{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19});
    }

    {
        var collector = std.ArrayList(usize).init(testing.allocator);
        defer collector.deinit();

        var iter = ChunkList(Foo, 32).ChunkListIterator(.a).init(&list);
        while (iter.next()) |data| {
            try collector.append(data);
        }

        try testing.expectEqualSlices(usize, collector.items, &[_]usize{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19});
    }
}
