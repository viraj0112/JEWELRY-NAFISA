import 'package:flutter/material.dart' as material;
import 'package:jewelry_nafisa/src/auth/supabase_auth_service.dart';
import 'package:jewelry_nafisa/src/ui/screens/welcome/welcome_screen.dart';
import 'constants/app_menu_items.dart';
import 'models/menu_item.dart';
import 'widgets/header.dart';

class AdminShell extends material.StatefulWidget {
  const AdminShell({super.key});

  @override
  material.State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends material.State<AdminShell> {
  final material.GlobalKey<material.ScaffoldState> _scaffoldKey =
      material.GlobalKey<material.ScaffoldState>();
  late MenuItem _selectedItem;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = menuItems.first;
  }

  void _expandPanel() => setState(() => _isExpanded = true);
  void _collapsePanel() => setState(() => _isExpanded = false);

  void _handleItemSelected(MenuItem item) {
    if (item.screen != null) {
      setState(() {
        _selectedItem = item;
      });
    }
  }

  Future<void> _signOut() async {
    await SupabaseAuthService().signOut();
    if (mounted) {
      material.Navigator.of(context).pushAndRemoveUntil(
        material.MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    final isMobile = material.MediaQuery.of(context).size.width < 800;
    return material.Scaffold(
      key: _scaffoldKey,
      appBar: isMobile
          ? material.AppBar(
              title: material.Text(_selectedItem.title),
              leading: material.IconButton(
                icon: const material.Icon(material.Icons.menu),
                onPressed: () => _scaffoldKey.currentState!.openDrawer(),
              ),
            )
          : null,
      drawer: isMobile
          ? material.Drawer(
              child: SidePanel(
                isExpanded: true,
                selectedItem: _selectedItem,
                onItemSelected: (item) {
                  _handleItemSelected(item);
                  material.Navigator.pop(context);
                },
              ),
            )
          : null,
      body: material.Row(
        children: [
          if (!isMobile)
            material.MouseRegion(
              onEnter: (_) => _expandPanel(),
              onExit: (_) => _collapsePanel(),
              child: SidePanel(
                isExpanded: _isExpanded,
                selectedItem: _selectedItem,
                onItemSelected: _handleItemSelected,
              ),
            ),
          material.Expanded(
            child: material.Column(
              children: [
                if (!isMobile) Header(onSignOut: _signOut),
                material.Expanded(
                  child:
                      _selectedItem.screen ??
                      const material.Center(
                        child: material.Text(
                          "Select an item to view its content.",
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

class SidePanel extends material.StatefulWidget {
  final bool isExpanded;
  final MenuItem selectedItem;
  final material.ValueChanged<MenuItem> onItemSelected;

  const SidePanel({
    super.key,
    required this.isExpanded,
    required this.selectedItem,
    required this.onItemSelected,
  });

  @override
  material.State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends material.State<SidePanel> {
  MenuItem? _expandedItem;

  @override
  void initState() {
    super.initState();
    for (var item in menuItems) {
      if (item.subItems?.contains(widget.selectedItem) ?? false) {
        _expandedItem = item;
        break;
      }
    }
  }

  @override
  material.Widget build(material.BuildContext context) {
    final theme = material.Theme.of(context);
    final isDarkMode = theme.brightness == material.Brightness.dark;
    final backgroundColor = isDarkMode
        ? const material.Color(0xFF1E1E1E)
        : const material.Color(0xFFFAFAFA);
    final textColor = isDarkMode
        ? material.Colors.white
        : const material.Color(0xFF2D2D2D);
    final subtextColor = isDarkMode
        ? material.Colors.grey[400]!
        : material.Colors.grey[600]!;
    final selectedColor = theme.primaryColor;

    return material.AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isExpanded ? 280 : 80,
      decoration: material.BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          material.BoxShadow(
            color: material.Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
            offset: const material.Offset(2, 0),
            blurRadius: 8,
          ),
        ],
      ),
      child: material.Column(
        children: [
          material.SizedBox(
            height: 80,
            child: material.Center(
              child: widget.isExpanded
                  ? material.Text(
                      'AKD',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: material.FontWeight.bold,
                        color: selectedColor,
                      ),
                    )
                  : material.Container(
                      padding: const material.EdgeInsets.all(8),
                      decoration: material.BoxDecoration(
                        color: selectedColor.withOpacity(0.1),
                        borderRadius: material.BorderRadius.circular(8),
                      ),
                      child: material.Text(
                        'A',
                        style: material.TextStyle(
                          fontSize: 14,
                          fontWeight: material.FontWeight.bold,
                          color: selectedColor,
                        ),
                      ),
                    ),
            ),
          ),
          const material.Divider(height: 1),
          material.Expanded(
            child: material.ListView.builder(
              padding: const material.EdgeInsets.symmetric(vertical: 8),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                final hasSubItems =
                    item.subItems != null && item.subItems!.isNotEmpty;
                final isSelected =
                    widget.selectedItem == item ||
                    (item.subItems?.contains(widget.selectedItem) ?? false);
                if (!hasSubItems) {
                  return _buildSimpleItem(
                    context,
                    item,
                    isSelected,
                    textColor,
                    selectedColor,
                  );
                } else {
                  return material.MouseRegion(
                    onEnter: (_) => setState(() => _expandedItem = item),
                    onExit: (_) => setState(() => _expandedItem = null),
                    child: _buildExpandableItem(
                      context,
                      item,
                      isSelected,
                      textColor,
                      subtextColor,
                      selectedColor,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  material.Widget _buildSimpleItem(
    material.BuildContext context,
    MenuItem item,
    bool isSelected,
    material.Color textColor,
    material.Color selectedColor,
  ) {
    return material.Container(
      margin: const material.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: material.BoxDecoration(
        color: isSelected
            ? selectedColor.withOpacity(0.1)
            : material.Colors.transparent,
        borderRadius: material.BorderRadius.circular(8),
        border: isSelected
            ? material.Border(
                left: material.BorderSide(color: selectedColor, width: 3),
              )
            : null,
      ),
      child: material.Material(
        color: material.Colors.transparent,
        child: material.InkWell(
          borderRadius: material.BorderRadius.circular(8),
          onTap: () => widget.onItemSelected(item),
          child: material.Padding(
            padding: const material.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            child: material.Row(
              children: [
                material.Icon(
                  item.icon,
                  size: 20,
                  color: isSelected ? selectedColor : textColor,
                ),
                if (widget.isExpanded) ...[
                  const material.SizedBox(width: 12),
                  material.Expanded(
                    child: material.Text(
                      item.title,
                      style: material.TextStyle(
                        color: isSelected ? selectedColor : textColor,
                        fontWeight: isSelected
                            ? material.FontWeight.w600
                            : material.FontWeight.w400,
                        fontSize: 14,
                      ),
                      overflow: material.TextOverflow.ellipsis,
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

  material.Widget _buildExpandableItem(
    material.BuildContext context,
    MenuItem item,
    bool isSelected,
    material.Color textColor,
    material.Color subtextColor,
    material.Color selectedColor,
  ) {
    final isEffectivelyExpanded = _expandedItem == item;
    return material.Container(
      margin: const material.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: material.Column(
        mainAxisSize: material.MainAxisSize.min,
        children: [
          material.Material(
            child: material.InkWell(
              borderRadius: material.BorderRadius.circular(8),
              onTap: () {
                if (widget.isExpanded) {
                  setState(
                    () => _expandedItem = isEffectivelyExpanded ? null : item,
                  );
                } else if (item.screen != null) {
                  widget.onItemSelected(item);
                }
              },
              child: material.Container(
                decoration: material.BoxDecoration(
                  color: isSelected && !isEffectivelyExpanded
                      ? selectedColor.withOpacity(0.1)
                      : material.Colors.transparent,
                  borderRadius: material.BorderRadius.circular(8),
                  border: isSelected && !isEffectivelyExpanded
                      ? material.Border(
                          left: material.BorderSide(
                            color: selectedColor,
                            width: 3,
                          ),
                        )
                      : null,
                ),
                padding: const material.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: material.Row(
                  children: [
                    material.Icon(
                      item.icon,
                      size: 20,
                      color: isSelected ? selectedColor : textColor,
                    ),
                    if (widget.isExpanded) ...[
                      const material.SizedBox(width: 12),
                      material.Expanded(
                        child: material.Text(
                          item.title,
                          style: material.TextStyle(
                            color: isSelected ? selectedColor : textColor,
                            fontWeight: isSelected
                                ? material.FontWeight.w600
                                : material.FontWeight.w400,
                            fontSize: 14,
                          ),
                          overflow: material.TextOverflow.ellipsis,
                        ),
                      ),
                      material.AnimatedRotation(
                        turns: isEffectivelyExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: material.Icon(
                          material.Icons.keyboard_arrow_down,
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
            material.AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: material.Curves.easeInOut,
              child: material.Container(
                height: isEffectivelyExpanded ? null : 0,
                child: material.Column(
                  children: item.subItems!
                      .map(
                        (subItem) => _buildSubItem(
                          context,
                          subItem,
                          subtextColor,
                          selectedColor,
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  material.Widget _buildSubItem(
    material.BuildContext context,
    MenuItem subItem,
    material.Color subtextColor,
    material.Color selectedColor,
  ) {
    final isSubItemSelected = widget.selectedItem == subItem;
    return material.Container(
      margin: const material.EdgeInsets.only(
        left: 28,
        right: 8,
        top: 2,
        bottom: 2,
      ),
      decoration: material.BoxDecoration(
        color: isSubItemSelected
            ? selectedColor.withOpacity(0.1)
            : material.Colors.transparent,
        borderRadius: material.BorderRadius.circular(6),
      ),
      child: material.Material(
        color: material.Colors.transparent,
        child: material.InkWell(
          borderRadius: material.BorderRadius.circular(6),
          onTap: () => widget.onItemSelected(subItem),
          child: material.Padding(
            padding: const material.EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: material.Row(
              children: [
                material.Icon(
                  subItem.icon,
                  size: 18,
                  color: isSubItemSelected ? selectedColor : subtextColor,
                ),
                const material.SizedBox(width: 12),
                material.Expanded(
                  child: material.Text(
                    subItem.title,
                    style: material.TextStyle(
                      color: isSubItemSelected ? selectedColor : subtextColor,
                      fontSize: 13,
                      fontWeight: isSubItemSelected
                          ? material.FontWeight.w500
                          : material.FontWeight.w400,
                    ),
                    overflow: material.TextOverflow.ellipsis,
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
