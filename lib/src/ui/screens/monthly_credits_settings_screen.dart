import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonthlyCreditsSettingsScreen extends StatefulWidget {
  const MonthlyCreditsSettingsScreen({super.key});

  @override
  State<MonthlyCreditsSettingsScreen> createState() =>
      _MonthlyCreditsSettingsScreenState();
}

class _MonthlyCreditsSettingsScreenState
    extends State<MonthlyCreditsSettingsScreen> {
  final TextEditingController _memberCreditsController =
      TextEditingController();
  final TextEditingController _nonMemberCreditsController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCredits();
  }

  Future<void> _loadCredits() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _memberCreditsController.text = prefs.getString('memberCredits') ?? '';
      _nonMemberCreditsController.text =
          prefs.getString('nonMemberCredits') ?? '';
    });
  }

  Future<void> _saveCredits() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('memberCredits', _memberCreditsController.text);
    await prefs.setString('nonMemberCredits', _nonMemberCreditsController.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monthly credits updated!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Credits Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set Monthly Credits',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _memberCreditsController,
              decoration: const InputDecoration(
                labelText: 'Credits for Members',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nonMemberCreditsController,
              decoration: const InputDecoration(
                labelText: 'Credits for Non-Members',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveCredits,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _memberCreditsController.dispose();
    _nonMemberCreditsController.dispose();
    super.dispose();
  }
}
