import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/services/jewelry_service.dart';
import 'package:provider/provider.dart';

class QuoteWithProduct {
  final Map<String, dynamic> quote;
  final JewelryItem? product;

  QuoteWithProduct({required this.quote, this.product});
}

class QuoteHistoryScreen extends StatefulWidget {
  const QuoteHistoryScreen({super.key});

  @override
  State<QuoteHistoryScreen> createState() => _QuoteHistoryScreenState();
}

class _QuoteHistoryScreenState extends State<QuoteHistoryScreen> {
  late Future<List<QuoteWithProduct>> _historyFuture;

  @override
  void initState() {
    super.initState();

    _historyFuture = _fetchQuoteHistoryWithProducts();
  }

  Future<List<QuoteWithProduct>> _fetchQuoteHistoryWithProducts() async {
    final userProfileProvider = context.read<UserProfileProvider>();
    final jewelryService = context.read<JewelryService>();

    // 1. Fetch quote history
    final history = await userProfileProvider.getQuoteHistory();
    if (history.isEmpty) {
      return [];
    }

    // 2. Create a list of futures to fetch each product
    final productFutures = history.map((quote) {
      final productId = quote['product_id']?.toString();
      if (productId != null) {
        return jewelryService.getJewelryItem(productId);
      }
      // Return a future that resolves to null if no product ID
      return Future.value(null);
    }).toList();

    // 3. Wait for all product fetch operations to complete
    final products = await Future.wait(productFutures);

    // 4. Zip the history and products lists together
    List<QuoteWithProduct> combinedList = [];
    for (int i = 0; i < history.length; i++) {
      combinedList
          .add(QuoteWithProduct(quote: history[i], product: products[i]));
    }

    return combinedList;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
        title: const Text('My Quote History'),
      ),
      // Update FutureBuilder type
      body: FutureBuilder<List<QuoteWithProduct>>(
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
              final combinedItem = history[index];
              final quote = combinedItem.quote;
              final product = combinedItem.product;

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
                  leading: product != null && product.image.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4.0),
                          child: Image.network(
                            product.image,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      )),
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 50),
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          child:
                              const Icon(Icons.image_not_supported, size: 30),
                        ),
                  title: Text(
                    product?.productTitle ??
                        'Product ID: ${quote['product_id']}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                      'Expires: ${DateFormat.yMMMd().add_jm().format(expiresAt)}'),
                  trailing: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    _showQuoteDetailsPopup(context, quote, product);
                  },
                ),
              );
            },
          );
        },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Flexible(child: Text(value)),
        ],
      ),
    );
  }

  void _showQuoteDetailsPopup(
      BuildContext context, Map<String, dynamic> quote, JewelryItem? product) {
    final status = quote['status'] as String;
    final expiresAt = DateTime.parse(quote['expires_at'] as String);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(product?.productTitle ?? 'Quote Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                if (product != null && product.image.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        product.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator()),
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 100),
                      ),
                    ),
                  ),

                _buildDetailRow('Product Name', product?.productTitle ?? 'N/A'),

                //
                // --- FIX #1: PREVENTS THE CRASH ---
                // This call is now null-safe.
                _buildDetailRow(
                    'Product ID', quote['product_id']?.toString() ?? 'N/A'),

                _buildDetailRow('Quote Status', status.toUpperCase()),
                _buildDetailRow(
                    'Expires', DateFormat.yMMMd().add_jm().format(expiresAt)),

                if (product != null) ...[
                  const Divider(height: 20),
                  // _buildDetailRow('Description', product.description),
                  if (product.price != null)
                    _buildDetailRow(
                        'Price', '₹${product.price!.toStringAsFixed(2)}'),
                  _buildDetailRow('Metal Type', product.metalType ?? 'N/A'),
                  _buildDetailRow('Metal Purity', product.metalPurity ?? 'N/A'),
                  _buildDetailRow('Gold Weight', product.goldWeight ?? 'N/A'),
                  _buildDetailRow(
                      'Stone Type', product.stoneType?.join(', ') ?? 'N/A'),
                  _buildDetailRow(
                      'Stone Count', product.stoneCount?.join(', ') ?? 'N/A'),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
