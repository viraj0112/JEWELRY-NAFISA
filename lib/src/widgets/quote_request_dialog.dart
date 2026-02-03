import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/services/quote_service.dart';

class QuoteRequestDialog extends StatefulWidget {
  final UserProfile user;
  final JewelryItem product;
  final QuoteService quoteService;

  const QuoteRequestDialog({
    super.key,
    required this.user,
    required this.product,
    required this.quoteService,
  });

  @override
  _QuoteRequestDialogState createState() => _QuoteRequestDialogState();
}

class _QuoteRequestDialogState extends State<QuoteRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  // RENAME _messageController to _notesController for clarity
  late final TextEditingController _notesController;
  late final TextEditingController _phoneController; // <-- ADD THIS
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _phoneController =
        TextEditingController(text: widget.user.phone); // <-- ADD THIS
  }

  @override
  void dispose() {
    _notesController.dispose();
    _phoneController.dispose(); 
    super.dispose();
  }

  Future<void> _submitForm() async {
    // Validate is not needed if fields are optional, but good to keep
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Call the correct service method
        await widget.quoteService.submitQuoteRequest(
          product: widget.product,
          user: widget.user,
          phoneNumber: _phoneController.text, // <-- PASS PHONE
          additionalNotes: _notesController.text, // <-- PASS NOTES
        );

        if (mounted) {
          Navigator.of(context).pop(); // Close dialog on success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quote request submitted!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Get a Quote'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.productTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (widget.product.image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: widget.product.image,
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
              const SizedBox(height: 16),

              // --- ADDED PHONE FIELD ---
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter your phone number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Additional Notes (Optional)',
                  hintText: 'e.g., "I need this by..." or "Change stone to..."',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : _submitForm, 
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Request'),
        ),
      ],
    );
  }
}
