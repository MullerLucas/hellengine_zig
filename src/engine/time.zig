const std  = @import("std");

// ----------------------------------------------

pub const SimpleTimer = struct
{
    timer: std.time.Timer,

    pub fn init() !SimpleTimer
    {
        return SimpleTimer
        {
            .timer = try std.time.Timer.start()
        };
    }

    pub fn read_ns(self: *SimpleTimer) u64
    {
        return self.timer.read();
    }

    pub inline fn read_us(self: *SimpleTimer) u64
    {
        return self.read_ns() / 1000;
    }

    pub inline fn read_ms(self: *SimpleTimer) u64
    {
        return self.read_us() / 1000;
    }
};

// ----------------------------------------------

pub fn FrameTimer(comptime window_size: usize) type
{
    return struct
    {
        const Self = @This();

        timer:      std.time.Timer,
        window:     [window_size]u64 = [_]u64 {0} ** window_size,
        window_idx: usize = 0,

        pub fn init() !Self
        {
            return Self
            {
                .timer = try std.time.Timer.start()
            };
        }

        pub fn start_frame(self: *Self) void
        {
            self.timer.reset();
        }

        pub fn stop_frame(self: *Self) void
        {
            self.window[self.window_idx] = self.timer.read();

            self.window_idx += 1;
            if (self.window_idx == window_size - 1)
            {
                self.window_idx = 0;
            }
        }

        pub fn avg_frame_time_ns(self: *const Self) u64
        {
            var timings: u64 = 0;
            var frames: u64 = 0;

            for (self.window) |win|
            {
                if (win == 0) { break; }
                timings += win;
                frames  += 1;
            }

            if (frames == 0) { return 0; }

            return timings / frames;
        }

        pub inline fn avg_frame_time_us(self: *const Self) u64
        {
            return self.avg_frame_time_ns() / 1000;
        }

        pub inline fn avg_frame_time_ms(self: *const Self) u64
        {
            return self.avg_frame_time_us() / 1000;
        }

        pub inline fn avg_fps(self: *const Self) u64
        {
            const ns_per_second = 1 * 1000 * 1000 * 1000;
            const time_ns = self.avg_frame_time_ns();
            if (time_ns == 0) { return 0; }
            return ns_per_second / time_ns;
        }

        pub fn is_frame_0(self: *const Self) bool
        {
            return self.window_idx == 0;
        }
    };
}

// ----------------------------------------------
