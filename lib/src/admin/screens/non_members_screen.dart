import 'dart:async';
import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/services/enhanced_admin_service.dart';
import 'package:jewelry_nafisa/src/admin/models/enhanced_admin_models.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_models.dart';

class NonMembersScreen extends StatefulWidget {
  const NonMembersScreen({super.key});

  @override
  State<NonMembersScreen> createState() => _NonMembersScreenState();
}

class _NonMembersScreenState extends State<NonMembersScreen>
    with TickerProviderStateMixin {
  final EnhancedAdminService _adminService = EnhancedAdminService();
  late final StreamController<List<EnhancedUser>> _usersController;
  FilterState _filterState = FilterState.defaultFilters();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _usersController = StreamController<List<EnhancedUser>>.broadcast();
    _loadNonMembers();
  }

  @override
  void dispose() {
    _usersController.close();
    _adminService.dispose();
    super.dispose();
  }

  Future<void> _loadNonMembers() async {
    try {
      final users = await _adminService.getEnhancedUsersList(
        userType: 'Non-Members',
        filterState: _filterState,
      );
      _usersController.add(users);
    } catch (e) {
      debugPrint('Error loading non-members: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Column(
        children: [
          _buildHeader(),
          _buildConversionFunnel(),
          _buildFilters(),
          Expanded(
            child: _buildNonMembersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Non-Members (Free Users)',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Manage free users and track conversion opportunities',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          _buildHeaderActions(),
        ],
      ),
    );
  }

  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadNonMembers,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _exportConversionData,
          icon: const Icon(Icons.trending_up, size: 18),
          label: const Text('Conversion Report'),
        ),
      ],
    );
  }

  Widget _buildConversionFunnel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildFunnelStep('Signups', '1,234', Icons.person_add, Colors.blue),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFunnelStep('Active Users', '856', Icons.visibility, Colors.green),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFunnelStep('Engaged', '432', Icons.favorite_border, Colors.orange),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFunnelStep('Converted', '123', Icons.star, Colors.purple),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunnelStep(String label, String count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          count,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search non-members...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter by Signup Source',
            onSelected: (value) {
              _updateSignupSourceFilter(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All Sources')),
              const PopupMenuItem(value: 'Organic', child: Text('Organic')),
              const PopupMenuItem(value: 'Referral', child: Text('Referral')),
              const PopupMenuItem(value: 'Social', child: Text('Social')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNonMembersList() {
    return StreamBuilder<List<EnhancedUser>>(
      stream: _usersController.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Failed to load non-members'),
              ],
            ),
          );
        }

        var users = snapshot.data ?? [];
        if (_searchQuery.isNotEmpty) {
          users = users.where((user) =>
              user.username?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false ||
              (user.email?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) as bool).toList();
        }

        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No non-members found'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadNonMembers,
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildNonMemberTile(user);
            },
          ),
        );
      },
    );
  }

  Widget _buildNonMemberTile(EnhancedUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: const Icon(Icons.person, color: Colors.blue),
        ),
        title: Text(
          user.username ?? user.email ?? 'Unknown User',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email ?? ''),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildSignupSourceChip(user.signupSource),
                const SizedBox(width: 8),
                _buildCreditsChip(user.creditsRemaining),
                const SizedBox(width: 8),
                _buildConversionPotentialChip(user),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleNonMemberAction(value, user),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'convert', child: Text('Convert to Member')),
            const PopupMenuItem(value: 'engagement', child: Text('View Engagement')),
            const PopupMenuItem(value: 'referrals', child: Text('View Referrals')),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupSourceChip(String source) {
    Color color;
    switch (source.toLowerCase()) {
      case 'referral':
        color = Colors.green;
        break;
      case 'social':
        color = Colors.purple;
        break;
      case 'organic':
        color = Colors.blue;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        source.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCreditsChip(int credits) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$credits credits',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.orange,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildConversionPotentialChip(EnhancedUser user) {
    final potential = _calculateConversionPotential(user);
    Color color;
    String label;
    
    if (potential > 80) {
      color = Colors.green;
      label = 'High';
    } else if (potential > 50) {
      color = Colors.orange;
      label = 'Medium';
    } else {
      color = Colors.red;
      label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label Potential',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  double _calculateConversionPotential(EnhancedUser user) {
    // Simple conversion potential calculation
    double score = 50; // Base score
    
    if (user.creditsRemaining > 20) score += 20;
    if (user.referralCode != null) score += 15;
    if (user.creditHistory.length > 5) score += 15;
    
    return score;
  }

  void _updateSignupSourceFilter(String source) {
    // TODO: Update filter by signup source
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Filter by $source will be implemented')),
    );
  }

  void _handleNonMemberAction(String action, EnhancedUser user) {
    switch (action) {
      case 'view':
        _showNonMemberDetails(user);
        break;
      case 'convert':
        _convertToMember(user);
        break;
      case 'engagement':
        _showEngagement(user);
        break;
      case 'referrals':
        _showReferrals(user);
        break;
    }
  }

  void _showNonMemberDetails(EnhancedUser user) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Non-Member Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              Text('Name: ${user.username ?? user.fullName ?? "N/A"}'),
              Text('Email: ${user.email ?? "N/A"}'),
              Text('Signup Source: ${user.signupSource}'),
              Text('Credits Remaining: ${user.creditsRemaining}'),
              Text('Conversion Potential: ${_calculateConversionPotential(user).round()}%'),
              if (user.referralCode != null) Text('Referral Code: ${user.referralCode}'),
              Text('Joined: ${user.createdAt.toLocal().toString().split(' ')[0]}'),
            ],
          ),
        ),
      ),
    );
  }

  void _convertToMember(EnhancedUser user) {
    // TODO: Implement conversion to member
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Converting ${user.username} to member...')),
    );
  }

  void _showEngagement(EnhancedUser user) {
    // TODO: Implement engagement view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Engagement view will be implemented')),
    );
  }

  void _showReferrals(EnhancedUser user) {
    // TODO: Implement referral view
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral view will be implemented')),
    );
  }

  void _exportConversionData() {
    // TODO: Implement conversion data export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Conversion report will be generated')),
    );
  }
}