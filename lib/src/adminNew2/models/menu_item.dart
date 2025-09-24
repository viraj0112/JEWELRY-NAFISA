import 'package:flutter/material.dart';

class MenuItem {
  final String title;
  final IconData icon;
  final Widget? screen; 
  final List<MenuItem>? subItems;

  MenuItem({
    required this.title,
    required this.icon,
    this.screen, 
    this.subItems,
  });
}