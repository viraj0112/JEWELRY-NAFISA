import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_dashboard_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_media_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_quotes_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_settings_screen.dart';
import 'package:jewelry_nafisa/src/admin/screens/admin_users_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  _AdminShellState createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  // ✨ UPDATED: Replaced placeholders with the new screens
  static const List<Widget> _widgetOptions = <Widget>[
    AdminDashboardScreen(),
    AdminUsersScreen(),
    AdminQuotesScreen(),
    AdminMediaScreen(),
    AdminSettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_outlined), activeIcon: Icon(Icons.people_alt), label: 'Users'),
          BottomNavigationBarItem(icon: Icon(Icons.request_quote_outlined), activeIcon: Icon(Icons.request_quote), label: 'Quotes'),
          BottomNavigationBarItem(icon: Icon(Icons.perm_media_outlined), activeIcon: Icon(Icons.perm_media), label: 'Media'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        showUnselectedLabels: true,
      ),
    );
  }
}