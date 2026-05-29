import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../database/usage_db.dart';
import '../providers/linux_usage_tracker.dart';
import '../utils/icon_manager.dart';
import '../utils/system_controller.dart';
import '../widgets/glass_container.dart';

class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key});

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  Map<String, int> _weeklyAggregatedData = {};
  List<double> _dailyUsageMinutes = List.filled(7, 0.0);
  List<double> _hourlyDistribution = List.filled(24, 0.0);
  List<String> _weekDayLabels = List.filled(7, '');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeeklyAnalytics();
    LinuxUsageTracker.instance.addListener(_loadWeeklyAnalytics);
  }

  @override
  void dispose() {
    LinuxUsageTracker.instance.removeListener(_loadWeeklyAnalytics);
    super.dispose();
  }

  Future<void> _loadWeeklyAnalytics() async {
    final data = await UsageDatabase.instance.getLast7DaysUsage();
    final Map<String, int> applicationAggregates = {};
    final List<double> hourlyBuckets = List.filled(24, 0.0);
    final List<DateTime> targetDates = List.generate(
        7, (index) => DateTime.now().subtract(Duration(days: 6 - index)));
    final List<double> dayMinutes = List.filled(7, 0.0);

    for (var row in data) {
      final String appName = row['appName'] ?? 'Unknown';
      final int minutes = (row['durationMinutes'] as num).toInt();
      applicationAggregates[appName] =
          (applicationAggregates[appName] ?? 0) + minutes;

      final dynamic ts = row['createdAt'] ?? row['timestamp'];
      DateTime rowDate = ts != null
          ? DateTime.parse(ts.toString().split(' ').first)
          : DateTime.now();

      if (rowDate.hour >= 0 && rowDate.hour < 24) {
        hourlyBuckets[rowDate.hour] =
            (hourlyBuckets[rowDate.hour] + (minutes / 60.0)).clamp(0, 5);
      }
      for (int i = 0; i < 7; i++) {
        if (rowDate.year == targetDates[i].year &&
            rowDate.month == targetDates[i].month &&
            rowDate.day == targetDates[i].day) {
          dayMinutes[i] += minutes.toDouble();
        }
      }
    }

    if (mounted) {
      setState(() {
        _weeklyAggregatedData = Map.fromEntries(
            applicationAggregates.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)));
        _dailyUsageMinutes = dayMinutes;
        _hourlyDistribution = hourlyBuckets;
        _weekDayLabels =
            targetDates.map((d) => DateFormat('E').format(d)).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxVal = _dailyUsageMinutes.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 60; // Prevent division by zero/empty chart

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text('7-Day Analysis',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),

                // Unified 7-Day Chart
                GlassContainer(
                  height: 220,
                  padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                  child: BarChart(BarChartData(
                    maxY: maxVal + 60,
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (v, m) => Text(
                                  "${(v / 60).toInt()}h",
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 10)))),
                      bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, m) => Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(_weekDayLabels[v.toInt()],
                                      style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11))))),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: List.generate(
                        7,
                        (i) => BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                  toY: _dailyUsageMinutes[i],
                                  width: 16,
                                  gradient: const LinearGradient(colors: [
                                    Colors.blueAccent,
                                    Colors.purpleAccent
                                  ]))
                            ])),
                  )),
                ),

                const SizedBox(height: 24),
                const Text('Daily Intensity (24h Map)',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Intensity Heatmap
                GlassContainer(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(
                          24,
                          (h) => Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent.withOpacity(
                                      (_hourlyDistribution[h] * 0.5)
                                          .clamp(0.2, 1.0)),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              )),
                    )),

                const SizedBox(height: 24),
                const Text('Application Breakdown',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),

                // Breakdown List with Swipe-to-Kill
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _weeklyAggregatedData.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final String appName =
                        _weeklyAggregatedData.keys.elementAt(index);
                    return Dismissible(
                      key: Key(appName),
                      background: Container(
                          color: Colors.red.withOpacity(0.3),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.close)),
                      onDismissed: (_) => SystemController.killProcess(appName),
                      child: GlassContainer(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              IconManager.getAppIcon(appName),
                              const SizedBox(width: 14),
                              Text(appName,
                                  style: const TextStyle(color: Colors.white))
                            ],
                          )),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
