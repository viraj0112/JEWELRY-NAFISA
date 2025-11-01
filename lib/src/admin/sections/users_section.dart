import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/notifiers/filter_state_notifier.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({super.key});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final AdminService _adminService = AdminService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showUserDetails(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(user.username ?? 'User Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${user.email ?? "N/A"}'),
                Text('Role: ${user.role ?? "N/A"}'),
                Text('Member: ${user.isMember}'),
                const SizedBox(height: 20),

                // FIX: Show current credits from the 'user' object
                Text(
                  'Credits Remaining: ${user.creditsRemaining}', //
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                // FIX: Show credit *usage* history from 'quotes'
                const Text('Credit Usage History (Last 20):',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                FutureBuilder<List<CreditUsageLog>>(
                  future: _adminService.getUserCreditUsage(user.id), //
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    final history = snapshot.data ?? [];
                    if (history.isEmpty) {
                      return const Text('No credit usage found.');
                    }
                    return DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Product ID')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: history
                          .map((e) => DataRow(cells: [
                                DataCell(
                                    Text(DateFormat.yMMMd().format(e.usedAt))),
                                DataCell(Text(e.productId,
                                    style: const TextStyle(fontSize: 12))),
                                DataCell(Text(e.status)),
                              ]))
                          .toList(),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // FIX: Show referral code from the 'user' object
                Text(
                  'Referral Code: ${user.referralCode ?? "N/A"}', //
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                // FIX: Show list of users this person referred
                const Text('Users Referred By Them:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                FutureBuilder<List<ReferredUser>>(
                  future: _adminService.getUsersReferredBy(user.id), //
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }
                    final tree = snapshot.data ?? [];
                    if (tree.isEmpty) {
                      return const Text('No users referred yet.');
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: tree
                          .map((node) => Text(
                              '${node.username} (Joined: ${DateFormat.yMMMd().format(node.joinedAt)})'))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            // ... (Your Delete User and Close buttons remain the same) ...
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              onPressed: () {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: Text(
                        'Are you sure you want to delete this user (${user.username ?? user.email})? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        onPressed: () async {
                          try {
                            // Call the service function
                            await _adminService.deleteUser(user.id);

                            // Close confirmation dialog
                            Navigator.of(ctx).pop();
                            // Close user details dialog
                            Navigator.of(context).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('User deleted successfully.'),
                                  backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to delete user: $e'),
                                  backgroundColor: Colors.red),
                            );
                          }
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Delete User'),
            ),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FilterStateNotifier>(
      builder: (context, filterNotifier, child) {
        final filterState = filterNotifier.value;
        return Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Members'),
                Tab(text: 'Non-Members'),
                Tab(text: 'B2B Creators'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildUserList('Members', filterState),
                  _buildUserList('Non-Members', filterState),
                  _buildUserList('B2B Creators', filterState),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUserList(String userType, FilterState filterState) {
    return StreamBuilder<List<AppUser>>(
      // The key ensures the StreamBuilder gets a new stream when filters change
      key: ValueKey('$userType-${filterState.hashCode}'),
      stream: _adminService.getUsers(
        userType: userType,
        filterState: filterState,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(
            child: Text(
              'No users found for the selected criteria.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundImage:
                      (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? Text(
                          user.username?.substring(0, 1).toUpperCase() ?? 'U')
                      : null,
                ),
                title: Text(user.username ?? 'No Username'),
                subtitle: Text(user.email ?? 'No Email'),
                trailing: Text(DateFormat.yMMMd().format(user.createdAt)),
                onTap: () => _showUserDetails(context, user),
              ),
            );
          },
        );
      },
    );
  }
}
