import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/jewelry_detail_screen.dart';
import 'package:jewelry_nafisa/src/ui/screens/detail/product_browse.dart';

/// Product pages the user can swipe through, right to left, in the order of
/// the list they came from, with an "N designs left" counter.
///
/// Swiping on the image area still flips through that product's photos; a
/// swipe anywhere else on the page moves to the next product. Wide screens
/// also get previous/next buttons and the arrow keys, since a mouse cannot
/// drag a page.
///
/// Only the page the user settles on is a full [JewelryDetailScreen]. While a
/// neighbour is being dragged into view it is a plain image preview, so a
/// product merely peeked at is not fetched in full or counted as viewed.
class ProductSwipePager extends StatefulWidget {
  const ProductSwipePager({super.key, required this.browse});

  final ProductBrowseList browse;

  @override
  State<ProductSwipePager> createState() => _ProductSwipePagerState();
}

class _ProductSwipePagerState extends State<ProductSwipePager> {
  late final PageController _controller;
  late int _settled;
  final Map<int, Future<JewelryItem?>> _fullItems = {};

  bool _counterVisible = false;
  Timer? _counterTimer;

  List<JewelryItem> get _items => widget.browse.items;
  int get _remaining => _items.length - _settled - 1;

  @override
  void initState() {
    super.initState();
    _settled = widget.browse.index;
    _controller = PageController(initialPage: _settled);
    _prefetchAround(_settled);
    // Show the counter once on arrival, as a hint that there is more to swipe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _flashCounter();
    });
  }

  @override
  void dispose() {
    _counterTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<JewelryItem?> _fullItem(int index) =>
      _fullItems[index] ??= loadFullProduct(_items[index]);

  void _prefetchAround(int index) {
    _fullItem(index);
    if (index > 0) _fullItem(index - 1);
    if (index < _items.length - 1) _fullItem(index + 1);
  }

  bool _onScroll(ScrollNotification notification) {
    // depth 0 is this pager; deeper notifications come from the page's own
    // vertical scrolling and image carousel.
    if (notification.depth == 0 && notification is ScrollEndNotification) {
      final page = _controller.page?.round();
      if (page != null) _settle(page);
    }
    return false;
  }

  void _settle(int index) {
    if (index == _settled) return;
    setState(() => _settled = index);
    _prefetchAround(index);
    // Keep the address bar on the product being shown so it can be shared or
    // refreshed, without a router navigation that would rebuild this pager.
    unawaited(SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(productPath(_items[index])),
      replace: true,
    ));
    _flashCounter();
  }

  void _flashCounter() {
    _counterTimer?.cancel();
    setState(() => _counterVisible = true);
    _counterTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _counterVisible = false);
    });
  }

  void _go(int delta) {
    final target = _settled + delta;
    if (target < 0 || target >= _items.length) return;
    _controller.animateToPage(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 800;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ScrollConfiguration(
                // Let a trackpad swipe move between products on desktop web.
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.trackpad,
                  },
                ),
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  itemBuilder: (context, index) => index == _settled
                      ? _FullProductPage(
                          key: ValueKey(index),
                          preview: _items[index],
                          full: _fullItem(index),
                        )
                      : _ProductPreview(item: _items[index]),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: isWide
                      ? _CounterPill(
                          remaining: _remaining,
                          onPrevious: _settled > 0 ? () => _go(-1) : null,
                          onNext: _remaining > 0 ? () => _go(1) : null,
                        )
                      : IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _counterVisible ? 1 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: _CounterPill(remaining: _remaining),
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The settled page: the full product once loaded, its preview until then.
class _FullProductPage extends StatelessWidget {
  const _FullProductPage(
      {super.key, required this.preview, required this.full});

  final JewelryItem preview;
  final Future<JewelryItem?> full;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<JewelryItem?>(
      future: full,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _ProductPreview(item: preview, loading: true);
        }
        final item = snapshot.data;
        if (item == null) {
          return Scaffold(
            appBar: AppBar(
              leading: Container(
                margin: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'This product could not be loaded. Swipe to see the next one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back to catalogue'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return JewelryDetailScreen(
          key: ValueKey(item.uid ?? item.id),
          jewelryItem: item,
        );
      },
    );
  }
}

/// A light stand-in for a product page: just its image.
class _ProductPreview extends StatelessWidget {
  const _ProductPreview({required this.item, this.loading = false});

  final JewelryItem item;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          if (item.image.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: CachedNetworkImage(
                imageUrl: item.image,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (loading) const CircularProgressIndicator(),
          if (loading)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.remaining, this.onPrevious, this.onNext});

  final int remaining;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final label = switch (remaining) {
      0 => 'Last design',
      1 => '1 design left',
      _ => '$remaining designs left',
    };
    final showArrows = onPrevious != null || onNext != null;
    return Material(
      color: Colors.black.withValues(alpha: 0.65),
      shape: const StadiumBorder(),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: showArrows ? 4 : 14, vertical: showArrows ? 0 : 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showArrows)
              IconButton(
                onPressed: onPrevious,
                tooltip: 'Previous design',
                icon: const Icon(Icons.chevron_left),
                color: Colors.white,
                disabledColor: Colors.white38,
                visualDensity: VisualDensity.compact,
              ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showArrows)
              IconButton(
                onPressed: onNext,
                tooltip: 'Next design',
                icon: const Icon(Icons.chevron_right),
                color: Colors.white,
                disabledColor: Colors.white38,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
