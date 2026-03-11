import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Creates a blur-up (LQIP) placeholder widget for image loading
/// 
/// This provides a smooth loading experience by showing an animated
/// blurred background that simulates progressive image loading
class BlurUpPlaceholder extends StatefulWidget {
  final Color backgroundColor;
  final Duration animationDuration;

  const BlurUpPlaceholder({
    Key? key,
    Color? backgroundColor,
    this.animationDuration = const Duration(milliseconds: 400),
  })  : backgroundColor = backgroundColor ?? const Color(0xFFE8E8E8),
        super(key: key);

  @override
  State<BlurUpPlaceholder> createState() => _BlurUpPlaceholderState();
}

class _BlurUpPlaceholderState extends State<BlurUpPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _blurAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Blur animation: gradually reduce blur from 15 to 0
    _blurAnimation = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _blurAnimation,
      builder: (context, child) {
        return AnimatedOpacity(
          opacity: _blurAnimation.value > 0.1 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 100),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: _blurAnimation.value,
              sigmaY: _blurAnimation.value,
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.backgroundColor,
                    widget.backgroundColor.withOpacity(0.6),
                  ],
                ),
              ),
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
