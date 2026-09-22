import 'package:flutter/material.dart';

class FilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isActive;

  const FilterButton({
    super.key,
    required this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.diamond,
            color: isActive ? Colors.white : Colors.grey,
            size: 24,
          ),
          Positioned(
            right: 0,
            child: Text(
              'FILTERS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey,
              ),
            ),
          ),
        ],
      ),
      onPressed: onPressed,
      color: Colors.green,
      style: IconButton.styleFrom(
        backgroundColor: isActive ? Colors.green : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: isActive ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
    );
  }
}
