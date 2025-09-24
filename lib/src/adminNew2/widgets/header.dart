import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/providers/theme_provider.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';

class Header extends StatelessWidget {
  final VoidCallback onSignOut;
  const Header({super.key, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProfile = context.watch<UserProfileProvider>();

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Row(
          children: [
            // Search bar
            Expanded(
              flex: 2,
              child: Container(
                height: 44,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users, content, analytics...',
                    hintStyle: TextStyle(
                      color: theme.textTheme.bodySmall?.color,
                      fontSize: 14,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.search_rounded,
                        color: theme.iconTheme.color,
                        size: 20,
                      ),
                    ),
                    suffixIcon: Container(
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '⌘K',
                          style: TextStyle(
                            color: theme.textTheme.bodySmall?.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            const Spacer(),
            // Theme toggle button
            _buildQuickAction(
              context,
              themeProvider.themeMode == ThemeMode.light
                  ? Icons.dark_mode_outlined
                  : Icons.light_mode_outlined,
              'Toggle Theme',
              () => themeProvider.toggleTheme(),
            ),
            const SizedBox(width: 12),
            // Quick actions
            _buildQuickAction(
              context,
              Icons.add_rounded,
              'Add New',
              () {},
              isPrimary: true,
            ),
            const SizedBox(width: 12),
            _buildQuickAction(
              context,
              Icons.notifications_outlined,
              'Notifications',
              () {},
              badge: '3',
            ),
            const SizedBox(width: 8),
            _buildQuickAction(
              context,
              Icons.help_outline,
              'Help',
              () {},
            ),

            const SizedBox(width: 24),

            // User profile
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'logout') {
                  onSignOut();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(userProfile.username.isNotEmpty
                          ? userProfile.username[0]
                          : 'A'),
                    ),
                    title: Text(userProfile.username),
                    subtitle: Text(userProfile.role),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Log out'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.primaryColor,
                              theme.primaryColor.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.3),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            userProfile.username.isNotEmpty
                                ? userProfile.username
                                    .substring(0, 2)
                                    .toUpperCase()
                                : 'AD',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userProfile.username,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          Text(
                            userProfile.role,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.iconTheme.color,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onPressed, {
    bool isPrimary = false,
    String? badge,
  }) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Tooltip(
          message: tooltip,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPrimary
                  ? theme.primaryColor
                  : theme.dividerColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              boxShadow: isPrimary
                  ? [
                      BoxShadow(
                        color: theme.primaryColor.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(10),
                child: Icon(
                  icon,
                  color: isPrimary ? Colors.white : theme.iconTheme.color,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade500,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}