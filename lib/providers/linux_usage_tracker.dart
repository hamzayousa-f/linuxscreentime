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
      // Poll every 5 seconds as specified in the blueprint
      await Future.delayed(const Duration(seconds: 5));
      if (!_tracking) break;

      final currentApp = await _getActiveApp();

      if (currentApp != null && currentApp.isNotEmpty) {
        final now = DateTime.now();

        if (_lastApp != null) {
          final duration = now.difference(_lastCheck!);
          final seconds = duration.inSeconds;

          // If a tracking interval has passed, safely convert down to minutes
          if (seconds >= 5) {
            // Convert to minutes (ceil handles fractional increments cleanly)
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
      // 1. Fetch the hex ID of the active window
      final windowResult = await Process.run('xprop', ['-root', '_NET_ACTIVE_WINDOW']);
      if (windowResult.exitCode != 0) return null;

      final windowIdMatch = RegExp(r'#\s+(0x[a-fA-F0-9]+)').firstMatch(windowResult.stdout.toString());
      if (windowIdMatch == null) return null;
      final windowId = windowIdMatch.group(1);

      if (windowId == null || windowId == "0x0") return null;

      // 2. Fetch the WM_CLASS application name string using that window ID
      final classResult = await Process.run('xprop', ['-id', windowId, 'WM_CLASS']);
      if (classResult.exitCode != 0) return null;

      // Cleanly parse the last quote containing the official app name class
      final classMatch = RegExp(r'"([^"]+)"\s*$').firstMatch(classResult.stdout.toString());
      if (classMatch != null) {
        return classMatch.group(1); 
      }
    } catch (e) {
      debugPrint("Error detecting active window: $e");
    }
    return null;
  }
}