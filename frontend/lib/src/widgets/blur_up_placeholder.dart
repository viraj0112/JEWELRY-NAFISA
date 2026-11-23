import 'package:flutter/material.dart';

/// Creates a smooth placeholder widget for image loading
///
/// This provides a smooth loading experience by showing a gentle pulse animation
/// without expensive offscreen blur render passes that can exhaust GPU texture memory.
class BlurUpPlaceholder extends StatefulWidget {
  final Color backgroundColor;
  final Duration animationDuration;

  const BlurUpPlaceholder({
    super.key,
    Color? backgroundColor,
    this.animationDuration = const Duration(milliseconds: 1200),
  }) : backgroundColor = backgroundColor ?? const Color(0xFFE8E8E8);

  @override
  State<BlurUpPlaceholder> createState() => _BlurUpPlaceholderState();
}

class _BlurUpPlaceholderState extends State<BlurUpPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.backgroundColor,
                widget.backgroundColor
                    .withValues(alpha: _opacityAnimation.value),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Helper function to create a blur-up placeholder
///
/// Usage:
/// ```dart
/// CachedNetworkImage(
///   imageUrl: url,
///   placeholder: (context, url) => createBlurUpPlaceholder(),
/// )
/// ```
Widget createBlurUpPlaceholder({
  Color? backgroundColor,
}) {
  return BlurUpPlaceholder(
    backgroundColor: backgroundColor,
  );
}
