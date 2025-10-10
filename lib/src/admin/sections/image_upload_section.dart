import 'dart:io';

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

  Future<void> _uploadImages(List<File> images) async {
    setState(() {
      _isLoading = true;
    });

    try {
      for (final image in images) {
        final imageName = image.path.split('/').last;
        final productTitle = imageName.split('.').first;

        // Upload image to Supabase Storage
        await _supabase.storage.from('product-images').upload(
              imageName,
              image,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: false),
            );

        // Get public URL
        final imageUrl =
            _supabase.storage.from('product-images').getPublicUrl(imageName);

        // Update product table
        await _supabase
            .from('products')
            .update({'image': imageUrl}).eq('title', productTitle);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Images uploaded successfully')),
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

  Future<void> _pickAndUploadImages({bool allowMultiple = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: allowMultiple,
    );

    if (result != null) {
      final files = result.paths.map((path) => File(path!)).toList();
      await _uploadImages(files);
    }
  }

  @override
  Widget build(BuildContext context) {
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
