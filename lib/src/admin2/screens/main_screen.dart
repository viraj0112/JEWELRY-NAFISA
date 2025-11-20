import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';
import '../providers/app_state.dart';
import '../providers/users_provider.dart';
import '../screens/b2b_creators_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/productupload_screen.dart';
import '../sections/activity_logs_section.dart';
import '../sections/analytics_section.dart';
import '../sections/content_section.dart';
import '../sections/reports_section.dart';
import '../sections/users_section.dart';
import '../utils/responsive.dart';
import '../widgets/admin_profile_menu.dart';
import '../widgets/app_sidebar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _navRailDestinations = [
    _RailDestination('dashboard', 'Dashboard', Icons.space_dashboard_outlined),
    _RailDestination('analytics', 'Analytics', Icons.analytics_outlined),
    _RailDestination('users', 'Users', Icons.people_outline),
    _RailDestination('content', 'Content', Icons.article_outlined),
    _RailDestination('reports', 'Reports', Icons.pie_chart_outline),
    _RailDestination('activity-logs', 'Activity', Icons.history),
  ];
  static const _quickRanges = [
    _QuickRange('24h', 'Last 24 Hours', Duration(hours: 24), '24h'),
    _QuickRange('7d', 'Last 7 Days', Duration(days: 7), '7d'),
    _QuickRange('30d', 'Last 30 Days', Duration(days: 30), '30d'),
    _QuickRange('90d', 'Last 90 Days', Duration(days: 90), '90d'),
  ];

  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final layout = AdminBreakpoints.ofWidth(width);
    final showDrawer = layout.isCompact;
    final showNavigationRail = layout == AdminSize.cozy;
    final showSidebar =
        layout == AdminSize.comfy || layout.isExpanded || layout.isUltra;

    return Consumer2<AppState, ThemeProvider>(
      builder: (context, appState, themeProvider, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.background,
          drawer: showDrawer
              ? Drawer(
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: const AppSidebar(
                    collapsed: false,
                    showCollapseToggle: false,
                  ),
                )
              : null,
          body: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Theme.of(context).brightness == Brightness.light
                      ? [
                          Theme.of(context).colorScheme.background,
                          Theme.of(context).colorScheme.surface,
                        ]
                      : [
                          Theme.of(context).colorScheme.background,
                          Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.8),
                        ],
                ),
              ),
              child: Row(
                children: [
                  if (showSidebar)
                    AppSidebar(
                      collapsed: layout.isUltra || _sidebarCollapsed,
                      onToggleCollapse: () => setState(
                        () => _sidebarCollapsed = !_sidebarCollapsed,
                      ),
                    ),
                  if (showNavigationRail) _buildNavigationRail(appState),
                  Expanded(
                    child: Column(
                      children: [
                        _buildTopBar(
                          context,
                          appState,
                          themeProvider,
                          layout,
                        ),
                        Expanded(
                          child: Padding(
                            padding: AdminBreakpoints.pagePadding(layout),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(28),
                                topRight: Radius.circular(28),
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 350),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.05, 0.04),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  key: ValueKey(appState.activeView),
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  child: _renderContent(appState.activeView),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationRail(AppState appState) {
    final selectedIndex = _navRailDestinations.indexWhere(
      (destination) => destination.key == appState.activeView,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex == -1 ? 0 : selectedIndex,
        labelType: NavigationRailLabelType.all,
        backgroundColor: Colors.transparent,
        indicatorColor: Theme.of(context).primaryColor.withOpacity(0.15),
        onDestinationSelected: (index) =>
            appState.setActiveView(_navRailDestinations[index].key),
        destinations: _navRailDestinations
            .map(
              (destination) => NavigationRailDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(
                  destination.icon,
                  color: Theme.of(context).primaryColor,
                ),
                label: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(destination.label),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    AppState appState,
    ThemeProvider themeProvider,
    AdminSize layout,
  ) {
    final isMobile = layout.isCompact;
    final colorScheme = Theme.of(context).colorScheme;

    final trailingWidgets = <Widget>[
      if (!isMobile)
        _LiveModeToggle(
          enabled: appState.isLiveDataEnabled,
          onChanged: (_) => appState.toggleLiveData(),
        ),
      IconButton(
        tooltip: 'Toggle theme',
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: themeProvider.themeMode == ThemeMode.dark
              ? const Icon(Icons.light_mode, key: ValueKey('light'))
              : const Icon(Icons.dark_mode, key: ValueKey('dark')),
        ),
        onPressed: () => themeProvider.toggleTheme(),
      ),
      const AdminProfileMenu(),
    ];

    return Padding(
      padding: EdgeInsets.only(
        left: isMobile ? 12 : 20,
        right: isMobile ? 8 : 20,
        top: 12,
        bottom: 12,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outline.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 20,
          vertical: 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMobile)
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      tooltip: 'Open navigation',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _getViewTitle(appState.activeView),
                          key: ValueKey(appState.activeView),
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (!isMobile)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Monitoring ${appState.selectedTimeRange.toLowerCase()} • ${appState.activeFilters.isEmpty ? 'No filters applied' : appState.activeFilters.join(', ')}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.6),
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.end,
                      children: trailingWidgets,
                    ),
                  ),
                ),
              ],
            ),
            if (isMobile)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _LiveModeToggle(
                  enabled: appState.isLiveDataEnabled,
                  onChanged: (_) => appState.toggleLiveData(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildQuickRangeSelector(appState, isMobile),
            ),
            if (appState.activeFilters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildActiveFilters(appState, isMobile),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickRangeSelector(AppState appState, bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _quickRanges.map((range) {
          final isSelected = appState.selectedTimeRange == range.label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(isMobile ? range.shortLabel : range.label),
              selected: isSelected,
              onSelected: (_) => _applyQuickRange(appState, range),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActiveFilters(AppState appState, bool isMobile) {
    final chips = appState.activeFilters
        .map(
          (filter) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: true,
              onSelected: (_) => appState.removeFilter(filter),
              onDeleted: () => appState.removeFilter(filter),
              showCheckmark: false,
            ),
          ),
        )
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...chips,
          if (chips.isNotEmpty)
            TextButton(
              onPressed: appState.clearFilters,
              child: const Text('Clear filters'),
            ),
        ],
      ),
    );
  }

  void _applyQuickRange(AppState appState, _QuickRange range) {
    final now = DateTime.now();
    final start = now.subtract(range.duration);
    appState.setDateRange(start, now, range.label);
  }

  Widget _renderContent(String activeView) {
    switch (activeView) {
      case 'content':
        return const ContentSection();
      case 'users':
        return ChangeNotifierProvider(
          create: (_) => UsersProvider(),
          child: const UsersSection(),
        );
      case 'b2b-creators':
        return const B2BCreatorsScreen();
      case 'product-upload':
        return const ProductUploadScreen();
      case 'analytics':
        return const AnalyticsSection();
      case 'reports':
        return const ReportsSection();
      case 'activity-logs':
        return const ActivityLogsSection();
      case 'dashboard':
        return const DashboardScreen();
      default:
        return const B2BCreatorsScreen();
    }
  }

  String _getViewTitle(String view) {
    switch (view) {
      case 'users':
        return 'Users Management';
      case 'content':
        return 'Content Management';
      case 'b2b-creators':
        return 'B2B Creators';
      case 'analytics':
        return 'Analytics Insights';
      case 'reports':
        return 'Reports';
      case 'activity-logs':
        return 'Activity Logs';
      case 'product-upload':
        return 'Product Upload';
      case 'dashboard':
        return 'Operational Dashboard';
      default:
        return 'Admin Panel';
    }
  }
}

class _RailDestination {
  final String key;
  final String label;
  final IconData icon;

  const _RailDestination(this.key, this.label, this.icon);
}

class _QuickRange {
  final String key;
  final String label;
  final Duration duration;
  final String shortLabel;

  const _QuickRange(this.key, this.label, this.duration, this.shortLabel);
}

class _LiveModeToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _LiveModeToggle({
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: enabled
            ? colorScheme.primary.withOpacity(0.12)
            : colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: enabled ? Colors.greenAccent : colorScheme.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            enabled ? 'Live data' : 'Paused',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: enabled,
            onChanged: onChanged,
            activeColor: colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}
