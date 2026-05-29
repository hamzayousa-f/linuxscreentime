import 'dart:io';
import 'package:flutter/foundation.dart';
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
  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    // In Debug Mode under Wayland/Hyprland, prevent close intercepting
    // so standard exit handlers work flawlessly without tray dependency.
    if (kDebugMode) {
      windowManager.setPreventClose(false);
      debugPrint(
          "Running in Debug Mode: Skipping native system tray to prevent Wayland crashes.");
    } else {
      windowManager.setPreventClose(true);
      _initSystemTray();
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _initSystemTray() async {
    String iconPath =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

    if (Platform.isLinux &&
        !Platform.executable.contains('.exe') &&
        !Platform.executable.contains('bundle')) {
      iconPath = '${Directory.current.path}/assets/app_icon.png';
    }

    try {
      await _systemTray.initSystemTray(
        title: "Screen Time",
        iconPath: iconPath,
      );

      await _menu.buildFrom([
        MenuItemLabel(
          label: 'Open Dashboard',
          onClicked: (menuItem) async {
            await windowManager.show();
            await windowManager.focus();
          },
        ),
        MenuItemLabel(
          label: 'Quit',
          onClicked: (menuItem) async {
            LinuxUsageTracker.instance.stopTracking();
            await windowManager.setPreventClose(false);
            await windowManager.close();
          },
        ),
      ]);

      await _systemTray.setContextMenu(_menu);

      _systemTray.registerSystemTrayEventHandler((eventName) async {
        if (eventName == kSystemTrayEventClick) {
          bool isVisible = await windowManager.isVisible();
          if (isVisible) {
            await windowManager.hide();
          } else {
            await windowManager.show();
            await windowManager.focus();
          }
        }
      });
    } catch (e) {
      debugPrint("Handled native system tray initialization fallback: $e");
    }
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      await windowManager.hide();
    }
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
