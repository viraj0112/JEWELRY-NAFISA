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
                Text('Email: ${user.email}'),
                Text('Role: ${user.role}'),
                Text('Member: ${user.isMember}'),
                const SizedBox(height: 20),
                const Text('Credit History:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                FutureBuilder<List<CreditHistory>>(
                  future: _adminService.getUserCreditHistory(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final history = snapshot.data ?? [];
                    return DataTable(
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Added')),
                        DataColumn(label: Text('Spent')),
                      ],
                      rows: history
                          .map((e) => DataRow(cells: [
                                DataCell(Text(
                                    DateFormat.yMMMd().format(e.entryDate))),
                                DataCell(Text(e.creditsAdded.toString())),
                                DataCell(Text(e.creditsSpent.toString())),
                              ]))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text('Referral Tree:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                FutureBuilder<List<ReferralNode>>(
                  future: _adminService.getReferralTree(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final tree = snapshot.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: tree
                          .map((node) => Padding(
                                padding:
                                    EdgeInsets.only(left: (node.level * 20.0)),
                                child: Text(
                                    '${node.username} (Level ${node.level})'),
                              ))
                          .toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
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
