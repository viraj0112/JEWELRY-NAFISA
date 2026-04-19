import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/creators_provider.dart';

/// Team Member model representing a creator with workload capacity
class TeamMember {
  final String id;
  final String fullName;
  final String? email;
  final String? avatarUrl;
  final String businessType;
  final String? location;
  final int worksCount;
  final int activeProjects;
  final int maxCapacity;
  final String status; // Peak Load, Optimal Flow, Available
  final List<String> specializations;
  final double avgRating;
  final String lastActivity;
  final String latestCommunication;

  TeamMember({
    required this.id,
    required this.fullName,
    this.email,
    this.avatarUrl,
    required this.businessType,
    this.location,
    required this.worksCount,
    required this.activeProjects,
    required this.maxCapacity,
    required this.status,
    required this.specializations,
    required this.avgRating,
    required this.lastActivity,
    required this.latestCommunication,
  });

  /// Calculate available slots
  int get availableSlots => maxCapacity - activeProjects;

  /// Calculate workload percentage
  double get workloadPercent => (activeProjects / maxCapacity) * 100;

  factory TeamMember.fromCreator(CreatorModel creator) {
    // Determine status based on workload
    final workloadPercent = creator.worksCount > 0
        ? (creator.worksCount / 10) * 100 // Assuming 10 is max capacity
        : 0.0;

    String status;
    if (workloadPercent >= 80) {
      status = 'Peak Load';
    } else if (workloadPercent >= 50) {
      status = 'Optimal Flow';
    } else {
      status = 'Available';
    }

    // Parse specializations from business type
    final specializations = _parseSpecializations(creator.businessType);

    // Currently simulating activity & communication logs as placeholders
    // until full integration with ActivityLogsService can be done
    final lastActivity = 'Approved a creator profile 2h ago';
    final latestCommunication = 'Replied to quote request #1024';

    return TeamMember(
      id: creator.id,
      fullName: creator.fullName,
      email: creator.email,
      avatarUrl: creator.avatarUrl,
      businessType: creator.businessType,
      location: creator.location,
      worksCount: creator.worksCount,
      activeProjects:
          creator.worksCount, // Using works count as proxy for active projects
      maxCapacity: 10, // Default max capacity
      status: status,
      specializations: specializations,
      avgRating: creator.avgRating,
      lastActivity: lastActivity,
      latestCommunication: latestCommunication,
    );
  }

  static List<String> _parseSpecializations(String businessType) {
    final type = businessType.toLowerCase();
    final specs = <String>[];

    if (type.contains('3d') || type.contains('model')) {
      specs.add('3D Modeling');
    }
    if (type.contains('sketch') || type.contains('design')) {
      specs.add('Sketch Design');
    }
    if (type.contains('pave') || type.contains('delicate')) {
      specs.add('Pavé Settings');
    }
    if (type.contains('gold') || type.contains('smith')) {
      specs.add('Goldsmithing');
    }
    if (type.contains('cast')) {
      specs.add('Casting');
    }
    if (specs.isEmpty) {
      specs.add('General');
    }

    return specs;
  }
}

class CreatorsTeamsTab extends StatelessWidget {
  final List<CreatorModel> creators;
  const CreatorsTeamsTab({super.key, required this.creators});

