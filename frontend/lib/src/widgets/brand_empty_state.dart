import 'package:flutter/material.dart';

import '../B2BScreens/b2b_theme.dart';

/// Centred gold-circle icon, serif title and a short line - the classic
/// empty state used on the customer home screens.
class BrandEmptyState extends StatelessWidget {
  const BrandEmptyState({
    super.key,
    this.icon = Icons.diamond_outlined,
    required this.title,
    this.message,
  });

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: B2BColors.goldSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: B2BColors.gold),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center, style: B2BText.serif(size: 22)),
            if (message != null) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(message!,
                    textAlign: TextAlign.center,
                    style: B2BText.sans(size: 13.5, color: B2BColors.muted)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
