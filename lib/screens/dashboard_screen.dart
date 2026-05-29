import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/usage_db.dart';
import '../providers/linux_usage_tracker.dart';
import '../utils/icon_manager.dart';
import '../widgets/glass_container.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _totalMinutesToday = 0;
  List<Map<String, dynamic>> _topAppsGrid = [];
  int _uniqueAppsCount = 0;
  bool _isLoading = true;

  // Change this string to whatever app process you want permanently tracked
  final String _pinnedTargetApp = "zen-browser";
  int _pinnedAppMinutes = 0;

  // System dynamic infrastructure variables
  late Timer _clockTimer;
  String _timeString = "";
  String _dateString = "";

  final String _batteryName = "BAT0";
  double _batteryLevel = 1.0;
  bool _isCharging = false;
  late Timer _hardwarePollingTimer;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _updateTime();
    _clockTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _updateNativeLinuxBatteryState();
    _hardwarePollingTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) {
      _updateNativeLinuxBatteryState();
    });

    _loadDashboardStats();
    LinuxUsageTracker.instance.addListener(_loadDashboardStats);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _hardwarePollingTimer.cancel();
    _waveController.dispose();
    LinuxUsageTracker.instance.removeListener(_loadDashboardStats);
    super.dispose();
  }

  void _updateTime() {
    final DateTime now = DateTime.now();
    if (mounted) {
      setState(() {
        _timeString = DateFormat('hh:mm:ss a').format(now);
        _dateString = DateFormat('EEEE, MMMM dd').format(now);
      });
    }
  }

  Future<void> _updateNativeLinuxBatteryState() async {
    try {
      final ProcessResult statusResult = await Process.run(
          'cat', ['/sys/class/power_supply/$_batteryName/status']);
      final ProcessResult capacityResult = await Process.run(
          'cat', ['/sys/class/power_supply/$_batteryName/capacity']);

      if (statusResult.exitCode == 0 && capacityResult.exitCode == 0) {
        final String rawStatus =
            statusResult.stdout.toString().trim().toLowerCase();
        final int? rawCapacity =
            int.tryParse(capacityResult.stdout.toString().trim());

        if (mounted && rawCapacity != null) {
          setState(() {
            _batteryLevel = rawCapacity / 100.0;
            _isCharging = (rawStatus == "charging" || rawStatus == "full");
          });
        }
      }
    } catch (e) {
      debugPrint("Unable to map Linux physical battery rails: $e");
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final int totalToday =
          await UsageDatabase.instance.getTotalMinutesToday();
      final List<Map<String, dynamic>> dailyApps =
          await UsageDatabase.instance.getTodayUsage();

      // Extract specific tracking metrics for our pinned application choice
      int pinnedMinutes = 0;
      try {
        final matchingRow = dailyApps.firstWhere((element) =>
            (element['appName'] ?? '').toString().toLowerCase() ==
            _pinnedTargetApp.toLowerCase());
        pinnedMinutes = (matchingRow['durationMinutes'] as num).toInt();
      } catch (_) {
        pinnedMinutes = 0; // App hasn't logged minutes yet today
      }

      if (mounted) {
        setState(() {
          _totalMinutesToday = totalToday;
          _topAppsGrid =
              dailyApps.take(4).toList(); // Constrain matrix strictly to 4 apps
          _pinnedAppMinutes = pinnedMinutes;
          _uniqueAppsCount = dailyApps.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard statistics: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                // ================= TOP STATUS HUB ROW =================
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _timeString,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.purpleAccent,
                                fontFamily: 'monospace',
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _dateString,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white38,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: GlassContainer(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14.0, vertical: 12.0),
                        child: Row(
                          children: [
                            AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(26, 46),
                                  painter: BatteryPainter(
                                    level: _batteryLevel,
                                    isCharging: _isCharging,
                                    waveValue: _waveController.value,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "${(_batteryLevel * 100).toInt()}%",
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white),
                                  ),
                                  Text(
                                    _isCharging ? "⚡ Charging" : "Discharging",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _isCharging
                                            ? Colors.greenAccent
                                            : Colors.blueAccent),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ================= NEW: 4 MOST USED APPS MATRIX GRID =================
                const Text(
                  'Primary Workspaces (Top 4)',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                _topAppsGrid.isEmpty
                    ? const GlassContainer(
                        width: double.infinity,
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                            child: Text("No app usage tracked yet.",
                                style: TextStyle(color: Colors.white38))),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _topAppsGrid.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.1,
                        ),
                        itemBuilder: (context, index) {
                          final item = _topAppsGrid[index];
                          final String appName = item['appName'] ?? 'Unknown';
                          final int minutes =
                              (item['durationMinutes'] as num).toInt();

                          return GlassContainer(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14.0, vertical: 10.0),
                            child: Row(
                              children: [
                                IconManager.getAppIcon(appName, size: 28.0),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        appName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text("$minutes mins",
                                          style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 24),

                // ================= RETAINED & CONVERTED: PINNED APP MONITOR =================
                const Text(
                  'Pinned Target Application Monitor',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white38,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 10),
                GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: IconManager.getAppIcon(_pinnedTargetApp,
                            size: 32.0),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pinnedTargetApp.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Session standard runtime: $_pinnedAppMinutes minutes logged",
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.push_pin_rounded,
                          size: 18, color: Colors.blueAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ================= DOUBLE MATRIX QUICK CARDS =================
                Row(
                  children: [
                    Expanded(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.hourglass_empty_rounded,
                                    size: 16, color: Colors.blueAccent),
                                SizedBox(width: 6),
                                Text("SCREEN TIME",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white38)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "${_totalMinutesToday ~/ 60}h ${_totalMinutesToday % 60}m",
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            const Text("Tracked accumulation",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white38)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassContainer(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.waves_rounded,
                                    size: 16, color: Colors.orangeAccent),
                                SizedBox(width: 6),
                                Text("VELOCITY",
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white38)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "$_uniqueAppsCount Apps",
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            const Text("Monitored workspaces",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white38)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class BatteryPainter extends CustomPainter {
  final double level;
  final bool isCharging;
  final double waveValue;

  BatteryPainter(
      {required this.level, required this.isCharging, required this.waveValue});

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final Paint outlinePaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;

    if (isCharging) {
      fillPaint.color = Colors.greenAccent.withOpacity(0.85);
    } else if (level <= 0.20) {
      fillPaint.color = Colors.redAccent.withOpacity(0.85);
    } else {
      fillPaint.color = Colors.blueAccent.withOpacity(0.85);
    }

    final RRect tip = RRect.fromRectAndRadius(
      Rect.fromLTWH(width * 0.35, 0, width * 0.3, height * 0.06),
      const Radius.circular(2),
    );
    canvas.drawRRect(
        tip,
        outlinePaint
          ..style = PaintingStyle.fill
          ..color = Colors.white38);

    final RRect bodyOutline = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, height * 0.08, width, height * 0.92),
      const Radius.circular(6),
    );
    canvas.drawRRect(
        bodyOutline,
        outlinePaint
          ..style = PaintingStyle.stroke
          ..color = Colors.white24);

    canvas.save();
    final Path clipPath = Path()..addRRect(bodyOutline);
    canvas.clipPath(clipPath);

    final double fillHeight = (height * 0.92) * level;
    final double topY = (height * 1.0) - fillHeight;

    if (isCharging) {
      final Path wavePath = Path();
      wavePath.moveTo(0, topY);

      for (double x = 0; x <= width; x++) {
        final double y = topY +
            math.sin((x / width * 2 * math.pi) + (waveValue * 2 * math.pi)) *
                2.5;
        wavePath.lineTo(x, y);
      }

      wavePath.lineTo(width, height);
      wavePath.lineTo(0, height);
      wavePath.close();
      canvas.drawPath(wavePath, fillPaint);
    } else {
      final Rect fillRect = Rect.fromLTWH(0, topY, width, fillHeight);
      canvas.drawRect(fillRect, fillPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BatteryPainter oldDelegate) => true;
}
