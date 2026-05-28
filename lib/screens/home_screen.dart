import 'package:flutter/material.dart';
import '../widgets/glass_container.dart';
import 'dashboard_screen.dart';
import 'apps_screen.dart';
import 'weekly_screen.dart';
import 'battery_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Ordered tabs pointing to our dedicated feature screens
  final List<Widget> _screens = const [
    DashboardScreen(),
    AppsScreen(),
    WeeklyScreen(),
    BatteryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background ambient gradient to accentuate the glass blur layers
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black, Color(0xFF1A0B2E), Color(0xFF0B162E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Main dynamic screen container area
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      
      // Fixed bottom custom navigation with embedded glassmorphism layout
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 16.0),
          child: GlassContainer(
            padding: EdgeInsets.zero,
            borderRadius: const BorderRadius.all(Radius.circular(24.0)),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.transparent, // Let GlassContainer handle background
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.purpleAccent,
              unselectedItemColor: Colors.white38,
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_rounded),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'Apps',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.date_range_rounded),
                  label: 'Weekly',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.battery_charging_full_rounded),
                  label: 'Battery',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}