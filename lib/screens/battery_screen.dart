import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/glass_container.dart';

class BatteryScreen extends StatefulWidget {
  const BatteryScreen({super.key});

  @override
  State<BatteryScreen> createState() => _BatteryScreenState();
}

class _BatteryScreenState extends State<BatteryScreen> {
  Timer? _batteryTimer;
  int _batteryPercentage = 100;
  String _chargingStatus = "Unknown";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _readLinuxBatteryState();
    // Poll the kernel hardware state files every 10 seconds for real-time updates
    _batteryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _readLinuxBatteryState();
    });
  }

  @override
  void dispose() {
    _batteryTimer?.cancel();
    super.dispose();
  }

  Future<void> _readLinuxBatteryState() async {
    try {
      int capacity = 100;
      String status = "Discharging";

      // 1. Read battery capacity file safely
      final capacityFile = File('/sys/class/power_supply/BAT0/capacity');
      if (await capacityFile.exists()) {
        final capacityRaw = await capacityFile.readAsString();
        capacity = int.tryParse(capacityRaw.trim()) ?? 100;
      }

      // 2. Read battery charging status file safely
      final statusFile = File('/sys/class/power_supply/BAT0/status');
      if (await statusFile.exists()) {
        final statusRaw = await statusFile.readAsString();
        status = statusRaw.trim(); // Returns "Charging", "Discharging", "Full"
      }

      if (mounted) {
        setState(() {
          _batteryPercentage = capacity;
          _chargingStatus = status;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error reading Linux hardware state: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  IconData _getBatteryIcon(int percentage, String status) {
    if (status == "Charging") return Icons.battery_charging_full_rounded;
    if (percentage <= 15) return Icons.battery_alert_rounded;
    if (percentage <= 30) return Icons.battery_3_bar_rounded;
    if (percentage <= 70) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  Color _getBatteryColor(int percentage, String status) {
    if (status == "Charging") return Colors.greenAccent;
    if (percentage <= 15) return Colors.redAccent;
    if (percentage <= 30) return Colors.orangeAccent;
    return Colors.purpleAccent;
  }

  @override
  Widget build(BuildContext context) {
    final stateColor = _getBatteryColor(_batteryPercentage, _chargingStatus);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text(
                  'Power Diagnostics',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),

                // Main Glassmorphic Battery Gauge Card
                GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(36.0),
                  child: Column(
                    centerSpace: false,
                    children: [
                      Icon(
                        _getBatteryIcon(_batteryPercentage, _chargingStatus),
                        size: 80,
                        color: stateColor,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "$_batteryPercentage%",
                        style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: stateColor.withOpacity(0.12),
                          borderRadius: const BorderRadius.all(Radius.circular(20)),
                          border: Border.all(color: stateColor.withOpacity(0.3), width: 1),
                        ),
                        child: Text(
                          _chargingStatus.toUpperCase(),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stateColor, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Hardware System Reference Card
                GlassContainer(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.white38),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          "Reading sysfs operational nodes directly from /sys/class/power_supply/BAT0/",
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}