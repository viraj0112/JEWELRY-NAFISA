// lib/src/designer/screens/asset_upload_screen.dart
// Create this new file.

import 'package:flutter/material.dart';

class AssetUploadScreen extends StatefulWidget {
  const AssetUploadScreen({super.key});

  @override
  State<AssetUploadScreen> createState() => _AssetUploadScreenState();
}

class _AssetUploadScreenState extends State<AssetUploadScreen> {
  final _formKey = GlobalKey<FormState>();

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
                  Text("Upload New Asset", style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 24),
                  // Placeholder for image upload button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text("Select Image/Reel"),
                    onPressed: () {
                      // TODO: Implement file picking logic
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Title"),
                    validator: (v) => v!.isEmpty ? "Title is required" : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Description"),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Category"),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Tags (comma-separated)"),
                  ),
                   const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "SKU / Code"),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // TODO: Implement submission logic to Supabase
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Uploading asset... (Not Implemented)")),
                        );
                      }
                    },
                    child: const Text("Submit for Review"),
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