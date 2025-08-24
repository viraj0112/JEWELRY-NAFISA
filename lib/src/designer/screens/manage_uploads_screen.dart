import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageUploadsScreen extends StatefulWidget {
  const ManageUploadsScreen({super.key});

  @override
  State<ManageUploadsScreen> createState() => _ManageUploadsScreenState();
}

class _ManageUploadsScreenState extends State<ManageUploadsScreen> {
  late Future<List<Map<String, dynamic>>> _uploadsFuture;

  @override
  void initState() {
    super.initState();
    _uploadsFuture = _fetchUploads();
  }

  Future<List<Map<String, dynamic>>> _fetchUploads() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final response = await supabase
        .from('assets')
        .select()
        .eq('owner_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _uploadsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          final uploads = snapshot.data!;
          return ListView.builder(
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
                  leading: Image.network(item['media_url'],
                      width: 50, height: 50, fit: BoxFit.cover),
                  title: Text(item['title']),
                  subtitle: Text(
                    "Status: ${item['status']}",
                    style: TextStyle(color: statusColor),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () {
                          // TODO: Implement edit functionality
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          // TODO: Implement delete functionality
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}