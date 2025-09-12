import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/admin_service.dart';
import 'package:jewelry_nafisa/src/admin/models/admin_quote.dart';

class AdminQuotesScreen extends StatelessWidget {
  const AdminQuotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AdminService adminService = AdminService();
    return Scaffold(
      appBar: AppBar(title: const Text('Quotes CRM')),
      body: FutureBuilder<List<AdminQuote>>(
        future: adminService.getQuotes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final quotes = snapshot.data ?? [];
          return ListView.builder(
            itemCount: quotes.length,
            itemBuilder: (context, index) {
              final quote = quotes[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text('Quote from ${quote.userName}'),
                  subtitle: Text(quote.message, maxLines: 2),
                  trailing: Chip(
                    label: Text(quote.status),
                    backgroundColor: quote.status == 'Pending' ? Colors.orange : Colors.green,
                  ),
                  onTap: () { /* Navigate to quote detail */ },
                ),
              );
            },
          );
        },
      ),
    );
  }
}