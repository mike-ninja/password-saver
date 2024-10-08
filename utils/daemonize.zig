const std = @import("std");

fn daemoonize() !void {
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
