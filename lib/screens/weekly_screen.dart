import 'package:flutter/material.dart';
import '../database/usage_db.dart';
import '../widgets/glass_container.dart';

class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key});

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  Map<String, int> _weeklyAggregatedData = {};
  double _totalWeeklyHours = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyAnalytics();
  }

  Future<void> _loadWeeklyAnalytics() async {
    try {
      final data = await UsageDatabase.instance.getLast7DaysUsage();
      final Map<String, int> applicationAggregates = {};
      int totalMinutesAccumulated = 0;

      // Group and sum minutes across identical application class names
      for (var row in data) {
        final String appName = row['appName'] ?? 'Unknown Process';
        final int minutes = (row['durationMinutes'] as num).toInt();

        applicationAggregates[appName] = (applicationAggregates[appName] ?? 0) + minutes;
        totalMinutesAccumulated += minutes;
      }

      // Sort aggregated list from highest usage to lowest
      final sortedAggregates = Map.fromEntries(
        applicationAggregates.entries.toList()..sort((a, b) => b.value.compareTo(a.value))
      );

      if (mounted) {
        setState(() {
          _weeklyAggregatedData = sortedAggregates;
          _totalWeeklyHours = totalMinutesAccumulated / 60.0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading weekly metrics: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text(
                  '7-Day Analysis',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),

                // Weekly Summary Card
                GlassContainer(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.blueAccent.withOpacity(0.15),
                        child: const Icon(Icons.date_range_rounded, color: Colors.blueAccent, size: 28),
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "TOTAL TIME THIS WEEK",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 1),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${_totalWeeklyHours.toStringAsFixed(1)} hours",
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Application Breakdown',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(height: 16),

                _weeklyAggregatedData.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 40.0),
                        child: Center(child: Text("No rolling historical logs found.", style: TextStyle(color: Colors.white24))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _weeklyAggregatedData.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final String appName = _weeklyAggregatedData.keys.elementAt(index);
                          final int totalMinutes = _weeklyAggregatedData[appName]!;
                          final double hoursSpent = totalMinutes / 60.0;

                          return GlassContainer(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.between,
                              children: [
                                Text(
                                  appName,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                                Text(
                                  "${hoursSpent.toStringAsFixed(1)}h",
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blueAccent),
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