import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/usage_db.dart';
import 'providers/linux_usage_tracker.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite FFI explicitly for Linux desktop environments
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Start the real-time background application tracking daemon
  LinuxUsageTracker.instance.startTracking();

  // Initialize and configure the native window manager framework
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 750),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: "Linux Screen Time",
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const LinuxScreenTimeApp());
}

class LinuxScreenTimeApp extends StatefulWidget {
  const LinuxScreenTimeApp({super.key});

  @override
  State<LinuxScreenTimeApp> createState() => _LinuxScreenTimeAppState();
}

class _LinuxScreenTimeAppState extends State<LinuxScreenTimeApp>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Allow standard close behavior so it minimizes/closes cleanly without a tray lock
    windowManager.setPreventClose(false);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // DO NOT stop tracking here. Let the daemon run in the background!
    // We just allow the window frame to close cleanly.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linux Screen Time',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.purple,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
