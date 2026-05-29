import 'dart:io';

class SystemController {
  /// Kills a process by its name (e.g., 'zen-browser')
  static Future<void> killProcess(String appName) async {
    try {
      // pkill sends SIGTERM. Using 'pkill -f' matches the full command line.
      await Process.run('pkill', ['-f', appName]);
    } catch (e) {
      print("Error killing process $appName: $e");
    }
  }

  /// Sends a native Linux desktop notification
  static Future<void> sendNotification(String title, String message) async {
    try {
      await Process.run('notify-send', [title, message]);
    } catch (e) {
      print("Failed to send notification: $e");
    }
  }
}
