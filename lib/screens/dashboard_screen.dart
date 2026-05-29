import 'dart:async';
import 'package:flutter/material.dart';
import '../database/usage_db.dart';
import '../widgets/glass_container.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;
  int _totalMinutesToday = 0;
  List<Map<String, dynamic>> _todayUsageList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
    // Auto-refresh data arrays every 30 seconds to track background usage live
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    try {
      final now = DateTime.now();
      final data = await UsageDatabase.instance.getUsageByDate(now);

      int combinedMinutes = 0;
      for (var row in data) {
        combinedMinutes += (row['durationMinutes'] as num).toInt();
      }

      if (mounted) {
        setState(() {
          _todayUsageList = data;
          _totalMinutesToday = combinedMinutes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching dashboard statistics: $e");
    }
  }

  // Unified formatting logic for both hero totals and app items
  String _formatHoursAndMinutes(int totalMinutes) {
    if (totalMinutes < 0) return "0m";
    if (totalMinutes < 60) return "${totalMinutes}m";

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    return minutes == 0 ? "${hours}h" : "${hours}h ${minutes}m";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Inherit ambient home background
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 20),

                // Hero Screen Time Metric Card
                GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "TOTAL SCREEN TIME TODAY",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white38,
                            letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _formatHoursAndMinutes(_totalMinutesToday),
                        style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Most Used Apps',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70),
                ),
                const SizedBox(height: 16),

                // Live Tracked System Process Application Feed
                _todayUsageList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            "No application logs recorded yet today.",
                            style: TextStyle(color: Colors.white30),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _todayUsageList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final row = _todayUsageList[index];
                          final String appName =
                              row['appName'] ?? 'Unknown Process';
                          final int minutes =
                              (row['durationMinutes'] as num).toInt();

                          return GlassContainer(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20.0, vertical: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor:
                                          Colors.purple.withOpacity(0.2),
                                      child: const Icon(
                                          Icons.star_border_rounded,
                                          color: Colors.purpleAccent,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      appName,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white),
                                    ),
                                  ],
                                ),
                                Text(
                                  _formatHoursAndMinutes(minutes),
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.purpleAccent),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ],
            ),
    );
  }
}
