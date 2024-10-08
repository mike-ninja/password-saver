const std = @import("std");
const c = @cImport({
    @cInclude("libudev.h");
})

pub fn main() anyerror!void {
    // Daemonize the process
    daemonize() catch |err| {
        std.debug.print("Failed to daemonize: {}\n", .{err});
        return;
    };

    var udev = c.udev_new();
    if (udev == null) {
        std.debug.print("Failed to create udev\n", .{});
        return;
    }
    defer c.udev_unref(udev);

    var monitor = c.udev_monitor_new_from_netlink(udev, "udev");
    if (monitor == null) {
        std.debug.print("Failed to create udev monitor\n", .{});
        return;
    }
    defer c.udev_monitor_unref(monitor);

    c.udev_monitor_filter_add_match_subsystem_devtype(monitor, "block", null);
    c.udev_monitor_enable_receiving(monitor);

    const fd = c.udev_monitor_get_fd(monitor);

    var pollfds = [_]std.os.pollfd{
        .{
            .fd = fd,
            .events = std.os.POLLIN,
            .revents = 0,
        },
    };

    while (true) {
        const poll_res = try std.os.poll(&pollfds, -1);
        if (poll_res < 0) {
            std.debug.print("Poll error\n", .{});
            break;
        }

        if (pollfds[0].revents & std.os.POLLIN != 0) {
            var device = c.udev_monitor_receive_device(monitor);
            if (device != null) {
                const action = c.udev_device_get_action(device);
                if (std.mem.eql(u8, std.mem.spanFromCStr(action), "add")) {
                    handle_device(device) catch |err| {
                        std.debug.print("Error handling device: {}\n", .{err});
                    };
                }
                c.udev_device_unref(device);
            }
        }
    }
}

fn daemonize() !void {
    const fork_result = try std.os.fork();
    if (fork_result > 0) {
        // Parent process exits
        std.os.exit(0);
    } else if (fork_result == 0) {
        // Child process continues
        try std.os.setsid();
        try std.fs.cwd().chdir();
        std.os.close(std.os.stdin_fd);
        std.os.close(std.os.stdout_fd);
        std.os.close(std.os.stderr_fd);
    }
}

fn handle_device(device: ?*c.struct_udev_device) !void {
    if (device == null) return;

    const devtype = c.udev_device_get_devtype(device);
    if (devtype == null) return;

    if (!std.mem.eql(u8, std.mem.spanFromCStr(devtype), "partition")) {
        return;
    }

    const devnode = c.udev_device_get_devnode(device);
    if (devnode == null) return;

    const uuid_cstr = c.udev_device_get_property_value(device, "ID_FS_UUID");
    if (uuid_cstr == null) return;

    const uuid = std.mem.spanFromCStr(uuid_cstr);

    const target_uuid = "YOUR_TARGET_UUID_HERE";
    if (std.mem.eql(u8, uuid, target_uuid)) {
        try mount_device(devnode);

        defer unmount_device("/mnt/usb");

        try write_file("/mnt/usb/output.txt", "Data to write");

        std.debug.print("Operation completed successfully\n", .{});
    }
}

fn mount_device(devnode: [*c]const u8) !void {
    const mount_point = "/mnt/usb";

    // Ensure the mount point exists
    std.fs.mkdirp(mount_point, 0o755) catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };

    const args = &[_][]const u8{ devnode, mount_point };

    var mount_cmd = try std.process.Command.init(std.heap.c_allocator, "mount", args);
    defer mount_cmd.deinit();

    try mount_cmd.spawnAndWait();
}

fn unmount_device(mount_point: []const u8) !void {
    const args = &[_][]const u8{ mount_point };

    var umount_cmd = try std.process.Command.init(std.heap.c_allocator, "umount", args);
    defer umount_cmd.deinit();

    try umount_cmd.spawnAndWait();
}

fn write_file(path: []const u8, content: []const u8) !void {
    var file = try std.fs.File.openWrite(path);
    defer file.close();

    try file.writeAll(content);
}
