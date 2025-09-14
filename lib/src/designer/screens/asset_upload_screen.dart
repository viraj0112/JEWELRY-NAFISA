import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssetUploadScreen extends StatefulWidget {
  const AssetUploadScreen({super.key});

  @override
  State<AssetUploadScreen> createState() => _AssetUploadScreenState();
}

class _AssetUploadScreenState extends State<AssetUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  final _skuController = TextEditingController();
  XFile? _imageFile;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile != null) {
      setState(() {
        _imageFile = imageFile;
      });
    }
  }

  Future<void> _submitAsset() async {
    if (_formKey.currentState!.validate() && _imageFile != null) {
      setState(() => _isLoading = true);
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      try {
        final fileBytes = await _imageFile!.readAsBytes();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}-${_imageFile!.name}';
        await supabase.storage.from('assets').uploadBinary(fileName, fileBytes);

        final imageUrl =
            supabase.storage.from('assets').getPublicUrl(fileName);

        await supabase.from('assets').insert({
          'owner_id': userId,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'category': _categoryController.text,
          'tags': _tagsController.text.split(','),
          'sku': _skuController.text,
          'media_url': imageUrl,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Asset uploaded successfully!")),
          );
        }
        _formKey.currentState!.reset();
        setState(() => _imageFile = null);
      } on StorageException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Storage Error: ${e.message}")),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error uploading asset: $e")),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an image to upload.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Upload New Asset",
                      style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  _imageFile == null
                      ? OutlinedButton.icon(
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text("Select Image/Reel"),
                          onPressed: _pickImage,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                          ),
                        )
                      : kIsWeb
                          ? Image.network(_imageFile!.path)
                          : Image.file(File(_imageFile!.path)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "Title"),
                    validator: (v) => v!.isEmpty ? "Title is required" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: "Description"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: "Category"),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tagsController,
                    decoration:
                        const InputDecoration(labelText: "Tags (comma-separated)"),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(labelText: "SKU / Code"),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitAsset,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text("Submit for Review"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}