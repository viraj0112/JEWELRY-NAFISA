import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/designer/screens/analytics_screen.dart';
import 'package:jewelry_nafisa/src/designer/screens/b2b_upload_screen.dart'; 
import 'package:jewelry_nafisa/src/designer/screens/manage_uploads_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';

class DesignerShell extends StatefulWidget {
  const DesignerShell({super.key});

  @override
  State<DesignerShell> createState() => _DesignerShellState();
}

class _DesignerShellState extends State<DesignerShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const B2BProductUploadScreen(), 
    const ManageUploadsScreen(),
    const AnalyticsScreen(),
  ];

  Future<void> _signOut() async {
    await SupabaseAuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Designer Workspace"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: "Log Out",
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.upload_file_outlined),
                selectedIcon: Icon(Icons.upload_file),
                label: Text('Upload'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.collections_outlined),
                selectedIcon: Icon(Icons.collections),
                label: Text('Manage'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Analytics'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}