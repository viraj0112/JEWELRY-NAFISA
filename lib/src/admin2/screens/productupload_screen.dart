import 'package:flutter/material.dart';
import "../sections/productupload_section.dart";
import '../providers/creators_provider.dart';
import 'package:provider/provider.dart';

class ProductUploadScreen extends StatelessWidget {
  const ProductUploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CreatorsProvider()..loadCreators(),
      child: const ProductUploadSection(),
    );
  }
}
