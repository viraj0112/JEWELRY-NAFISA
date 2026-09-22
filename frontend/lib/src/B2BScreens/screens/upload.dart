import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/B2BScreens/b2b_theme.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/Uploads/sinlgeFile.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/Uploads/bulkUpload.dart';

class UploadPage {
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints.expand(
          width: MediaQuery.of(context).size.width, height: 340),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NEW DESIGN', style: B2BText.eyebrow()),
              const SizedBox(height: 4),
              Text("Choose Upload Method", style: B2BText.serif(size: 22)),
              const SizedBox(height: 8),
              const SingleProductUploadCard(),
              const BulkUploadUploadCard(),
            ],
          ),
        );
      },
    );
  }
}
