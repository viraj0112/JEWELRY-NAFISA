import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangeFilter extends StatefulWidget {
  final Function(DateTimeRange) onDateSelected;

  const DateRangeFilter({super.key, required this.onDateSelected});

  @override
  State<DateRangeFilter> createState() => _DateRangeFilterState();
}

class _DateRangeFilterState extends State<DateRangeFilter> {
  String _displayText = "30 days"; // Default text from your screenshot
  DateTimeRange? _selectedRange;

  final GlobalKey _buttonKey = GlobalKey();

  Future<void> _pickDateRange() async {
    final RenderBox renderBox = _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    // Calculate available screen size to prevent overflow
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;

    // Dialog dimensions
    const double dialogWidth = 400; // Approximate width of DateRangePicker
    const double dialogHeight = 500; // Approximate height

    // Determine position: prefer below, flip to above if not enough space
    double left = offset.dx;
    double top = offset.dy + size.height + 5; // Default: below button

    // Adjust horizontal position if it goes off-screen right
    if (left + dialogWidth > screenWidth) {
      left = screenWidth - dialogWidth - 10;
    }
    // Adjust horizontal position if it goes off-screen left (unlikely but safe)
    if (left < 10) {
      left = 10;
    }

    // Check vertical space
    if (top + dialogHeight > screenHeight) {
      // Not enough space below, show above
      top = offset.dy - dialogHeight - 5;
    }

    final DateTime now = DateTime.now();
    final DateTimeRange? picked = await showDialog<DateTimeRange>(
      context: context,
      barrierColor: Colors.transparent, // Make it look like a pure popup
      builder: (context) {
        return Stack(
          children: [
            // Close the dialog when clicking outside (transparent barrier handles this, 
            // but this ensures clicks pass through if needed, though modal barrier usually blocks)
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
                      primaryColor: Colors.teal,
                      colorScheme: const ColorScheme.light(primary: Colors.teal),
                      buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
                    ),
                    child: DateRangePickerDialog(
                      firstDate: DateTime(2023),
                      lastDate: now,
                      initialDateRange: _selectedRange ?? DateTimeRange(
                        start: now.subtract(const Duration(days: 30)),
                        end: now
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
        // Format the text to look professional (e.g., "Jan 1 - Jan 31")
        String start = DateFormat('MMM d').format(picked.start);
        String end = DateFormat('MMM d').format(picked.end);
        _displayText = "$start - $end";
      });
      
      // Send the data back to your main screen to filter products
      widget.onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pickDateRange,
      child: Container(
        key: _buttonKey, // Assign the GlobalKey here
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              _displayText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}