import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/notifiers/filter_state_notifier.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

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
  Widget build(BuildContext context) {
    final filterState = Provider.of<FilterStateNotifier>(context).value;

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
  }

  Widget _buildUserList(String userType, FilterState filterState) {
    return FutureBuilder<List<AppUser>>(
      key: ValueKey('$userType-${filterState.hashCode}'),
      future:
          _adminService.getUsers(userType: userType, filterState: filterState),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              ),
            );
          },
        );
      },
    );
  }
}
