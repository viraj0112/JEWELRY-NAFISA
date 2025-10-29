import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/product_upload_section.dart';

class ProductUploadScreen extends StatelessWidget {
  const ProductUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: const ProductUploadSection(),
    );
  }
}
