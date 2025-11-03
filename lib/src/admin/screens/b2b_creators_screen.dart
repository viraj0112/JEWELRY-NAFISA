import 'package:flutter/material.dart';

class B2BCreatorsScreen extends StatelessWidget {
  const B2BCreatorsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'B2B Creators',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text('Manage B2B creators and their uploads'),
            // TODO: Implement B2B creators management
          ],
        ),
      ),
    );
  }
}
