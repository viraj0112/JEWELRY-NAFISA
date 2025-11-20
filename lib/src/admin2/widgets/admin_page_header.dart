import 'package:flutter/material.dart';

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;

  const AdminPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        final textTheme = Theme.of(context).textTheme;

        Widget buildTitleBlock() {
          final titleWidget = Text(
            title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          );

          final subtitleWidget = subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                );

          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              if (subtitleWidget != null) ...[
                const SizedBox(height: 6),
                subtitleWidget,
              ],
            ],
          );

          if (leading == null) return column;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading!,
                const SizedBox(height: 12),
                column,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading!,
              const SizedBox(width: 16),
              Expanded(child: column),
            ],
          );
        }

        final actionsWrap = actions.isEmpty
            ? null
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: isCompact ? WrapAlignment.start : WrapAlignment.end,
                children: actions,
              );

        return Padding(
          padding: padding ?? EdgeInsets.zero,
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTitleBlock(),
                    if (actionsWrap != null) ...[
                      const SizedBox(height: 16),
                      actionsWrap,
                    ],
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: buildTitleBlock()),
                    if (actionsWrap != null) ...[
                      const SizedBox(width: 12),
                      actionsWrap,
                    ],
                  ],
                ),
        );
      },
    );
  }
}
