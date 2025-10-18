import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:provider/provider.dart';

class QuoteHistoryScreen extends StatefulWidget {
  const QuoteHistoryScreen({super.key});

  @override
  State<QuoteHistoryScreen> createState() => _QuoteHistoryScreenState();
}

class _QuoteHistoryScreenState extends State<QuoteHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    // Fetch the history using the provider
    _historyFuture = context.read<UserProfileProvider>().getQuoteHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Quote History'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return const Center(
              child: Text('You have no quote history.'),
            );
          }

          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final quote = history[index];
              final status = quote['status'] as String;
              final expiresAt = DateTime.parse(quote['expires_at'] as String);
              
              Color statusColor;
              switch (status) {
                case 'valid':
                  statusColor = Colors.green;
                  break;
                case 'expired':
                  statusColor = Colors.red;
                  break;
                case 'used':
                  statusColor = Colors.blue;
                  break;
                default:
                  statusColor = Colors.grey;
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text('Product ID: ${quote['product_id']}'),
                  subtitle: Text(
                      'Expires: ${DateFormat.yMMMd().add_jm().format(expiresAt)}'),
                  trailing: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
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