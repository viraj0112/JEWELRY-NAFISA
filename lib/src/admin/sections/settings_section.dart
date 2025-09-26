import 'package:flutter/material.dart';

class SettingsSection extends StatefulWidget {
  const SettingsSection({super.key});

  @override
  State<SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<SettingsSection> {
  bool emailNotifications = true;
  bool pushNotifications = false;
  bool twoFactorAuth = true;
  String selectedTheme = 'light';
  String selectedLanguage = 'english';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          
          // General Settings
          _buildSettingsCard(
            'General Settings',
            [
              _buildSwitchSetting(
                'Email Notifications',
                'Receive notifications via email',
                emailNotifications,
                (value) => setState(() => emailNotifications = value),
              ),
              _buildSwitchSetting(
                'Push Notifications',
                'Receive push notifications',
                pushNotifications,
                (value) => setState(() => pushNotifications = value),
              ),
              _buildDropdownSetting(
                'Theme',
                'Choose your preferred theme',
                selectedTheme,
                ['light', 'dark', 'auto'],
                (value) => setState(() => selectedTheme = value!),
              ),
              _buildDropdownSetting(
                'Language',
                'Select your language',
                selectedLanguage,
                ['english', 'spanish', 'french', 'german'],
                (value) => setState(() => selectedLanguage = value!),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Security Settings
          _buildSettingsCard(
            'Security',
            [
              _buildSwitchSetting(
                'Two-Factor Authentication',
                'Add an extra layer of security',
                twoFactorAuth,
                (value) => setState(() => twoFactorAuth = value),
              ),
              _buildActionSetting(
                'Change Password',
                'Update your account password',
                'Change',
                () {},
              ),
              _buildActionSetting(
                'Download Data',
                'Export your account data',
                'Download',
                () {},
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // API Settings
          _buildSettingsCard(
            'API Configuration',
            [
              _buildTextFieldSetting(
                'API Key',
                'Your API key for integrations',
                '••••••••••••••••',
              ),
              _buildActionSetting(
                'Regenerate API Key',
                'Generate a new API key',
                'Regenerate',
                () {},
              ),
              _buildTextFieldSetting(
                'Webhook URL',
                'URL for webhook notifications',
                'https://your-domain.com/webhook',
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Danger Zone
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danger Zone',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delete Account',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'This action cannot be undone',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchSetting(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting(String title, String subtitle, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option.toUpperCase()),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSetting(String title, String subtitle, String buttonText, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onPressed,
            child: Text(buttonText),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldSetting(String title, String subtitle, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: TextEditingController(text: value),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}