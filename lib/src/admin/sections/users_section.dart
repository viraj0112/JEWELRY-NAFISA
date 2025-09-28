import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/admin/widgets/filter_component.dart';
import 'package:provider/provider.dart';

class UsersSection extends StatefulWidget {
  const UsersSection({super.key});

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AdminService _adminService = AdminService();
  final List<String> _userTypes = ['Members', 'Non-Members', 'B2B Creators'];
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUsersForTab(0, null); // Initial fetch
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Refetch when tab changes, applying current filters
        _fetchUsersForTab(
            _tabController.index, context.read<FilterStateNotifier>().value);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for filter changes and refetch data
    final filterNotifier = Provider.of<FilterStateNotifier>(context);
    filterNotifier.addListener(_onFilterChanged);
  }

  void _onFilterChanged() {
    final filterState = context.read<FilterStateNotifier>().value;
    _fetchUsersForTab(_tabController.index, filterState);
  }

  void _fetchUsersForTab(int index, FilterState? filterState) {
    setState(() {
      _usersFuture = _adminService.getUsers(
        userType: _userTypes[index],
        filterState: filterState,
      );
    });
  }

  Future<void> _deleteUser(String userId) async {
    // ... (deleteUser implementation is correct)
  }

  @override
  void dispose() {
    _tabController.dispose();
    Provider.of<FilterStateNotifier>(context, listen: false)
        .removeListener(_onFilterChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Users Management',
                style: GoogleFonts.inter(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add User'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(),
          tabs: const [
            Tab(text: 'Members (Premium)'),
            Tab(text: 'Non-Members (Free)'),
            Tab(text: 'B2B Creators'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<AppUser>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Failed to load users: ${snapshot.error}'));
              }
              final users = snapshot.data ?? [];
              if (users.isEmpty) {
                return const Center(
                    child: Text('No users found in this category.'));
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 600) {
                    return _buildUserList(users);
                  } else {
                    return _buildUserTable(users);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserList(List<AppUser> users) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return StyledCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.username ?? 'N/A',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(user.email ?? 'No Email',
                  style: Theme.of(context).textTheme.bodySmall),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Joined: ${DateFormat.yMMMd().format(user.createdAt)}'),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.edit_outlined, size: 20)),
                      IconButton(
                          onPressed: () => _deleteUser(user.id),
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserTable(List<AppUser> users) {
    return StyledCard(
      child: Column(
        children: [
          // Search and export UI remains the same
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Username')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Joined Date')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: users.map((user) {
                  return DataRow(cells: [
                    DataCell(Text(user.username ?? 'N/A')),
                    DataCell(Text(user.email ?? 'No Email')),
                    DataCell(Chip(
                      label: Text(user.role == 'designer'
                          ? user.approvalStatus ?? 'N/A'
                          : (user.isMember ? 'Member' : 'Free')),
                      backgroundColor: user.role == 'designer'
                          ? user.statusColor.withOpacity(0.1)
                          : (user.isMember
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1)),
                      side: BorderSide.none,
                    )),
                    DataCell(Text(DateFormat.yMMMd().format(user.createdAt))),
                    DataCell(Row(
                      children: [
                        IconButton(
                            onPressed: () {/* TODO: Implement Edit */},
                            icon: const Icon(Icons.edit_outlined, size: 20)),
                        IconButton(
                            onPressed: () => _deleteUser(user.id),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20)),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
