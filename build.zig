const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const exe = b.addExecutable("usb_deamon", "src/main.zig");
    exe.linkSystemLibrary("udev");
    exe.setBuildMode(b.standardReleaseOptions());
    exe.install();
}

