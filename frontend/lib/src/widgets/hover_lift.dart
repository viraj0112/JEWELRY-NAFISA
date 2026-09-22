import 'package:flutter/material.dart';

/// Lifts its child a few pixels and deepens the shadow while the pointer is
/// over it. Hover state lives here, so only this card rebuilds - not the whole
/// grid around it. [builder] also receives the hover flag for inner effects
/// such as a gentle image zoom. On touch devices it simply never hovers.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.builder,
    this.lift = 4,
    this.radius = 18,
    this.restShadow = const [],
    this.hoverShadow = const [],
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final double lift;
  final double radius;
  final List<BoxShadow> restShadow;
  final List<BoxShadow> hoverShadow;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovered = false;

  void _set(bool value) {
    if (_hovered != value) setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _set(true),
      onExit: (_) => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _hovered ? -widget.lift : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: _hovered ? widget.hoverShadow : widget.restShadow,
        ),
        child: widget.builder(context, _hovered),
      ),
    );
  }
}
