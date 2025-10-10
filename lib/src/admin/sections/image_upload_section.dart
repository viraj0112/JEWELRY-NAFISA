import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImageUploadSection extends StatefulWidget {
  const ImageUploadSection({super.key});

  @override
  State<ImageUploadSection> createState() => _ImageUploadSectionState();
}

class _ImageUploadSectionState extends State<ImageUploadSection> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<void> _pickAndUploadImages({bool allowMultiple = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        allowMultiple: allowMultiple,
        withData: kIsWeb,
      );

      if (result == null) {
        setState(() => _isLoading = false);
        return;
      }

      int skippedFiles = 0;
      if (kIsWeb) {
        skippedFiles = await _uploadForWeb(result.files);
      } else {
        skippedFiles = await _uploadForMobile(result.paths.map((path) => File(path!)).toList());
      }
      
      String message = 'Images uploaded successfully!';
      if (skippedFiles > 0) {
        message += ' ($skippedFiles invalid files were skipped).';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Returns the number of skipped files
  Future<int> _uploadForWeb(List<PlatformFile> files) async {
    int skippedCount = 0;
    for (final file in files) {
      final imageName = file.name;

      // --- ROBUST TITLE EXTRACTION ---
      final lastDot = imageName.lastIndexOf('.');
      final productTitle = (lastDot == -1) ? imageName : imageName.substring(0, lastDot);
      
      // Skip invalid files (like .DS_Store)
      if (productTitle.isEmpty) {
        debugPrint('Skipping invalid file: $imageName');
        skippedCount++;
        continue;
      }
      // --------------------------------

      await _supabase.storage.from('product-images').uploadBinary(
            imageName,
            file.bytes!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl =
          _supabase.storage.from('product-images').getPublicUrl(imageName);

      await _supabase
          .from('products')
          .update({'image': imageUrl})
          .eq('title', productTitle);
    }
    return skippedCount;
  }

  // Returns the number of skipped files
  Future<int> _uploadForMobile(List<File> files) async {
    int skippedCount = 0;
    for (final file in files) {
      final imageName = file.path.split(Platform.pathSeparator).last;

      // --- ROBUST TITLE EXTRACTION ---
      final lastDot = imageName.lastIndexOf('.');
      final productTitle = (lastDot == -1) ? imageName : imageName.substring(0, lastDot);
      
      // Skip invalid files
      if (productTitle.isEmpty) {
        debugPrint('Skipping invalid file: $imageName');
        skippedCount++;
        continue;
      }
      // --------------------------------

      await _supabase.storage.from('product-images').upload(
            imageName,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl =
          _supabase.storage.from('product-images').getPublicUrl(imageName);

      await _supabase
          .from('products')
          .update({'image': imageUrl})
          .eq('title', productTitle);
    }
    return skippedCount;
  }

  @override
  Widget build(BuildContext context) {
    // Build method remains the same
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Upload Product Images',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload a single image or multiple images. The image name (without the file extension) should exactly match the product title to link them automatically.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Row(
              children: [
                ElevatedButton(
                  onPressed: () => _pickAndUploadImages(),
                  child: const Text('Upload Single Image'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => _pickAndUploadImages(allowMultiple: true),
                  child: const Text('Upload Multiple Images'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}