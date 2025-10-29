import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';

class JewelryDetailScreen extends StatelessWidget {
  final JewelryItem jewelryItem;

  const JewelryDetailScreen({Key? key, required this.jewelryItem})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
        title: Text(jewelryItem.productTitle),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'jewelry-${jewelryItem.id}', // Unique tag for hero animation
              child: Image.network(
                jewelryItem.image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 300,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jewelryItem.productTitle,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    jewelryItem.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        context.push('/signup');
                      },
                      child: const Text('Sign Up'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
