import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/services/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});
  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  final AdminService _adminService = AdminService();
  Future<Map<String, String>>? _settingsFuture;
  bool _isLoading = false;

  // Controllers for text fields
  final _signupBonusController = TextEditingController();
  final _memberReferralBonusController = TextEditingController();
  final _nonMemberReferralBonusController = TextEditingController();

  // Variable for time picker
  TimeOfDay _dailyResetTime = const TimeOfDay(hour: 0, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    _settingsFuture = _adminService.getSettings();
    _settingsFuture!.then((settings) {
      setState(() {
        _signupBonusController.text = settings['signup_bonus_credits'] ?? '1';
        _memberReferralBonusController.text = settings['referral_bonus_member'] ?? '3';
        _nonMemberReferralBonusController.text = settings['referral_bonus_non_member'] ?? '2';
        
        final timeParts = (settings['daily_reset_time_utc'] ?? '00:00').split(':');
        _dailyResetTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
      });
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      // Create a list of futures to run in parallel
      final List<Future> updateFutures = [];

      updateFutures.add(_adminService.updateSetting('signup_bonus_credits', _signupBonusController.text));
      updateFutures.add(_adminService.updateSetting('referral_bonus_member', _memberReferralBonusController.text));
      updateFutures.add(_adminService.updateSetting('referral_bonus_non_member', _nonMemberReferralBonusController.text));
      
      final newTime = '${_dailyResetTime.hour.toString().padLeft(2, '0')}:${_dailyResetTime.minute.toString().padLeft(2, '0')}';
      updateFutures.add(_adminService.updateSetting('daily_reset_time_utc', newTime));

      // Wait for all updates to complete
      await Future.wait(updateFutures);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  void dispose() {
    _signupBonusController.dispose();
    _memberReferralBonusController.dispose();
    _nonMemberReferralBonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading settings: ${snapshot.error}'));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text('System Settings', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildCreditLogicCard(),
            const SizedBox(height: 24),
            _buildUserRolesCard(),
            const SizedBox(height: 24),
            _buildScraperSettingsCard(),
          ],
        );
      },
    );
  }

  Widget _buildCreditLogicCard() {
    return StyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Credit Logic Configuration', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildTextFieldSetting('Signup Bonus Credits', 'Credits for new users upon signing up.', _signupBonusController),
          _buildTextFieldSetting('Member Referral Bonus', 'Credits for a member when they refer a new user.', _memberReferralBonusController),
          _buildTextFieldSetting('Non-Member Referral Bonus', 'Credits for a non-member when they refer a new user.', _nonMemberReferralBonusController),
          _buildTimePickerSetting(
            'Daily Reset Time (UTC)',
            'Time when daily credits for members are reset.',
            _dailyResetTime,
            (newTime) {
              if (newTime != null) setState(() => _dailyResetTime = newTime);
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveSettings,
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save Credit Settings'),
            ),
          )
        ],
      ),
    );
  }
  
  // ... (The other _build methods like _buildUserRolesCard can remain the same)
  Widget _buildUserRolesCard() {
    final roles = ['Admin', 'Moderator', 'Creator', 'Member', 'Free User'];
    return StyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('User Roles & Permissions', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: roles.map((role) => Chip(label: Text(role))).toList(),
          ),
           const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: () {}, child: const Text('Manage Roles')),
          )
        ],
      ),
    );
  }

  Widget _buildScraperSettingsCard() {
     return StyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scraper Settings', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Scraper Sources'),
            subtitle: const Text('Manage websites to scrape from.'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
           ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Scraping Frequency'),
            subtitle: const Text('Set how often the scrapers run.'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldSetting(String title, String subtitle, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerSetting(String title, String subtitle, TimeOfDay time, Function(TimeOfDay?) onTimeChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () async {
              final newTime = await showTimePicker(context: context, initialTime: time);
              onTimeChanged(newTime);
            },
            child: Text(time.format(context)),
          ),
        ],
      ),
    );
  }
}