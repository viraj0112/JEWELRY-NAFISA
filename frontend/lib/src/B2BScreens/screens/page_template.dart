import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';

/// Page frame for B2B screens: a small gold eyebrow, a serif title and an
/// optional subtitle above the page content, centred at a comfortable width.
class PageTemplate extends StatelessWidget {
  final String title;
  final Widget child;

  /// Small uppercase label above the title, e.g. "CATALOGUE".
  final String? eyebrow;

  /// One line under the title.
  final String? subtitle;

  /// Widgets aligned to the right of the title (buttons, filters).
  final List<Widget> actions;

  const PageTemplate({
    super.key,
    required this.title,
    required this.child,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              wide ? 32 : 16, wide ? 28 : 18, wide ? 32 : 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (eyebrow != null) ...[
                          Text(eyebrow!.toUpperCase(), style: B2BText.eyebrow()),
                          const SizedBox(height: 6),
                        ],
                        Text(title,
                            style: B2BText.serif(size: wide ? 30 : 24)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(subtitle!,
                              style: B2BText.sans(
                                  size: 13.5, color: B2BColors.muted)),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              const SizedBox(height: 14),
              // Thin gold rule under the header.
              Container(width: 44, height: 2, color: B2BColors.gold),
              const SizedBox(height: 20),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
