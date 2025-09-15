import 'package:flutter/material.dart';
import 'dart:math';

class AnimatedCreditIndicator extends StatefulWidget {
  final int currentCredits;
  final int totalCredits;

  const AnimatedCreditIndicator({
    super.key,
    required this.currentCredits,
    required this.totalCredits,
  });

  @override
  State<AnimatedCreditIndicator> createState() =>
      _AnimatedCreditIndicatorState();
}

class _AnimatedCreditIndicatorState extends State<AnimatedCreditIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedCreditIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCredits != oldWidget.currentCredits) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double progress = widget.totalCredits > 0
        ? widget.currentCredits / widget.totalCredits
        : 0.0;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _CreditPainter(
            progress: progress * _animation.value,
            color: Theme.of(context).colorScheme.primary,
          ),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Center(
              child: Text(
                '${widget.currentCredits}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CreditPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CreditPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);

    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawArc(rect, -pi / 2, 2 * pi, false, backgroundPaint);

    final foregroundPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}