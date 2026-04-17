import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/new_admin_models.dart';
import '../services/new_admin_data_service.dart';
import '../widgets/admin_skeletons.dart';

class SystemControlsScreen extends StatefulWidget {
  const SystemControlsScreen({
    super.key,
    required this.settings,
    required this.dateFormat,
    required this.dataService,
    required this.onRefreshRequested,
  });

  final List<SystemSetting> settings;
  final DateFormat dateFormat;
  final NewAdminDataService dataService;
  final VoidCallback onRefreshRequested;

  @override
  State<SystemControlsScreen> createState() => _SystemControlsScreenState();
}

class _SystemControlsScreenState extends State<SystemControlsScreen> {
  late final TextEditingController _memberCreditsController;
  late final TextEditingController _nonMemberCreditsController;
  // Controller for admin-configurable credit deduction per click (default 5)
  late final TextEditingController _creditDeductionController;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  // Controllers for specific user targeting (username, email, phone)
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  String _audience = 'manufacturers';
  String _scheduleMode = 'immediate';
  String _urgencyLevel = 'standard';
  DateTime? _customScheduleAt;
  bool _savingSettings = false;
  bool _sendingBroadcast = false;
  final List<String> _recentActions = [];
  List<Map<String, dynamic>> _dbLedger = const [];
  bool _loadingLedger = true;
  // State for specific user search and selection
  List<Map<String, dynamic>> _userSearchResults = [];
  String? _selectedUserId;

  // Added: Method to save credit settings (including credit deduction amount)
  Future<void> _saveCreditSettings() async {
    final member = int.tryParse(_memberCreditsController.text.trim());
    final nonMember = int.tryParse(_nonMemberCreditsController.text.trim());
    if (member == null || nonMember == null || member < 0 || nonMember < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid credit values')),
      );
      return;
    }

