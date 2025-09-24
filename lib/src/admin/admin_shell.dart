import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_dashboard_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_users_screen.dart';
import 'package:jewelry_nafisa/src/auth/auth_gate.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const Center(child: Text("Product Upload")), // Placeholder
    const Center(child: Text("Analytics")), // Placeholder
    const AdminUsersScreen(),
    const Center(child: Text("Quotes")), // Placeholder
    const Center(child: Text("Push Notifications")), // Placeholder
    const Center(child: Text("Auto Tagging")), // Placeholder
  ];

  void _selectScreen(int index) {
    if (index == 7) {
      _signOut();
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
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
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      title: SizedBox(
        height: 40,
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search something...',
            prefixIcon: const Icon(Icons.search, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          onPressed: () => themeProvider.toggleTheme(),
          tooltip: 'Toggle Theme',
        ),
        IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        IconButton(
          icon: const Icon(Icons.notifications_none_outlined),
          onPressed: () {},
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: CircleAvatar(
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=3'),
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    return Container(
      width: 250,
      color: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'AKD',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildMenuItem(
                  context,
                  0,
                  Icons.dashboard_outlined,
                  'Dashboard',
                ),
                _buildMenuItem(
                  context,
                  1,
                  Icons.cloud_upload_outlined,
                  'Product Upload',
                ),
                _buildMenuItem(
                  context,
                  2,
                  Icons.analytics_outlined,
                  'Analytics',
                ),
                _buildMenuItem(
                  context,
                  3,
                  Icons.people_outline,
                  'Users Management',
                ),
                _buildMenuItem(
                  context,
                  4,
                  Icons.format_quote_outlined,
                  'Quotes',
                ),
                _buildMenuItem(
                  context,
                  5,
                  Icons.notifications_active_outlined,
                  'Push Notifications',
                ),
                _buildMenuItem(
                  context,
                  6,
                  Icons.sell_outlined,
                  'Auto Tagging Panel',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildMenuItem(context, 7, Icons.logout, 'Logout'),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    int index,
    IconData icon,
    String text,
  ) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);
    final color = isSelected ? theme.colorScheme.primary : Colors.grey[600];
    final bgColor = isSelected
        ? theme.colorScheme.primary.withOpacity(0.1)
        : Colors.transparent;

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
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
