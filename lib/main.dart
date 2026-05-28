import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:system_tray/system_tray.dart';
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
    await windowManager.setFocus();
  });

  runApp(const LinuxScreenTimeApp());
}

class LinuxScreenTimeApp extends StatefulWidget {
  const LinuxScreenTimeApp({super.key});

  @override
  State<LinuxScreenTimeApp> createState() => _LinuxScreenTimeAppState();
}

// Implement WindowListener to intercept user close actions
class _LinuxScreenTimeAppState extends State<LinuxScreenTimeApp> with WindowListener {
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Prevent the window from closing natively so we can hide it instead
    windowManager.setPreventClose(true); 
    _initSystemTray();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    // We point to a standard system icon fallback for local compilation
    // This will be mapped to our custom SVG once we package for Arch
    String iconPath = Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

    await _systemTray.initSystemTray(
      title: "Screen Time",
      iconPath: iconPath,
    );

    await _menu.buildFrom([
      MenuItemLabel(label: 'Open Dashboard', onClicked: (menuItem) => windowManager.show()),
      MenuItemLabel(label: 'Quit', onClicked: (menuItem) async {
        LinuxUsageTracker.instance.stopTracking();
        await windowManager.destroy();
      }),
    ]);

    await _systemTray.setContextMenu(_menu);

    // Toggle window visibility on tray click
    _systemTray.registerSystemTrayEventHandler((eventName) async {
      if (eventName == kSystemTrayEventClick) {
        bool isVisible = await windowManager.isVisible();
        if (isVisible) {
          await windowManager.hide();
        } else {
          await windowManager.show();
          await windowManager.setFocus();
        }
      }
    });
  }

  @override
  void onWindowClose() async {
    // Intercept standard window close behavior and hide to tray instead
    await windowManager.hide();
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