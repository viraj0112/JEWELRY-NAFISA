import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/constants/constant.dart';
import 'package:jewelry_nafisa/src/admin/models/menu_item.dart';
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/admin/widgets/filter_component.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

class _HoverableMenuItem extends StatefulWidget {
  final Widget child;
  final bool isSelected;
  const _HoverableMenuItem({required this.child, required this.isSelected});
  @override
  State<_HoverableMenuItem> createState() => _HoverableMenuItemState();
}

class _HoverableMenuItemState extends State<_HoverableMenuItem> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color backgroundColor;
    if (widget.isSelected) {
      backgroundColor = theme.primaryColor.withOpacity(0.1);
    } else if (_isHovered) {
      backgroundColor = theme.hoverColor;
    } else {
      backgroundColor = Colors.transparent;
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(_isHovered ? 5 : 0, 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: widget.child,
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  MenuItem _selectedMenuItem = menuItems.first;

  void _onMenuItemSelected(MenuItem item) {
    if (item.screen != null) {
      if (MediaQuery.of(context).size.width < 800 &&
          Navigator.canPop(context)) {
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

  // --- LAYOUTS ---
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedMenuItem.title),
        actions: [
          // Added Filter Button for Mobile
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AlertDialog(
                content: SizedBox(
                  width: 300,
                  child: FilterComponent(),
                ),
              ),
            ),
            tooltip: 'Filters',
          ),
          ..._buildAppBarActions(),
        ],
      ),
      drawer: Drawer(child: _buildSidePanel()),
      body: _buildPageContent(),
    );
  }

  Widget _buildDesktopLayout() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF161C24) : const Color(0xFFF9FAFB),
      body: Row(
        children: [
          SizedBox(width: 260, child: _buildSidePanel()),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                _buildAdminHeader(),
                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: FilterComponent(),
                ),
                Expanded(child: _buildPageContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildPageContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey<String>(_selectedMenuItem.title),
        child: _selectedMenuItem.screen,
      ),
    );
  }

  Widget _buildAdminHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      // FIX: Changed Wrap to Row and wrapped TextField in Expanded
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                filled: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _buildAppBarActions(),
          ),
        ],
      ),
    );
  }

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
      const SizedBox(width: 8),
    ];
  }

  Widget _buildAdminProfileMenu() {
    // Get the current user from Supabase
    final adminUser = Supabase.instance.client.auth.currentUser;

    return PopupMenuButton<String>(
      tooltip: 'Profile Menu',
      offset: const Offset(0, 50),
      onSelected: (value) {
        if (value == 'logout') {
          _signOut();
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: ListTile(
            leading: const CircleAvatar(child: Text('A')),
            title: const Text('Admin',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              // Use the user's email, or a fallback text if not available
              adminUser?.email ?? 'Not logged in',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Log out'),
          ),
        ),
      ],
      child: const CircleAvatar(
        child: Text('A', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSidePanel() {
    final theme = Theme.of(context);
    return Container(
      color: theme.cardColor,
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8.0),
              children:
                  menuItems.map((item) => _buildMenuList(item, theme)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond_outlined, size: 32),
              const SizedBox(width: 12),
              Text("JEWELRY", style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuList(MenuItem item, ThemeData theme) {
    final bool isSelected = _selectedMenuItem.title == item.title;
    final bool hasSubItems = item.subItems != null && item.subItems!.isNotEmpty;
    if (!hasSubItems) {
      return _HoverableMenuItem(
        isSelected: isSelected,
        child: ListTile(
          leading:
              Icon(item.icon, color: isSelected ? theme.primaryColor : null),
          title: Text(item.title,
              style: TextStyle(color: isSelected ? theme.primaryColor : null)),
          onTap: () => _onMenuItemSelected(item),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      bool isChildSelected =
          item.subItems!.any((sub) => sub.title == _selectedMenuItem.title);
      return _HoverableMenuItem(
        isSelected: isChildSelected,
        child: ExpansionTile(
          leading: Icon(item.icon,
              color: isChildSelected ? theme.primaryColor : null),
          title: Text(item.title,
              style: TextStyle(
                  color: isChildSelected ? theme.primaryColor : null)),
          initiallyExpanded: isChildSelected,
          childrenPadding: const EdgeInsets.only(left: 20.0),
          children: item.subItems!.map((subItem) {
            final bool isSubItemSelected =
                _selectedMenuItem.title == subItem.title;
            return _HoverableMenuItem(
              isSelected: isSubItemSelected,
              child: ListTile(
                title: Text(subItem.title,
                    style: TextStyle(
                        color: isSubItemSelected ? theme.primaryColor : null)),
                leading: Icon(subItem.icon,
                    size: 20,
                    color: isSubItemSelected ? theme.primaryColor : null),
                onTap: () => _onMenuItemSelected(subItem),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            );
          }).toList(),
        ),
      );
    }
  }
}