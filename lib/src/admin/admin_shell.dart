import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/constants/constant.dart';
import 'package:jewelry_nafisa/src/admin/models/menu_item.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:provider/provider.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  MenuItem _selectedMenuItem = menuItems.first;
  bool _isExpanded = false;

  void _onMenuItemSelected(MenuItem item) {
    if (item.screen != null) {
      // Close the drawer if on mobile and an item is selected
      if (MediaQuery.of(context).size.width < 800) {
        Navigator.of(context).pop();
      }
      setState(() {
        _selectedMenuItem = item;
      });
    }
  }

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;
        return isMobile ? _buildMobileLayout() : _buildDesktopLayout();
      },
    );
  }

  // --- Layouts ---

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedMenuItem.title),
        actions: _buildAppBarActions(), // Actions added here for mobile
      ),
      drawer: Drawer(
        child: _buildSidePanel(isMobile: true),
      ),
      body:
          _selectedMenuItem.screen ??
          const Center(child: Text('Select a screen')),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _isExpanded = true),
            onExit: (_) => setState(() => _isExpanded = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: _isExpanded ? 260 : 80,
              curve: Curves.easeOut,
              child: _buildSidePanel(isMobile: false),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                _buildAdminAppBar(),
                Expanded(
                  child: _selectedMenuItem.screen ??
                      const Center(child: Text('Select a screen')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---

  Widget _buildAdminAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          Text(
            _selectedMenuItem.title,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const Spacer(),
          ..._buildAppBarActions(), // Using the shared actions
        ],
      ),
    );
  }

  // This new method creates the action buttons to be shared by both layouts
  List<Widget> _buildAppBarActions() {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return [
      IconButton(
        icon: Icon(
          themeProvider.themeMode == ThemeMode.light
              ? Icons.dark_mode_outlined
              : Icons.light_mode_outlined,
        ),
        onPressed: () => themeProvider.toggleTheme(),
        tooltip: 'Toggle Theme',
      ),
      const SizedBox(width: 8),
      _buildAdminProfileMenu(),
      const SizedBox(width: 8), // Add some padding to the edge
    ];
  }

  Widget _buildAdminProfileMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Profile Menu',
      offset: const Offset(0, 50),
      onSelected: (value) {
        if (value == 'logout') {
          _signOut();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            leading: CircleAvatar(child: Text('A')),
            title: Text('Admin', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('admin@jewelrynafisa.com'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Text('Log out'),
        ),
      ],
      child: const CircleAvatar(
        child: Text('A', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSidePanel({required bool isMobile}) {
    final bool isPanelExpanded = isMobile || _isExpanded;
    final theme = Theme.of(context);

    return Container(
      color: theme.cardColor,
      child: Column(
        children: [
          _buildHeader(isPanelExpanded),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              children: menuItems
                  .map((item) => _buildMenuList(item, isPanelExpanded))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isExpanded) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 120,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: isExpanded
              ? _buildExpandedHeader(theme)
              : _buildCollapsedHeader(theme),
        ),
      ),
    );
  }

  Widget _buildCollapsedHeader(ThemeData theme) {
    return CircleAvatar(
      key: const ValueKey('collapsed_header'),
      backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
      child: Text(
        'A',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildExpandedHeader(ThemeData theme) {
    return Padding(
      key: const ValueKey('expanded_header'),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            child: Text(
              'A',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  'admin@jewelrynafisa.com',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList(MenuItem item, bool isExpanded) {
    final bool isSelected = _selectedMenuItem.title == item.title;
    final theme = Theme.of(context);

    if (!isExpanded) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Tooltip(
          message: item.title,
          child: Material(
            color: isSelected
                ? theme.colorScheme.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => _onMenuItemSelected(item),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(
                  item.icon,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.iconTheme.color,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (item.subItems == null || item.subItems!.isEmpty) {
      return ListTile(
        leading: Icon(item.icon),
        title: Text(item.title),
        onTap: () => _onMenuItemSelected(item),
        selected: isSelected,
        selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
        selectedColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );
    } else {
      return ExpansionTile(
        leading: Icon(item.icon),
        title: Text(item.title),
        initiallyExpanded: isSelected,
        childrenPadding: const EdgeInsets.only(left: 20.0),
        children: item.subItems!
            .map(
              (subItem) => ListTile(
                title: Text(subItem.title),
                leading: Icon(subItem.icon, size: 20),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${subItem.title} clicked')),
                  );
                },
              ),
            )
            .toList(),
      );
    }
  }
}