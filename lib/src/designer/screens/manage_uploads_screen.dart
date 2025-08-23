import 'package:flutter/material.dart';

class ManageUploadsScreen extends StatelessWidget {
  const ManageUploadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder data
    final List<Map<String, String>> uploads = [
      {'title': 'Gold Necklace', 'status': 'Approved', 'image': 'https://picsum.photos/seed/1/200'},
      {'title': 'Diamond Ring', 'status': 'Pending', 'image': 'https://picsum.photos/seed/2/200'},
      {'title': 'Silver Bracelet', 'status': 'Rejected', 'image': 'https://picsum.photos/seed/3/200'},
    ];

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: uploads.length,
        itemBuilder: (context, index) {
          final item = uploads[index];
          final statusColor = item['status'] == 'Approved'
              ? Colors.green
              : item['status'] == 'Pending'
              ? Colors.orange
              : Colors.red;

          return Card(
            child: ListTile(
              leading: Image.network(item['image']!, width: 50, height: 50, fit: BoxFit.cover),
              title: Text(item['title']!),
              subtitle: Text("Status: ${item['status']!}", style: TextStyle(color: statusColor)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {}),
                  IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}