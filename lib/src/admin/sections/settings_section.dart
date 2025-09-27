import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/admin/widgets/dashboard_widgets.dart'; // Using StyledCard

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  // TODO: Fetch these initial settings values from Supabase
  TimeOfDay _dailyResetTime = const TimeOfDay(hour: 0, minute: 0);
  final _signupBonusController = TextEditingController(text: '10');
  final _referralBonusController = TextEditingController(text: '5');
  
  @override
  void dispose() {
    _signupBonusController.dispose();
    _referralBonusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
  }

  Widget _buildCreditLogicCard() {
    return StyledCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Credit Logic Configuration', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          _buildTextFieldSetting('Signup Bonus', 'Credits for new users.', _signupBonusController),
          _buildTextFieldSetting('Referral Bonus', 'Credits for successful referrals.', _referralBonusController),
          _buildTimePickerSetting(
            'Daily Reset Time',
            'Time when daily credits are reset (UTC).',
            _dailyResetTime,
            (newTime) {
              if (newTime != null) setState(() => _dailyResetTime = newTime);
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(onPressed: () {/* TODO: Save settings to Supabase */}, child: const Text('Save Credit Settings')),
          )
        ],
      ),
    );
  }
  
  Widget _buildUserRolesCard() {
    // TODO: Fetch user roles from Supabase
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
            child: ElevatedButton(onPressed: () {/* TODO: Navigate to role management page */}, child: const Text('Manage Roles')),
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
          // TODO: Add UI for managing scraper sources, frequency, etc.
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