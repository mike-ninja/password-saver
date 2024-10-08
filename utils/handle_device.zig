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
