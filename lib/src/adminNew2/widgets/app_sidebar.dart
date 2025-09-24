import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import 'package:provider/provider.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Container(
          width: 280,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                offset: const Offset(2, 0),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              // Logo/Brand section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor,
                            Theme.of(context).primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).primaryColor.withOpacity(0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.diamond,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jewelry Admin',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Premium Dashboard',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Divider
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.grey.shade200,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Navigation items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Main Section
                    _buildSectionHeader('Main'),
                    _buildNavItem(
                      context,
                      'dashboard',
                      'Dashboard',
                      Icons.dashboard_outlined,
                      appState.activeView == 'dashboard',
                      () => appState.setActiveView('dashboard'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'analytics',
                      'Analytics',
                      Icons.analytics_outlined,
                      appState.activeView == 'analytics',
                      () => appState.setActiveView('analytics'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Management Section
                    _buildSectionHeader('Management'),
                    _buildNavItem(
                      context,
                      'users',
                      'Users',
                      Icons.people_outline,
                      appState.activeView == 'users',
                      () => appState.setActiveView('users'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'content',
                      'Content',
                      Icons.article_outlined,
                      appState.activeView == 'content',
                      () => appState.setActiveView('content'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'b2b-creators',
                      'B2B Creators',
                      Icons.business_outlined,
                      appState.activeView == 'b2b-creators',
                      () => appState.setActiveView('b2b-creators'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Business Section
                    _buildSectionHeader('Business'),
                    _buildNavItem(
                      context,
                      'monetization',
                      'Monetization',
                      Icons.monetization_on_outlined,
                      appState.activeView == 'monetization',
                      () => appState.setActiveView('monetization'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'marketing',
                      'Marketing',
                      Icons.campaign_outlined,
                      appState.activeView == 'marketing',
                      () => appState.setActiveView('marketing'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'reports',
                      'Reports',
                      Icons.assessment_outlined,
                      appState.activeView == 'reports',
                      () => appState.setActiveView('reports'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Communications Section
                    _buildSectionHeader('Communications'),
                    _buildNavItem(
                      context,
                      'notifications',
                      'Notifications',
                      Icons.notifications_outlined,
                      appState.activeView == 'notifications',
                      () => appState.setActiveView('notifications'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'email',
                      'Email',
                      Icons.email_outlined,
                      appState.activeView == 'email',
                      () => appState.setActiveView('email'),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // System Section
                    _buildSectionHeader('System'),
                    _buildNavItem(
                      context,
                      'alerts',
                      'Alerts',
                      Icons.warning_amber_outlined,
                      appState.activeView == 'alerts',
                      () => appState.setActiveView('alerts'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'activity-logs',
                      'Activity Logs',
                      Icons.history_outlined,
                      appState.activeView == 'activity-logs',
                      () => appState.setActiveView('activity-logs'),
                    ),
                    const SizedBox(height: 4),
                    _buildNavItem(
                      context,
                      'settings',
                      'Settings',
                      Icons.settings_outlined,
                      appState.activeView == 'settings',
                      () => appState.setActiveView('settings'),
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive 
          ? Theme.of(context).primaryColor.withOpacity(0.08)
          : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive 
          ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2))
          : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: isActive 
                    ? BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                  child: Icon(
                    icon,
                    color: isActive 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade600,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isActive 
                        ? Theme.of(context).primaryColor 
                        : Colors.grey.shade700,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(2),
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