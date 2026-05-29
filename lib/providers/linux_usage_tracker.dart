import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/usage_db.dart';

class LinuxUsageTracker extends ChangeNotifier {
  static final LinuxUsageTracker instance = LinuxUsageTracker._internal();
  LinuxUsageTracker._internal();

  bool _tracking = false;
  String? _lastApp;
  DateTime? _lastCheck;

  bool get isTracking => _tracking;
  String? get currentApp => _lastApp;

  void startTracking() {
    if (_tracking) return;
    _tracking = true;
    _lastCheck = DateTime.now();
    _trackLoop();
  }

  void stopTracking() {
    _tracking = false;
  }

  Future<void> _trackLoop() async {
    while (_tracking) {
      await Future.delayed(const Duration(seconds: 5));
      if (!_tracking) break;

      final currentApp = await _getActiveApp();

      if (currentApp != null && currentApp.isNotEmpty) {
        final now = DateTime.now();

        if (_lastApp != null) {
          final duration = now.difference(_lastCheck!);
          final seconds = duration.inSeconds;

          if (seconds >= 5) {
            final int minutesToLog = (seconds / 60).ceil();

            if (minutesToLog > 0) {
              await UsageDatabase.instance.insertUsage(
                now,
                _lastApp!,
                minutesToLog,
              );
              notifyListeners();
            }
          }
        }
        _lastApp = currentApp;
        _lastCheck = now;
      }
    }
  }

  Future<String?> _getActiveApp() async {
    try {
      // Query Hyprland's native controller for the active focused window profile
      final result = await Process.run('hyprctl', ['activewindow']);
      if (result.exitCode != 0) return null;

      final output = result.stdout.toString();

      // Extract the native window class identifier using a clean RegExp
      final classMatch = RegExp(r'class:\s*([^\n\r]+)').firstMatch(output);
      if (classMatch != null) {
        final appClass = classMatch.group(1)!.trim();
        if (appClass.isNotEmpty && appClass != "Invalid") {
          return appClass;
        }
      }
    } catch (e) {
      debugPrint("Error detecting active Hyprland window: $e");
    }
    return null;
  }
}