    setState(() => _savingSettings = true);
    try {
      // Prepare settings map including credit deduction amount
      final settingsMap = {
        'monthly_member_credits': '$member',
        'monthly_non_member_credits': '$nonMember',
        // Persist the admin-configurable credit deduction per click
        'credit_deduction_amount':
            _creditDeductionController.text.trim().isNotEmpty
                ? _creditDeductionController.text.trim()
                : '5',
      };
      await widget.dataService.upsertSystemSettings(settingsMap);

      // Also update individual user credits
      await widget.dataService.refreshAllUserCredits(
        memberCredits: member,
        nonMemberCredits: nonMember,
      );

      if (!mounted) return;
      setState(() {
        _recentActions.insert(
          0,
          'Treasury update: Members $member, External $nonMember credits',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Treasury parameters updated')),
      );
      widget.onRefreshRequested();
      _loadLedger();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      if (message.contains('42501')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permission denied by database policy while updating settings. '
              'Please allow admin update on settings keys.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  // Added: Method to search for specific users based on entered criteria
  Future<void> _searchSpecificUsers() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    // Use the data service to search users; null values are ignored
    final results = await widget.dataService.searchUsers(
      username: username.isNotEmpty ? username : null,
      email: email.isNotEmpty ? email : null,
      phone: phone.isNotEmpty ? phone : null,
    );
    setState(() {
      _userSearchResults = results;
      _selectedUserId = null;
    });
  }

  // Added: Method to send broadcast (including specific user handling)
  Future<void> _sendBroadcast() async {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject and message are required')),
      );
      return;
    }

    setState(() => _sendingBroadcast = true);
    try {
      int recipients = 0;
      if (_audience == 'specific_users') {
        // Determine which user IDs to target
        final List<String> ids = [];
        if (_selectedUserId != null) {
          ids.add(_selectedUserId!);
        } else {
          // If no specific selection, broadcast to all search results
          ids.addAll(_userSearchResults.map((u) => u['id'] as String));
        }
        recipients = await widget.dataService.broadcastToSpecificUsers(
          userIds: ids,
          subject: subject,
          body: body,
          urgency: _urgencyLevel,
          scheduledFor: _effectiveScheduleTime(),
        );
      } else {
        recipients = await widget.dataService.broadcastNotification(
          audience: _audience,
          subject: subject,
          body: body,
          urgency: _urgencyLevel,
          scheduledFor: _effectiveScheduleTime(),
        );
      }
      if (!mounted) return;
      setState(() {
        _recentActions.insert(
          0,
          'Broadcast "$subject" queued for $recipients recipients (${_scheduleLabel(_scheduleMode)}).',
        );
        _subjectController.clear();
        _bodyController.clear();
        if (_audience == 'specific_users') {
          // Reset specific user fields after broadcast
          _usernameController.clear();
          _emailController.clear();
          _phoneController.clear();
          _userSearchResults = [];
          _selectedUserId = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Broadcast sent to $recipients users')),
      );
      _loadLedger();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Broadcast failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingBroadcast = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _memberCreditsController = TextEditingController(
      text: _settingValue(
          ['monthly_member_credits', 'member_monthly_credits'], '5000'),
    );
    _nonMemberCreditsController = TextEditingController(
      text: _settingValue(
        ['monthly_non_member_credits', 'non_member_monthly_credits'],
        '1200',
      ),
    );
    _creditDeductionController = TextEditingController(
      text: _settingValue(['credit_deduction_amount'], '5'),
    );
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _loadLedger();
  }

  @override
  void dispose() {
    _memberCreditsController.dispose();
    _nonMemberCreditsController.dispose();
    _creditDeductionController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String _settingValue(List<String> keys, String fallback) {
    for (final key in keys) {
      final match = widget.settings.where((s) => s.key == key);
      if (match.isNotEmpty && match.first.value.trim().isNotEmpty) {
        return match.first.value.trim();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _HeaderBlock(),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            if (stacked) {
              return Column(
                children: [
                  _buildCreditsColumn(),
                  const SizedBox(height: 12),
                  _buildBroadcastPanel(),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildCreditsColumn()),
                const SizedBox(width: 12),
                Expanded(flex: 7, child: _buildBroadcastPanel()),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _buildCreditsColumn() {
    return Column(
      children: [
        _buildCreditsPanel(),
        const SizedBox(height: 10),
        _buildReserveCard(),
        const SizedBox(height: 10),
        _buildLogoutCard(),
      ],
    );
  }

  Widget _buildCreditsPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Global Credit Values',
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF242B28),
                  ),
                ),
              ),
              CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFFE1EFE8),
                child: Icon(Icons.attach_money,
                    size: 14, color: Color(0xFF0A4F3F)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CreditLineInput(
            label: 'TIER 1: MEMBER',
            controller: _memberCreditsController,
          ),
          const SizedBox(height: 10),
          _CreditLineInput(
            label: 'TIER 2: NON-MEMBERS',
            controller: _nonMemberCreditsController,
          ),
          const SizedBox(height: 10),
          // Credit deduction per click input
          _CreditLineInput(
            label: 'CREDIT DEDUCTION PER CLICK',
            controller: _creditDeductionController,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _savingSettings ? null : _saveCreditSettings,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: Text(
                _savingSettings ? 'Updating...' : 'Update Treasury Parameters',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF034033),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReserveCard() {
    final member = int.tryParse(_memberCreditsController.text.trim()) ?? 0;
    final nonMember =
        int.tryParse(_nonMemberCreditsController.text.trim()) ?? 0;
    final reserve = (member * 30) + (nonMember * 120);

    return Container(
      height: 146,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A4D41), Color(0xFF275A4D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF0E3B33).withValues(alpha: 0.28),
              ),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAILABLE RESERVE',
                  style: TextStyle(
                    color: Color(0xFFC0DCCE),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  NumberFormat.decimalPattern('en_IN').format(reserve),
                  style: const TextStyle(
                    color: Color(0xFFE9C96E),
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
                const Text(
                  'unallocated',
                  style: TextStyle(
                    color: Color(0xFFE7EFEA),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  Widget _buildLogoutCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Session',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF242B28),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Securely end your administrative session. You will be required to log in again to access the dashboard.',
            style: TextStyle(fontSize: 12, color: Color(0xFF5A6A64)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Log Out Safely'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastPanel() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E6E4)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 13,
                backgroundColor: Color(0xFFE9C96E),
                child: Icon(Icons.campaign, size: 14, color: Color(0xFF2D260F)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Push Broadcast Editor',
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF242B28),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC4F0D8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'LIVE EDITOR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D6C48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Reach your global ecosystem instantly.',
            style: TextStyle(color: Color(0xFF5A6A64), fontSize: 13),
          ),
          const SizedBox(height: 14),
          const Text(
            'AUDIENCE TARGETING',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667772),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _audienceChip('all_users', 'All Users'),
              _audienceChip('manufacturers', 'All Manufacturers'),
              _audienceChip('verified_gemologists', 'Verified Gemologists'),
              _audienceChip('new_onboardings', 'New Onboardings'),
              _audienceChip('specific_users', 'Specific Users'),
            ],
          ),
          // Input fields for specific user targeting when audience is specific_users
          if (_audience == 'specific_users') ...[
            const SizedBox(height: 8),
            const Text(
              'USERNAME (optional)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667772),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                hintText: 'e.g., johndoe',
                filled: true,
                fillColor: Color(0xFFEDEEED),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'EMAIL ID',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667772),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: 'e.g., user@example.com',
                filled: true,
                fillColor: Color(0xFFEDEEED),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'PHONE NUMBER (optional)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667772),
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                hintText: 'e.g., +1234567890',
                filled: true,
                fillColor: Color(0xFFEDEEED),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
            // Button to search for matching users
            ElevatedButton(
              onPressed: _searchSpecificUsers,
              child: const Text('Search Users'),
            ),
            const SizedBox(height: 8),
            // Dropdown to select a user from search results
            if (_userSearchResults.isNotEmpty)
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Select User'),
                value: _selectedUserId,
                items: _userSearchResults
                    .map((u) => DropdownMenuItem<String>(
                          value: u['id'] as String?,
                          child: Text(
                            '${u['username'] ?? u['email'] ?? 'User'}',
                          ),
                        ))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedUserId = val);
                },
              ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 14),
          const Text(
            'SUBJECT LINE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667772),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              hintText: 'e.g., Seasonal Diamond Allocation Update',
              isDense: true,
              filled: true,
              fillColor: Color(0xFFF9FAF9),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'MESSAGE BODY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667772),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _bodyController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Craft your message with precision...',
              filled: true,
              fillColor: Color(0xFFEDEEED),
              contentPadding: EdgeInsets.all(10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _metaSelector(
                  label: 'SCHEDULE DELIVERY',
                  value: _scheduleLabel(_scheduleMode),
                  options: const [
                    _OptionItem('immediate', 'Immediate Dispatch'),
                    _OptionItem('in_1h', 'In 1 hour'),
                    _OptionItem('today_6pm', 'Today 6:00 PM'),
                    _OptionItem('custom', 'Custom Date & Time'),
                  ],
                  onSelected: (value) async {
                    if (value == 'custom') {
                      final picked = await _pickCustomSchedule();
                      if (picked == null) return;
                      setState(() {
                        _scheduleMode = value;
                        _customScheduleAt = picked;
                      });
                      return;
                    }
                    setState(() {
                      _scheduleMode = value;
                      _customScheduleAt = null;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metaSelector(
                  label: 'URGENCY LEVEL',
                  value: _urgencyLabel(_urgencyLevel),
                  options: const [
                    _OptionItem('silent', 'Silent'),
                    _OptionItem('standard', 'Standard'),
                    _OptionItem('high', 'High Priority'),
                  ],
                  onSelected: (value) {
                    setState(() => _urgencyLevel = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _showBroadcastPreview,
                child: const Text('Preview on Mobile'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _sendingBroadcast ? null : _sendBroadcast,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFA77E13),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(180, 42),
                ),
                child: Text(
                  _sendingBroadcast ? 'Broadcasting...' : 'Broadcast Message',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaSelector({
    required String label,
    required String value,
    required List<_OptionItem> options,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEEED),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF687A74),
            ),
          ),
          const SizedBox(height: 6),
          PopupMenuButton<String>(
            onSelected: onSelected,
            itemBuilder: (context) => options
                .map(
                  (item) => PopupMenuItem<String>(
                    value: item.value,
                    child: Text(item.label),
                  ),
                )
                .toList(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _audienceChip(String value, String label) {
    final selected = _audience == value;
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _audience = value),
      selectedColor: const Color(0xFFA77E13),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF34463F),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFFA77E13) : const Color(0xFFA7B1AD),
      ),
      backgroundColor: const Color(0xFFF8F9F8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildRecentActivity() {
    final now = DateTime.now();
    final runtimeLogs = _recentActions
        .map(
          (entry) => _ActivityTile(
            title: entry,
            subtitle: DateFormat('MMM d, h:mm a').format(now),
            status: 'SUCCESS',
            statusColor: const Color(0xFF17603A),
          ),
        )
        .toList();

    final dbTiles = _dbLedger.map((entry) {
      final when = _formatLedgerTime(entry['timestamp']);
      final status = (entry['status'] as String?) ?? 'SYSTEM';
      final color = _ledgerStatusColor(status);
      return _ActivityTile(
        title: (entry['title'] as String?) ?? 'System event',
        subtitle: when,
        status: status,
        statusColor: color,
      );
    }).toList();

    final tiles = [...runtimeLogs, ...dbTiles];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Administrative Ledger',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w500,
                color: Color(0xFF242B28),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: _showFullArchive,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'View Full Archive ->',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5A6A64),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            if (_loadingLedger && tiles.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              );
            }
            final columns = constraints.maxWidth > 1100
                ? 3
                : constraints.maxWidth > 700
                    ? 2
                    : 1;
            final content = tiles.take(6).toList();
            if (content.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No administrative activity recorded yet.',
                  style: TextStyle(color: Color(0xFF6B7B75)),
                ),
              );
            }
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: columns == 1 ? 3.1 : 2.3,
              children: content,
            );
          },
        ),
      ],
    );
  }

  String _scheduleLabel(String mode) {
    switch (mode) {
      case 'in_1h':
        return 'In 1 hour';
      case 'today_6pm':
        return 'Today 6:00 PM';
      case 'custom':
        if (_customScheduleAt != null) {
          return DateFormat('MMM d, h:mm a').format(_customScheduleAt!);
        }
        return 'Custom Date & Time';
      case 'immediate':
      default:
        return 'Immediate Dispatch';
    }
  }

  String _urgencyLabel(String mode) {
    switch (mode) {
      case 'silent':
        return 'Silent';
      case 'high':
        return 'High Priority';
      case 'standard':
      default:
        return 'Standard';
    }
  }

  DateTime? _effectiveScheduleTime() {
    final now = DateTime.now();
    switch (_scheduleMode) {
      case 'in_1h':
        return now.add(const Duration(hours: 1));
      case 'today_6pm':
        final today6 = DateTime(now.year, now.month, now.day, 18);
        return today6.isAfter(now)
            ? today6
            : today6.add(const Duration(days: 1));
      case 'custom':
        return _customScheduleAt;
      case 'immediate':
      default:
        return null;
    }
  }

  Future<DateTime?> _pickCustomSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 10))),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _showBroadcastPreview() {
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast Preview'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Audience: ${_audience.replaceAll('_', ' ')}'),
              Text('Schedule: ${_scheduleLabel(_scheduleMode)}'),
              Text('Urgency: ${_urgencyLabel(_urgencyLevel)}'),
              const SizedBox(height: 10),
              Text(
                subject,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(body),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLedger() async {
    setState(() => _loadingLedger = true);
    try {
      final rows = await widget.dataService.fetchRecentAdminLedger(limit: 12);
      if (!mounted) return;
      setState(() => _dbLedger = rows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _dbLedger = const []);
    } finally {
      if (mounted) setState(() => _loadingLedger = false);
    }
  }

  Future<void> _showFullArchive() async {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.dataService.fetchRecentAdminLedger(limit: 200),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                content: SizedBox(
                  width: 760,
                  height: 520,
                  child: AdminSkeletonView(
                    variant: AdminSkeletonVariant.list,
                    padding: EdgeInsets.zero,
                  ),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Full Archive'),
                content: Text('Failed to load archive: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ],
              );
            }

            final dbRows = snapshot.data ?? const [];
            final runtimeRows = _recentActions
                .map(
                  (entry) => {
                    'title': entry,
                    'timestamp': DateTime.now().toIso8601String(),
                    'status': 'SUCCESS',
                  },
                )
                .toList();
            final rows = [...runtimeRows, ...dbRows];

            return AlertDialog(
              title: const Text('Full Archive'),
              content: SizedBox(
                width: 760,
                height: 520,
                child: rows.isEmpty
                    ? const Center(
                        child: Text('No archive records found.'),
                      )
                    : ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final row = rows[index];
                          final status = (row['status'] as String?) ?? 'SYSTEM';
                          final color = _ledgerStatusColor(status);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            title: Text(
                              (row['title'] as String?) ?? 'System event',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(_formatLedgerTime(row['timestamp'])),
                            trailing: Text(
                              status,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color,
                                fontSize: 11,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatLedgerTime(dynamic value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return DateFormat('MMM d, hh:mm a').format(parsed);
      }
    } else if (value is DateTime) {
      return DateFormat('MMM d, hh:mm a').format(value);
    }
    return '-';
  }

  Color _ledgerStatusColor(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('error')) return const Color(0xFFBA1A1A);
    if (normalized.contains('high') || normalized.contains('opportunity')) {
      return const Color(0xFFA77E13);
    }
    if (normalized.contains('success') || normalized.contains('default')) {
      return const Color(0xFF17603A);
    }
    return const Color(0xFF0A4F3F);
  }
}

class _OptionItem {
  const _OptionItem(this.value, this.label);
  final String value;
  final String label;
}

class _HeaderBlock extends StatelessWidget {
  const _HeaderBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Controls',
          style: TextStyle(
            fontSize: 56,
            height: 1.05,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1F2523),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage global treasury allocations and orchestrate multi-channel communications to your\nartisan network.',
          style: TextStyle(color: Color(0xFF586963), fontSize: 16, height: 1.3),
        ),
      ],
    );
  }
}

class _CreditLineInput extends StatelessWidget {
  const _CreditLineInput({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 10,
            letterSpacing: 0.7,
            color: Color(0xFF6A7A74),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            suffixText: 'credits / mo',
            suffixStyle: TextStyle(
              fontSize: 13,
              color: Color(0xFF6C7D77),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
  });

  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F4),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: statusColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7B75),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF2C3733),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.circle, size: 8, color: statusColor),
              const SizedBox(width: 6),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
