import 'package:flutter/material.dart';

enum AdminSkeletonVariant {
  dashboard,
  table,
  cards,
  list,
  detail,
}

class AdminSkeletonView extends StatelessWidget {
  const AdminSkeletonView({
    super.key,
    this.variant = AdminSkeletonVariant.dashboard,
    this.padding = const EdgeInsets.all(24),
  });

  final AdminSkeletonVariant variant;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final shadow = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45);

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          switch (variant) {
            case AdminSkeletonVariant.dashboard:
              return _DashboardSkeleton(surface: surface, shadow: shadow);
            case AdminSkeletonVariant.table:
              return _TableSkeleton(surface: surface, shadow: shadow);
            case AdminSkeletonVariant.cards:
              return _CardsSkeleton(surface: surface, shadow: shadow);
            case AdminSkeletonVariant.list:
              return _ListSkeleton(surface: surface, shadow: shadow);
            case AdminSkeletonVariant.detail:
              return _DetailSkeleton(surface: surface, shadow: shadow);
          }
        },
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton({required this.surface, required this.shadow});

  final Color surface;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1200;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(width: 280, height: 24, radius: 12, color: surface, shadow: shadow),
          const SizedBox(height: 16),
          _SkeletonLine(width: 360, height: 16, radius: 12, color: surface, shadow: shadow),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              6,
              (_) => _SkeletonCard(width: wide ? 180 : 150, height: 110, color: surface, shadow: shadow),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(child: _SkeletonCard(width: double.infinity, height: 240, color: surface, shadow: shadow)),
              const SizedBox(width: 16),
              Expanded(child: _SkeletonCard(width: double.infinity, height: 240, color: surface, shadow: shadow)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SkeletonCard(width: double.infinity, height: 280, color: surface, shadow: shadow)),
              const SizedBox(width: 16),
              Expanded(child: _SkeletonCard(width: double.infinity, height: 280, color: surface, shadow: shadow)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableSkeleton extends StatelessWidget {
  const _TableSkeleton({required this.surface, required this.shadow});

  final Color surface;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SkeletonLine(width: 240, height: 22, radius: 12, color: surface, shadow: shadow),
        const SizedBox(height: 16),
        _SkeletonCard(
          width: double.infinity,
          height: 420,
          color: surface,
          shadow: shadow,
          child: Column(
            children: [
              Row(
                children: List.generate(
                  5,
                  (_) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _SkeletonLine(width: double.infinity, height: 16, radius: 10, color: surface, shadow: shadow),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    return Row(
                      children: [
                        Expanded(flex: 4, child: _SkeletonLine(width: double.infinity, height: 16, radius: 10, color: surface, shadow: shadow)),
                        const SizedBox(width: 16),
                        Expanded(child: _SkeletonLine(width: double.infinity, height: 16, radius: 10, color: surface, shadow: shadow)),
                        const SizedBox(width: 16),
                        Expanded(child: _SkeletonLine(width: double.infinity, height: 16, radius: 10, color: surface, shadow: shadow)),
                        const SizedBox(width: 16),
                        Expanded(child: _SkeletonLine(width: double.infinity, height: 16, radius: 10, color: surface, shadow: shadow)),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _SkeletonLine(width: 160, height: 14, radius: 10, color: surface, shadow: shadow),
                  const Spacer(),
                  _SkeletonLine(width: 180, height: 14, radius: 10, color: surface, shadow: shadow),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardsSkeleton extends StatelessWidget {
  const _CardsSkeleton({required this.surface, required this.shadow});

  final Color surface;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1100
            ? 3
            : constraints.maxWidth > 720
                ? 2
                : 1;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: columns == 1 ? 1.05 : 0.92,
          children: List.generate(
            columns == 1 ? 4 : 6,
            (_) => _SkeletonCard(
              width: double.infinity,
              height: double.infinity,
              color: surface,
              shadow: shadow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonLine(width: 80, height: 18, radius: 10, color: surface, shadow: shadow),
                  const SizedBox(height: 12),
                  _SkeletonLine(width: double.infinity, height: 20, radius: 10, color: surface, shadow: shadow),
                  const SizedBox(height: 10),
                  _SkeletonLine(width: 140, height: 14, radius: 10, color: surface, shadow: shadow),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(child: _SkeletonLine(width: double.infinity, height: 12, radius: 10, color: surface, shadow: shadow)),
                      const SizedBox(width: 12),
                      Expanded(child: _SkeletonLine(width: double.infinity, height: 12, radius: 10, color: surface, shadow: shadow)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.surface, required this.shadow});

  final Color surface;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        6,
        (index) => Padding(
          padding: EdgeInsets.only(bottom: index == 5 ? 0 : 14),
          child: _SkeletonCard(
            width: double.infinity,
            height: 84,
            color: surface,
            shadow: shadow,
            child: Row(
              children: [
                _SkeletonCircle(size: 48, color: surface, shadow: shadow),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SkeletonLine(width: 220, height: 16, radius: 10, color: surface, shadow: shadow),
                      const SizedBox(height: 10),
                      _SkeletonLine(width: 140, height: 12, radius: 10, color: surface, shadow: shadow),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _SkeletonLine(width: 120, height: 12, radius: 10, color: surface, shadow: shadow),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.surface, required this.shadow});

  final Color surface;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SkeletonLine(width: 220, height: 20, radius: 10, color: surface, shadow: shadow),
        const SizedBox(height: 18),
        _SkeletonCard(
          width: double.infinity,
          height: 180,
          color: surface,
          shadow: shadow,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
                child: _SkeletonLine(
                  width: double.infinity,
                  height: 16,
                  radius: 10,
                  color: surface,
                  shadow: shadow,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({
    required this.width,
    required this.height,
    required this.color,
    required this.shadow,
    this.child,
  });

  final double width;
  final double height;
  final Color color;
  final Color shadow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: Border.all(color: shadow),
      ),
      child: child,
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
    required this.shadow,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: shadow.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({
    required this.size,
    required this.color,
    required this.shadow,
  });

  final double size;
  final Color color;
  final Color shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: shadow.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
    );
  }
}
