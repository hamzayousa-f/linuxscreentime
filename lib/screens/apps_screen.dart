import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../database/usage_db.dart';
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
  }

  Future<void> _loadData() async {
    final data = await UsageDatabase.instance.getUsageByDate(DateTime.now());
    if (mounted) {
      setState(() {
        _todayData = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only chart the top 5 applications to keep the visual spacing clean
    final chartData = _todayData.take(5).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                const Text(
                  'Today\'s Apps',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),

                // Analytical Bar Chart Section
                if (chartData.isNotEmpty)
                  GlassContainer(
                    height: 250,
                    width: double.infinity,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: chartData.isEmpty 
                            ? 60 
                            : (chartData.map((e) => (e['durationMinutes'] as num).toDouble()).reduce((a, b) => a > b ? a : b) + 10),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.black.withOpacity(0.8),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                "${chartData[groupIndex]['appName']}\n${rod.toY.toInt()}m",
                                const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index >= 0 && index < chartData.length) {
                                  String name = chartData[index]['appName'] ?? '';
                                  // Truncate overly long system application process tags
                                  if (name.length > 8) name = "${name.substring(0, 6)}..";
                                  return Padding(
                                    padding: const EdgeInsets.top(8.0),
                                    child: Text(name, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                                  );
                                }
                                return const Text('');
                              },
                              reservedSize: 30,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text("${value.toInt()}m", style: const TextStyle(color: Colors.white30, fontSize: 10));
                              },
                              reservedSize: 30,
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: const FlGridData(show: false),
                        barGroups: List.generate(chartData.length, (index) {
                          final int minutes = (chartData[index]['durationMinutes'] as num).toInt();
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: minutes.toDouble(),
                                gradient: const LinearGradient(
                                  colors: [Colors.purpleAccent, Colors.blueAccent],
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                width: 18,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(6),
                                  topRight: Radius.circular(6),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                const SizedBox(height: 28),

                // Text List Breakdown Section
                const Text(
                  'Detailed View',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(height: 16),

                _todayData.isEmpty
                    ? const Center(child: Padding(
                        padding: EdgeInsets.only(top: 32.0),
                        child: Text("No detailed stats available yet.", style: TextStyle(color: Colors.white24)),
                      ))
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _todayData.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final row = _todayData[index];
                          final String appName = row['appName'] ?? 'Unknown App';
                          final int minutes = (row['durationMinutes'] as num).toInt();

                          return GlassContainer(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.between,
                              children: [
                                Text(appName, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                                Text("${minutes} minutes", style: const TextStyle(color: Colors.white60)),
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