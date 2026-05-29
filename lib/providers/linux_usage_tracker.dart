import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../database/usage_db.dart';

class LinuxUsageTracker extends ChangeNotifier {
  static final LinuxUsageTracker instance = LinuxUsageTracker._internal();
  LinuxUsageTracker._internal();

  bool _tracking = false;
  String? _lastApp;
  int _accumulatedSeconds = 0;
  Timer? _timer;

  bool get isTracking => _tracking;

  void startTracking() {
    if (_tracking) return;
    _tracking = true;
    _lastApp = null;
    _accumulatedSeconds = 0;

    _timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_tracking) {
        timer.cancel();
        return;
      }
      await _trackActiveWindow();
    });
  }

  void stopTracking() {
    _tracking = false;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _trackActiveWindow() async {
    final rawApp = await _getActiveApp();
    if (rawApp == null || rawApp.isEmpty) return;

    // Standardize to strict lowercase and trim immediately
    final normalizedApp = rawApp.toLowerCase().trim();

    if (_lastApp == normalizedApp) {
      _accumulatedSeconds += 5;

      // Commit exactly when hitting or crossing the 60-second limit
      if (_accumulatedSeconds >= 60) {
        await UsageDatabase.instance.insertUsage(
          DateTime.now(),
          normalizedApp,
          1,
        );
        _accumulatedSeconds = 0;
        notifyListeners(); // Alert the UI state streams
      }
    } else {
      // Switch context to the new window frame smoothly
      _lastApp = normalizedApp;
      _accumulatedSeconds = 0;
    }
  }

  Future<String?> _getActiveApp() async {
    try {
      final process = await Process.run('hyprctl', ['activewindow', '-j']);
      if (process.exitCode == 0) {
        final Map<String, dynamic> data = jsonDecode(process.stdout as String);

        // Check window class first, fall back to title if blank
        String? appClass = data['class'];
        if (appClass == null || appClass.isEmpty) {
          appClass = data['title'];
        }
        return appClass;
      }
    } catch (e) {
      // Graceful fallback over native terminal diagnostics
      return null;
    }
    return null;
  }
}
