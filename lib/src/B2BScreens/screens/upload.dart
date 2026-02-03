import 'package:flutter/material.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/Uploads/sinlgeFile.dart';
import 'package:jewelry_nafisa/src/B2BScreens/screens/Uploads/bulkUpload.dart';
class UploadPage{
static  void show(BuildContext context) {
  showModalBottomSheet(
    context: context,
    constraints: BoxConstraints.expand(width: MediaQuery.of(context).size.width, height: 340),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min, 
        crossAxisAlignment:CrossAxisAlignment.start ,
        
          children: [
            const Text("Choose Upload Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SingleProductUploadCard(),
            BulkUploadUploadCard(),
          ],
        ),
      );
    },
  );
}
}

  
