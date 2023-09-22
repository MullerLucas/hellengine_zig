const std = @import("std");

pub fn UniqueHandle(comptime ident_in: usize) type {
    return struct {
        value: usize,

        const Self = @This();
        pub const ident: usize = ident_in;
        pub const zero:    Self = .{ .value = 0 };
        pub const invalid: Self = .{ .value = std.math.maxInt(usize) };

        pub fn eql(self: Self, other: Self) bool {
            return self.value == other.value;
        }

        pub fn is_valid(self: Self) bool {
            return self.value != invalid.value;
        }
    };
}

