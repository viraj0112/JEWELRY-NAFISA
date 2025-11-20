import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class AppSidebar extends StatelessWidget {
  final bool collapsed;
  final bool showCollapseToggle;
  final VoidCallback? onToggleCollapse;

  const AppSidebar({
    super.key,
    this.collapsed = false,
    this.showCollapseToggle = true,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = colorScheme.shadow.withOpacity(0.08);

    return Consumer<AppState>(
      builder: (context, appState, child) {
        return AnimatedContainer(
          width: collapsed ? 88 : 280,
          duration: const Duration(milliseconds: 250),
          curve: Curves.fastOutSlowIn,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                offset: const Offset(2, 4),
                blurRadius: 16,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    collapsed ? 20 : 24,
                    28,
                    collapsed ? 16 : 24,
                    16,
                  ),
                  child: Row(
                    mainAxisAlignment: collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        width: collapsed ? 44 : 48,
                        height: collapsed ? 44 : 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.75),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.35),
                              offset: const Offset(0, 6),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.diamond,
                          color: Colors.white,
                        ),
                      ),
                      if (!collapsed) ...[
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jewelry Admin',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Premium Dashboard',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.5),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!collapsed)
                  _GradientDivider(colorScheme: colorScheme)
                else
                  const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 12 : 20,
                    ),
                    children: [
                      _buildSectionHeader(context, 'Main'),
                      _buildNavItem(
                        context,
                        'dashboard',
                        'Dashboard',
                        Icons.dashboard_outlined,
                        appState.activeView == 'dashboard',
                        () => appState.setActiveView('dashboard'),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(context, 'Management'),
                      _buildNavItem(
                        context,
                        'users',
                        'Users',
                        Icons.people_outline,
                        appState.activeView == 'users',
                        () => appState.setActiveView('users'),
                      ),
                      _buildNavItem(
                        context,
                        'content',
                        'Content',
                        Icons.article_outlined,
                        appState.activeView == 'content',
                        () => appState.setActiveView('content'),
                      ),
                      _buildNavItem(
                        context,
                        'b2b-creators',
                        'B2B Creators',
                        Icons.business_outlined,
                        appState.activeView == 'b2b-creators',
                        () => appState.setActiveView('b2b-creators'),
                      ),
                      _buildNavItem(
                        context,
                        'product-upload',
                        'Product Upload',
                        Icons.cloud_upload_outlined,
                        appState.activeView == 'product-upload',
                        () => appState.setActiveView('product-upload'),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(context, 'Analytics'),
                      _buildNavItem(
                        context,
                        'analytics',
                        'Analytics',
                        Icons.analytics_outlined,
                        appState.activeView == 'analytics',
                        () => appState.setActiveView('analytics'),
                      ),
                      _buildNavItem(
                        context,
                        'ai-requests',
                        'AI Requests',
                        Icons.auto_fix_high,
                        appState.activeView == 'ai-requests',
                        () => appState.setActiveView('ai-requests'),
                      ),
                      _buildNavItem(
                        context,
                        'website-performance',
                        'Website Performance',
                        Icons.speed,
                        appState.activeView == 'website-performance',
                        () => appState.setActiveView('website-performance'),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(context, 'Engagement'),
                      _buildNavItem(
                        context,
                        'notifications',
                        'Notifications',
                        Icons.notifications_outlined,
                        appState.activeView == 'notifications',
                        () => appState.setActiveView('notifications'),
                      ),
                      _buildNavItem(
                        context,
                        'email',
                        'Email',
                        Icons.email_outlined,
                        appState.activeView == 'email',
                        () => appState.setActiveView('email'),
                      ),
                      _buildNavItem(
                        context,
                        'reports',
                        'Reports',
                        Icons.assessment_outlined,
                        appState.activeView == 'reports',
                        () => appState.setActiveView('reports'),
                      ),
                      const SizedBox(height: 16),
                      _buildSectionHeader(context, 'System'),
                      _buildNavItem(
                        context,
                        'alerts',
                        'Alerts',
                        Icons.warning_amber_outlined,
                        appState.activeView == 'alerts',
                        () => appState.setActiveView('alerts'),
                      ),
                      _buildNavItem(
                        context,
                        'activity-logs',
                        'Activity Logs',
                        Icons.history_outlined,
                        appState.activeView == 'activity-logs',
                        () => appState.setActiveView('activity-logs'),
                      ),
                      _buildNavItem(
                        context,
                        'settings',
                        'Settings',
                        Icons.settings_outlined,
                        appState.activeView == 'settings',
                        () => appState.setActiveView('settings'),
                      ),
                    ],
                  ),
                ),
                if (showCollapseToggle)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: collapsed ? 8 : 16,
                      vertical: 16,
                    ),
                    child: Tooltip(
                      message: collapsed ? 'Expand menu' : 'Collapse menu',
                      child: OutlinedButton.icon(
                        onPressed: onToggleCollapse,
                        icon: Icon(
                          collapsed ? Icons.chevron_right : Icons.chevron_left,
                          size: 18,
                        ),
                        label: collapsed
                            ? const SizedBox.shrink()
                            : const Text('Collapse'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: collapsed ? 12 : 16,
                            vertical: 12,
                          ),
                          minimumSize:
                              Size(collapsed ? 44 : double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    if (collapsed) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 6, top: 10),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
            ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String key,
    String title,
    IconData icon,
    bool isActive,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = Theme.of(context).primaryColor;
    final inactiveColor = colorScheme.onSurface.withOpacity(0.7);

    final Widget content = Row(
      children: [
        Container(
          width: collapsed ? 40 : 28,
          height: collapsed ? 40 : 28,
          decoration: isActive
              ? BoxDecoration(
                  color: activeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
          child: Icon(
            icon,
            color: isActive ? activeColor : inactiveColor,
            size: collapsed ? 20 : 18,
          ),
        ),
        if (!collapsed) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isActive ? activeColor : inactiveColor,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ),
          if (isActive)
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ],
    );

    return Tooltip(
      message: collapsed ? title : '',
      waitDuration: const Duration(milliseconds: 500),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: activeColor.withOpacity(0.25))
              : Border.all(color: Colors.transparent),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: collapsed ? 12 : 16,
                vertical: collapsed ? 10 : 12,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientDivider extends StatelessWidget {
  final ColorScheme colorScheme;

  const _GradientDivider({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            colorScheme.outline.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
