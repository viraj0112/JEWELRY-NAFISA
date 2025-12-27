import 'package:flutter/material.dart';

class StaticInfoScreen extends StatelessWidget {
  const StaticInfoScreen({super.key});

  final Color customGreen = const Color(0xFF336B43);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        final maxWidth = isWide ? 600.0 : double.infinity;
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60.0),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
            // --- SECTION 1: ABOUT ---
            const Text(
              "What is Dagina.Design about?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "A Jewelry Inspiration Platform",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              "Find your perfect jewellery!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "With Dagina.Designs, you can find the ultimate jewellery piece you were looking for, we help you find more inspiration.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildImage('assets/icons/info1.png'),

            // --- SECTION 2: PRODUCT DETAILS ---
            const SizedBox(height: 50),
            const Text(
              "Get Product Details",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Get product details like gold weight, stone used etc. On Clicking on Get Details",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildImage('assets/icons/info21.png'),

            // --- SECTION 3: TECHNICAL DETAILS (DARK STYLE) ---

            // --- SECTION 4: QUOTE ---
            const SizedBox(height: 50),
            const Text(
              "Get a Quote By Clicking Below",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Get product Quote by Clicking Below",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            _buildImage('assets/icons/infoquote.png'),
            const SizedBox(height: 20),
            const Text(
              "Fill the Request Quote Form to get an estimate price",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Get product Quote by Clicking Below",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),

            // --- SECTION 5: FINAL ---
            const SizedBox(height: 50),
            _buildImage('assets/icons/info3.png'),
            const SizedBox(height: 30),
            const Text(
              "We will Get Back to you soon!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper to keep images consistent
  Widget _buildImage(String path) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(path, fit: BoxFit.contain),
      ),
    );
  }
}