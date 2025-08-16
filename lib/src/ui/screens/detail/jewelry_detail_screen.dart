// lib/src/ui/screens/detail/jewelry_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jewelry_nafisa/src/providers/user_profile_provider.dart';
import 'package:jewelry_nafisa/src/ui/screens/membership/buy_membership_screen.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JewelryDetailScreen extends StatelessWidget {
  final String imageUrl;
  final String itemName;

  const JewelryDetailScreen({
    super.key,
    required this.imageUrl,
    required this.itemName,
  });

  // Re-using the quote logic from your HomeScreen
  void _onGetQuotePressed(BuildContext context) {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);

    if (profile.isMember) {
      if (profile.creditsRemaining > 0) {
        _useQuoteCredit(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are out of quotes for today!')),
        );
      }
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Member Exclusive"),
          content: const Text(
            "Getting a quote is a premium feature available only to lifetime members.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Maybe Later"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BuyMembershipScreen(),
                  ),
                );
              },
              child: const Text("Upgrade Now"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _useQuoteCredit(BuildContext context) async {
    final profile = Provider.of<UserProfileProvider>(context, listen: false);
    final supabase = Supabase.instance.client;
    try {
      await supabase.rpc('decrement_credit');
      profile.decrementCredit();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quote request sent! One credit used.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get quote. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(itemName),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Image
            Image.network(imageUrl, fit: BoxFit.cover, width: 400, height: 500),

            // Item Title & Actions
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Image', // Image Name
                        style: GoogleFonts.ptSerif(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.bookmark_border),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Get Quote s
                  SizedBox(
                    width: 300,
                    child: ElevatedButton(
                      onPressed: () => _onGetQuotePressed(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Get Quote',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),

            const Divider(),

            // Description and Specifications
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Description",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "A sleek modern circular ring in gold.\nItem Code: 123456",
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Specifications",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildSpecRow("Material", "Gold"),
                  _buildSpecRow("Style", "Modern"),
                  _buildSpecRow("Occasion", "Bridal"),
                  _buildSpecRow("Karat", "13 k"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