  @override
  Widget build(BuildContext context) {
    // Filter to only show admins for the Teams tab
    final adminCreators =
        creators.where((c) => c.role.toLowerCase() == 'admin').toList();

    // Convert admin creators to team members
    final teamMembers =
        adminCreators.map((c) => TeamMember.fromCreator(c)).toList();

    // Sort by status: Peak Load first, then Optimal Flow, then Available
    teamMembers.sort((a, b) {
      final statusOrder = {'Peak Load': 0, 'Optimal Flow': 1, 'Available': 2};
      return statusOrder[a.status]!.compareTo(statusOrder[b.status]!);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with stats
          _buildStatsHeader(teamMembers),
          const SizedBox(height: 16),
          // Team members grid
          Expanded(
            child: teamMembers.isEmpty
                ? const Center(child: Text('No team members found'))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 900;
                      final crossAxisCount = isWide ? 3 : 2;

                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.4,
                        ),
                        itemCount: teamMembers.length +
                            1, // +1 for "Onboard Artisan" card
                        itemBuilder: (context, index) {
                          if (index == teamMembers.length) {
                            return _buildOnboardCard(context);
                          }
                          return _TeamMemberCard(member: teamMembers[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(List<TeamMember> members) {
    final peakLoad = members.where((m) => m.status == 'Peak Load').length;
    final optimalFlow = members.where((m) => m.status == 'Optimal Flow').length;
    final available = members.where((m) => m.status == 'Available').length;
    final totalSlots = members.fold<int>(0, (sum, m) => sum + m.availableSlots);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8E4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              label: 'Peak Load',
              value: '$peakLoad',
              color: const Color(0xFFDC2626),
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFFE0E8E4)),
          Expanded(
            child: _StatItem(
              label: 'Optimal Flow',
              value: '$optimalFlow',
              color: const Color(0xFF059669),
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFFE0E8E4)),
          Expanded(
            child: _StatItem(
              label: 'Available',
              value: '$available',
              color: const Color(0xFF0891B2),
            ),
          ),
          Container(width: 1, height: 40, color: const Color(0xFFE0E8E4)),
          Expanded(
            child: _StatItem(
              label: 'Open Slots',
              value: '$totalSlots',
              color: const Color(0xFF7C3AED),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD1D5DB),
          style: BorderStyle.solid,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showOnboardDialog(context),
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  size: 28,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Onboard Artisan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOnboardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Onboard New Artisan'),
        content: const SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Invite a new artisan to join the team.'),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Specialization',
                  hintText: 'e.g., 3D Modeling, Goldsmithing',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement onboarding logic
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final TeamMember member;

  const _TeamMemberCard({required this.member});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showActivityHistoryDialog(context, member),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with avatar and status
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFDAD7E7),
                      backgroundImage: member.avatarUrl != null
                          ? NetworkImage(member.avatarUrl!)
                          : null,
                      child: member.avatarUrl == null
                          ? Text(
                              _initials(member.fullName),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBgColor(member.status),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              member.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _statusTextColor(member.status),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Specializations
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: member.specializations.take(2).map((spec) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        spec,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const Spacer(),
                // Activity & Communication Logs
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.history,
                            size: 14, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            member.lastActivity,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Latest Communication',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.chat_bubble_outline,
                            size: 14, color: Color(0xFF6B7280)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            member.latestCommunication,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActivityHistoryDialog(BuildContext context, TeamMember member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFFDAD7E7),
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: member.avatarUrl == null
                  ? Text(
                      _initials(member.fullName),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 12,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text('${member.fullName} - Activity History'),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 400,
          child: ListView(
            children: [
              _buildTimelineItem(
                'Today, 10:45 AM',
                'Replied to quote request #1024',
                Icons.chat_bubble_outline,
                const Color(0xFF0891B2),
              ),
              _buildTimelineItem(
                'Today, 09:30 AM',
                'Approved creator profile: Rajika Saha',
                Icons.check_circle_outline,
                const Color(0xFF059669),
              ),
              _buildTimelineItem(
                'Yesterday, 04:15 PM',
                'Assigned 3D modeling task to Sofia Valerius',
                Icons.assignment_outlined,
                const Color(0xFF7C3AED),
              ),
              _buildTimelineItem(
                'Yesterday, 11:20 AM',
                'Updated metal pricing catalog',
                Icons.price_change_outlined,
                const Color(0xFFDC2626),
              ),
              _buildTimelineItem(
                'Mar 16, 02:00 PM',
                'Sent notification to 15 pending designers',
                Icons.notifications_outlined,
                const Color(0xFFD97706),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
      String time, String action, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Container(
                width: 2,
                height: 40,
                color: const Color(0xFFE5E7EB),
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'Peak Load':
        return const Color(0xFFFEE2E2);
      case 'Optimal Flow':
        return const Color(0xFFD1FAE5);
      case 'Available':
        return const Color(0xFFCFFAFE);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'Peak Load':
        return const Color(0xFFDC2626);
      case 'Optimal Flow':
        return const Color(0xFF059669);
      case 'Available':
        return const Color(0xFF0891B2);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}
