import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/admin/sections/image_upload_section.dart';

class ImageUploadScreen extends StatelessWidget {
  const ImageUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Upload'),
      ),
      body: const ImageUploadSection(),
    );
  }
}