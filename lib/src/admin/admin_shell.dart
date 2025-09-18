import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_dashboard_screen.dart';

// Placeholder screens for other menu items
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
    );
  }
}


class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const PlaceholderScreen(title: 'Product Upload'),
    const PlaceholderScreen(title: 'Analytics'),
    const PlaceholderScreen(title: 'Users Management'),
    const PlaceholderScreen(title: 'Quotes'),
    const PlaceholderScreen(title: 'Push Notifications'),
    const PlaceholderScreen(title: 'Auto Tagging Panel'),
  ];

  void _selectScreen(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          SideMenu(
            selectedIndex: _selectedIndex,
            onItemSelected: _selectScreen,
          ),
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

class SideMenu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const SideMenu({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFFFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'AKD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 28,
                color: Colors.brown[800],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildMenuItem(
                  context: context,
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  text: 'Dashboard',
                ),
                _buildMenuItem(
                  context: context,
                  index: 1,
                  icon: Icons.cloud_upload_outlined,
                  text: 'Product Upload',
                ),
                _buildMenuItem(
                  context: context,
                  index: 2,
                  icon: Icons.analytics_outlined,
                  text: 'Analytics',
                ),
                _buildMenuItem(
                  context: context,
                  index: 3,
                  icon: Icons.people_outline,
                  text: 'Users Management',
                ),
                _buildMenuItem(
                  context: context,
                  index: 4,
                  icon: Icons.format_quote_outlined,
                  text: 'Quotes',
                ),
                _buildMenuItem(
                  context: context,
                  index: 5,
                  icon: Icons.notifications_active_outlined,
                  text: 'Push Notifications',
                ),
                 _buildMenuItem(
                  context: context,
                  index: 6,
                  icon: Icons.sell_outlined,
                  text: 'Auto Tagging Panel',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildMenuItem(
            context: context,
            index: 7, // Logout index
            icon: Icons.logout,
            text: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String text,
  }) {
    final bool isSelected = selectedIndex == index;
    final color = isSelected ? const Color(0xFFC8A36A) : Colors.grey[600];
    final bgColor = isSelected ? const Color(0xFFF9F5EF) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: InkWell(
        onTap: () => onItemSelected(index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 16),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}