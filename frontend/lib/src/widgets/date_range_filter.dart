import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';

/// Date-range picker button.
///
/// Controlled: it displays [selectedRange] (the range actually applied by the
/// parent) rather than keeping its own copy, so every instance - the header
/// and the Filters sheet - shows the same thing. With no range it reads
/// "All time"; [onCleared], when given, adds a button to remove the range.
class DateRangeFilter extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final Function(DateTimeRange) onDateSelected;
  final VoidCallback? onCleared;

  const DateRangeFilter({
    super.key,
    required this.onDateSelected,
    this.selectedRange,
    this.onCleared,
  });

  String get _displayText {
    final range = selectedRange;
    if (range == null) return 'All time';
    final sameYear = range.start.year == range.end.year &&
        range.end.year == DateTime.now().year;
    final format = DateFormat(sameYear ? 'MMM d' : 'MMM d, y');
    return '${format.format(range.start)} - ${format.format(range.end)}';
  }

  Future<void> _pickDateRange(BuildContext buttonContext) async {
    final RenderBox renderBox = buttonContext.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    // Calculate available screen size to prevent overflow
    final MediaQueryData mediaQuery = MediaQuery.of(buttonContext);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;

    // Dialog dimensions
    const double dialogWidth = 400; // Approximate width of DateRangePicker
    const double dialogHeight = 500; // Approximate height

    // Determine position: prefer below, flip to above if not enough space
    double left = offset.dx;
    double top = offset.dy + size.height + 5; // Default: below button

    // Keep the popup on screen horizontally.
    if (left + dialogWidth > screenWidth) {
      left = screenWidth - dialogWidth - 10;
    }
    if (left < 10) {
      left = 10;
    }

    // Not enough space below: show above (but never off the top).
    if (top + dialogHeight > screenHeight) {
      top = offset.dy - dialogHeight - 5;
      if (top < 10) top = 10;
    }

    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: buttonContext,
      barrierColor: Colors.transparent, // Make it look like a pure popup
      builder: (context) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: dialogWidth,
                    maxHeight: dialogHeight,
                  ),
                  child: Theme(
                    data: ThemeData.light().copyWith(
                      primaryColor: B2BColors.primary,
                      colorScheme:
                          const ColorScheme.light(primary: B2BColors.primary),
                      buttonTheme: const ButtonThemeData(
                          textTheme: ButtonTextTheme.primary),
                    ),
                    child: DateRangePickerDialog(
                      firstDate: DateTime(2023),
                      lastDate: now,
                      initialDateRange: selectedRange ??
                          DateTimeRange(
                              start: now.subtract(const Duration(days: 30)),
                              end: now),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (picked != null) onDateSelected(picked);
  }

  @override
  Widget build(BuildContext context) {
    final active = selectedRange != null;
    return Builder(
      builder: (buttonContext) => GestureDetector(
        onTap: () => _pickDateRange(buttonContext),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? B2BColors.primary.withValues(alpha: 0.06) : Colors.white,
            border: Border.all(
                color: active ? B2BColors.primaryTint : B2BColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16, color: active ? B2BColors.primary : Colors.grey),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _displayText,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: B2BColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (active && onCleared != null)
                InkWell(
                  onTap: onCleared,
                  customBorder: const CircleBorder(),
                  child: const Tooltip(
                    message: 'Clear date range',
                    child: Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                )
              else
                const Icon(Icons.keyboard_arrow_down,
                    size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
