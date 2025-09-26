import 'package:flutter/material.dart';

class UsersSection extends StatelessWidget {
  const UsersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 800;
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Users Management',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add User'),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Users table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table header with search and filters
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search users...',
                                prefixIcon:
                                    const Icon(Icons.search, size: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                fillColor: Colors.grey.shade50,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () {},
                            icon: const Icon(Icons.filter_list, size: 16),
                            label: const Text('Filter'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Users table
                      isWide ? _buildUsersTable(context) : _buildUsersList(context),

                      const SizedBox(height: 24),

                      // Pagination
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Showing 1-10 of 24,567 users',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.chevron_left),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {},
                                child: const Text('2'),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: const Text('3'),
                              ),
                              const Text('...'),
                              TextButton(
                                onPressed: () {},
                                child: const Text('100'),
                              ),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.chevron_right),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUsersList(BuildContext context) {
    final users = _getUsers();
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final user = users[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Text(
              user['name']![0],
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          title: Text(user['name']!),
          subtitle: Text(user['email']!),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               _statusChip(user),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit, size: 16),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
              ),
            ],
          ),
        );
      },
    );
  }

  DataTable _buildUsersTable(BuildContext context) {
    final users = _getUsers();

    return DataTable(
      columns: const [
        DataColumn(label: Text('Name')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Role')),
        DataColumn(label: Text('Joined')),
        DataColumn(label: Text('Actions')),
      ],
      rows: users.map((user) => DataRow(
        cells: [
          DataCell(
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    user['name']![0],
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(user['name']!),
              ],
            ),
          ),
          DataCell(Text(user['email']!)),
          DataCell(_statusChip(user)),
          DataCell(_roleChip(user)),
          DataCell(Text(user['joined']!)),
          DataCell(Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.edit, size: 16),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.delete, size: 16, color: Colors.red),
              ),
            ],
          )),
        ],
      )).toList(),
    );
  }
   Widget _statusChip(Map<String, String> user) {
    return Chip(
      label: Text(user['status']!),
      backgroundColor: user['status'] == 'Active'
          ? Colors.green.withOpacity(0.1)
          : Colors.red.withOpacity(0.1),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: user['status'] == 'Active' ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _roleChip(Map<String, String> user) {
    return Chip(
      label: Text(user['role']!),
      backgroundColor: user['role'] == 'Premium'
          ? Colors.purple.withOpacity(0.1)
          : Colors.blue.withOpacity(0.1),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: user['role'] == 'Premium' ? Colors.purple : Colors.blue,
      ),
    );
  }
  List<Map<String,String>> _getUsers() {
    return [
      {
        'name': 'Sarah Chen',
        'email': 'sarah.chen@email.com',
        'status': 'Active',
        'role': 'Premium',
        'joined': 'Jan 15, 2024',
      },
      {
        'name': 'Mike Johnson',
        'email': 'mike.j@email.com',
        'status': 'Active',
        'role': 'Basic',
        'joined': 'Feb 2, 2024',
      },
      {
        'name': 'Emma Wilson',
        'email': 'emma.wilson@email.com',
        'status': 'Inactive',
        'role': 'Premium',
        'joined': 'Dec 20, 2023',
      },
      {
        'name': 'David Brown',
        'email': 'david.brown@email.com',
        'status': 'Active',
        'role': 'Basic',
        'joined': 'Mar 5, 2024',
      },
      {
        'name': 'Lisa Garcia',
        'email': 'lisa.garcia@email.com',
        'status': 'Active',
        'role': 'Premium',
        'joined': 'Jan 28, 2024',
      },
    ];

  }
}