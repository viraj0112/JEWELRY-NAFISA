import "dart:ui";
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/ui/theme/app_theme.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final List<MenuItem>? subItems;

  MenuItem({required this.title, required this.icon, this.subItems});
}

final List<MenuItem> menuItems = [
  MenuItem(title: 'Dashboard', icon: Icons.dashboard_outlined),
  MenuItem(
    title: 'Analytics',
    icon: Icons.analytics_outlined,
    subItems: [
      MenuItem(title: 'Post Analytics', icon: Icons.remove_red_eye_outlined),
      MenuItem(title: 'Members Behavior', icon: Icons.auto_graph),
      MenuItem(title: 'Credit System', icon: Icons.credit_score),
      MenuItem(title: 'Referral Tracking', icon: Icons.trending_up_sharp),
      MenuItem(title: 'Search & Filters', icon: Icons.search_outlined),
      MenuItem(title: 'Geo Analytics', icon: Icons.map_outlined),
    ],
  ),
  MenuItem(
    title: 'Users',
    icon: Icons.people_outline,
    subItems: [
      MenuItem(title: 'Members', icon: Icons.person_add_outlined),
      MenuItem(title: 'Non-Members', icon: Icons.person_add_disabled_outlined),
      MenuItem(title: 'Referrals', icon: Icons.share_outlined),
    ],
  ),
  MenuItem(
    title: 'B2B Creators',
    icon: Icons.palette_outlined,
    subItems: [
      MenuItem(title: '3D Artists', icon: Icons.palette_outlined),
      MenuItem(title: 'Sketch Designers', icon: Icons.brush_outlined),
      MenuItem(title: 'Uploads', icon: Icons.file_upload_outlined),
    ],
  ),
  MenuItem(
    title: 'Notifications',
    icon: Icons.message_outlined,
    subItems: [
      MenuItem(title: 'Admin Notifications', icon: Icons.shield_outlined),
      MenuItem(title: 'User Notifications', icon: Icons.person_outline_rounded),
      MenuItem(title: 'Alerts', icon: Icons.add_alert_sharp),
    ],
  ),
  MenuItem(
    title: 'Reports',
    icon: Icons.add_chart,
    subItems: [
      MenuItem(title: 'Platform Reports', icon: Icons.bar_chart),
      MenuItem(title: 'User Reports', icon: Icons.stacked_line_chart),
      MenuItem(title: 'Content Reports', icon: Icons.person_pin_outlined),
      MenuItem(title: 'Revenue Reports', icon: Icons.monetization_on_outlined),
    ],
  ),
  MenuItem(
    title: 'Activity Logs',
    icon: Icons.settings_backup_restore_outlined,
    subItems: [
      MenuItem(title: 'Admin Logs', icon: Icons.admin_panel_settings_outlined),
      MenuItem(title: 'User Logs', icon: Icons.supervised_user_circle_outlined),
      MenuItem(title: 'Export Logs', icon: Icons.download_outlined),
    ],
  ),
  MenuItem(title: 'Emails', icon: Icons.email_outlined),
  MenuItem(
    title: 'Settings',
    icon: Icons.settings,
    subItems: [
      MenuItem(title: 'User Roles & Permissions', icon: Icons.shield_outlined),
      MenuItem(title: 'Webhooks', icon: Icons.web_asset),
    ],
  ),
];

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  bool _isExpanded = false; // Start collapsed
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    if (_isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _expandPanel() {
    if (_isExpanded) return;
    setState(() {
      _isExpanded = true;
      _animationController.forward();
    });
  }

  void _collapsePanel() {
    if (!_isExpanded) return;
    setState(() {
      _isExpanded = false;
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  _scaffoldKey.currentState!.openDrawer();
                },
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () {
                    themeProvider.toggleTheme();
                  },
                ),
              ],
            )
          : null,
      drawer: isMobile
          ? Drawer(
              child: SidePanel(
                isExpanded: true,
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                  Navigator.pop(context);
                },
              ),
            )
          : null,
      body: Row(
        children: [
          if (!isMobile)
            MouseRegion(
              onEnter: (_) => _expandPanel(),
              onExit: (_) => _collapsePanel(),
              child: SidePanel(
                isExpanded: _isExpanded,
                selectedIndex: _selectedIndex,
                onItemSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (!isMobile)
                  Container(
                    height: 64,
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).appBarTheme.backgroundColor ??
                          Theme.of(context).primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 24), // Left padding for title
                        Expanded(
                          child: Text(
                            menuItems[_selectedIndex].title,
                            style:
                                Theme.of(context).appBarTheme.titleTextStyle ??
                                TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(
                                    context,
                                  ).appBarTheme.foregroundColor,
                                ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            color: Theme.of(
                              context,
                            ).appBarTheme.foregroundColor,
                          ),
                          onPressed: () {
                            themeProvider.toggleTheme();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: List.generate(
                        menuItems.length,
                        (index) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                menuItems[index].icon,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                menuItems[index].title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Content for ${menuItems[index].title} goes here',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.color
                                          ?.withOpacity(0.7),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SidePanel extends StatefulWidget {
  final bool isExpanded;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  const SidePanel({
    super.key,
    required this.isExpanded,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel>
    with SingleTickerProviderStateMixin {
  int? _expandedIndex;
  late AnimationController _expansionController;

  @override
  void initState() {
    super.initState();
    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Better color scheme for both themes
    final backgroundColor = isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFAFAFA);

    final textColor = isDarkMode ? Colors.white : const Color(0xFF2D2D2D);

    final subtextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    final selectedColor = theme.primaryColor;
    final hoverColor = isDarkMode ? Colors.grey[800] : Colors.grey[200];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isExpanded ? 280 : 80,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
              offset: const Offset(2, 0),
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              height: 80,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.isExpanded) ...[
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'AKD',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: selectedColor,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: selectedColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: selectedColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const Divider(height: 1),

            // Menu Items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: menuItems.length,
                itemBuilder: (context, index) {
                  final item = menuItems[index];
                  final isSelected = widget.selectedIndex == index;
                  final hasSubItems =
                      item.subItems != null && item.subItems!.isNotEmpty;

                  if (hasSubItems) {
                    return _buildExpandableItem(
                      context,
                      item,
                      index,
                      isSelected,
                      textColor,
                      subtextColor,
                      selectedColor,
                      hoverColor,
                    );
                  } else {
                    return _buildSimpleItem(
                      context,
                      item,
                      index,
                      isSelected,
                      textColor,
                      selectedColor,
                      hoverColor,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleItem(
    BuildContext context,
    MenuItem item,
    int index,
    bool isSelected,
    Color textColor,
    Color selectedColor,
    Color? hoverColor,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onItemSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border(left: BorderSide(color: selectedColor, width: 3))
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? selectedColor.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: isSelected ? selectedColor : textColor,
                  ),
                ),
                if (widget.isExpanded) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: isSelected ? selectedColor : textColor,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableItem(
    BuildContext context,
    MenuItem item,
    int index,
    bool isSelected,
    Color textColor,
    Color? subtextColor,
    Color selectedColor,
    Color? hoverColor,
  ) {
    final isExpanded = _expandedIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                if (widget.isExpanded) {
                  setState(() {
                    _expandedIndex = isExpanded ? null : index;
                  });
                } else {
                  widget.onItemSelected(index);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? selectedColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border(left: BorderSide(color: selectedColor, width: 3))
                      : null,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? selectedColor.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        item.icon,
                        size: 20,
                        color: isSelected ? selectedColor : textColor,
                      ),
                    ),
                    if (widget.isExpanded) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: isSelected ? selectedColor : textColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: isSelected ? selectedColor : subtextColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (widget.isExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isExpanded ? (item.subItems!.length * 44.0) : 0,
              child: ClipRect(
                // FIX: Wrapped the Column in a SingleChildScrollView
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: item.subItems!
                        .map(
                          (subItem) => _buildSubItem(
                            context,
                            subItem,
                            index,
                            isSelected,
                            textColor,
                            subtextColor,
                            selectedColor,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubItem(
    BuildContext context,
    MenuItem subItem,
    int parentIndex,
    bool isParentSelected,
    Color textColor,
    Color? subtextColor,
    Color selectedColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 8, top: 2, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => widget.onItemSelected(parentIndex),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(subItem.icon, size: 18, color: subtextColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    subItem.title,
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
