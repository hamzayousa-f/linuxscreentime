import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/usage_db.dart';
import '../providers/linux_usage_tracker.dart';
import '../utils/icon_manager.dart';
import '../utils/system_controller.dart';
import '../widgets/glass_container.dart';

class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key});

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<Map<String, dynamic>> _todayData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    LinuxUsageTracker.instance.addListener(_loadData);
  }

  @override
  void dispose() {
    LinuxUsageTracker.instance.removeListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    final data = await UsageDatabase.instance.getUsageByDate(DateTime.now());
    // Sort by duration descending to keep the chart clean
    final sortedData = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) =>
          (b['durationMinutes'] as num).compareTo(a['durationMinutes'] as num));

    if (mounted) {
      setState(() {
        _todayData = sortedData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show top 5 apps on the chart to keep labels readable
    final chartData = _todayData.take(5).toList();
    double maxVal = chartData.isEmpty
        ? 60
        : chartData
            .map((e) => (e['durationMinutes'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);
    if (maxVal < 60) maxVal = 60;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text('Today\'s Apps',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 20),
                GlassContainer(
                  height: 280,
                  padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                  child: BarChart(BarChartData(
                    maxY: maxVal + 30,
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
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index >= 0 && index < chartData.length) {
                                  String name =
                                      chartData[index]['appName'] ?? '';
                                  // Truncate name for readability
                                  if (name.length > 8)
                                    name = "${name.substring(0, 6)}..";
                                  return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(name,
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 10)));
                                }
                                return const SizedBox();
                              })),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    barGroups: List.generate(
                        chartData.length,
                        (i) => BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                  toY: (chartData[i]['durationMinutes'] as num)
                                      .toDouble(),
                                  width: 16,
                                  gradient: const LinearGradient(colors: [
                                    Colors.purpleAccent,
                                    Colors.blueAccent
                                  ]))
                            ])),
                  )),
                ),
                const SizedBox(height: 24),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _todayData.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final row = _todayData[index];
                    final String appName = row['appName'] ?? 'Unknown';
                    final int minutes = (row['durationMinutes'] as num).toInt();

                    return Dismissible(
                      key: Key(appName + index.toString()),
                      background: Container(
                          decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white)),
                      onDismissed: (direction) async {
                        await SystemController.killProcess(appName);
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Terminated $appName")));
                      },
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(children: [
                              IconManager.getAppIcon(appName, size: 24.0),
                              const SizedBox(width: 14),
                              Text(appName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white))
                            ]),
                            Text("$minutes mins",
                                style: const TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}
