import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_user.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  _AdminUsersScreenState createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();
  String _currentFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentFilter =
              ['All', 'Members', 'Non-Members'][_tabController.index];
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Users'),
            Tab(text: 'Members'),
            Tab(text: 'Non-Members'),
          ],
        ),
      ),
      body: _buildUserTable(),
    );
  }

  Widget _buildUserTable() {
    return FutureBuilder<List<AdminUser>>(
      future: _adminService.getUsers(_currentFilter),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text('Failed to load users'));
        }
        final users = snapshot.data ?? [];

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SizedBox(
            width: double.infinity,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Credits')),
                DataColumn(label: Text('Actions')),
              ],
              rows: users.map((user) => _buildUserRow(user)).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildUserRow(AdminUser user) {
    return DataRow(cells: [
      DataCell(
        Row(
          children: [
            CircleAvatar(
              backgroundImage:
                  user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
              child: user.avatarUrl == null ? Text(user.name[0]) : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(user.email, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
      DataCell(Text(user.role)),
      DataCell(
        Chip(
          label: Text(user.isMember ? 'Member' : 'Non-Member'),
          backgroundColor: user.isMember ? Colors.green.withOpacity(0.2) : null,
        ),
      ),
      DataCell(Text(user.creditsRemaining.toString())),
      DataCell(
        PopupMenuButton<String>(
          onSelected: (value) {
            // Handle actions like edit, ban, etc.
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
            const PopupMenuItem<String>(value: 'ban', child: Text('Ban')),
            const PopupMenuItem<String>(
                value: 'reset_credits', child: Text('Reset Credits')),
          ],
        ),
      ),
    ]);
  }
}