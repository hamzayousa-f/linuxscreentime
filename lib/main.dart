import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/usage_db.dart';
import 'providers/linux_usage_tracker.dart';
import 'screens/home_screen.dart';

void main() async {
  // 1. Ensure Flutter binding is fully initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize SQLite FFI explicitly for Linux desktop environments
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // 3. Start the real-time background application tracking daemon
  LinuxUsageTracker.instance.startTracking();

  // 4. Initialize and configure the native window manager framework
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 750),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: "Linux Screen Time",
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.setFocus();
  });

  runApp(const LinuxScreenTimeApp());
}

class LinuxScreenTimeApp extends StatelessWidget {
  const LinuxScreenTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Linux Screen Time',
      debugShowCheckedModeBanner: false,
      // Setting up the dark baseline for our glassmorphism UI language
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