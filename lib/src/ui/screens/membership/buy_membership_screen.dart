// lib/src/ui/screens/membership/buy_membership_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BuyMembershipScreen extends StatelessWidget {
  const BuyMembershipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Unlock Premium")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.star_border_purple500_sharp, size: 80, color: Colors.amber),
            const SizedBox(height: 24),
            Text(
              "Become a Lifetime Member",
              textAlign: TextAlign.center,
              style: GoogleFonts.ptSerif(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              "Get exclusive access to features like instant quotes, unlimited boards, and more!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                // TODO: Integrate with your payment provider
                // e.g., launchUrl(Uri.parse('https://members.daginawala.in'));
                print("Redirecting to payment...");
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text(
                "Buy Now - Lifetime Access",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}