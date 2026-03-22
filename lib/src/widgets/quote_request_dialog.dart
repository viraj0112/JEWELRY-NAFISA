import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jewelry_nafisa/src/models/jewelry_item.dart';
import 'package:jewelry_nafisa/src/models/user_profile.dart';
import 'package:jewelry_nafisa/src/services/quote_service.dart';
import 'package:jewelry_nafisa/src/widgets/blur_up_placeholder.dart';

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

  late final TextEditingController _notesController;
  late final TextEditingController _phoneController;

  late final TextEditingController _metalPurityController;
  late final TextEditingController _metalFinishController;
  late final TextEditingController _stoneUsedController;
  late final TextEditingController _stoneCountController;
  late final TextEditingController _metalTypeController;
  late final TextEditingController _metalColorController;
  late final TextEditingController _stoneColorController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _phoneController = TextEditingController(text: widget.user.phone);
    _metalPurityController =
        TextEditingController(text: widget.product.metalPurity);
    _metalFinishController =
        TextEditingController(text: widget.product.metalFinish);
    _stoneUsedController =
        TextEditingController(text: widget.product.stoneUsed?.join(', '));
    _stoneCountController =
        TextEditingController(text: widget.product.stoneCount?.join(', '));
    _metalTypeController =
        TextEditingController(text: widget.product.metalType);
    _metalColorController =
        TextEditingController(text: widget.product.metalColor);
    _stoneColorController =
        TextEditingController(text: widget.product.stoneColor?.join(', '));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _phoneController.dispose();
    _metalPurityController.dispose();
    _metalFinishController.dispose();
    _stoneUsedController.dispose();
    _stoneCountController.dispose();
    _metalTypeController.dispose();
    _metalColorController.dispose();
    _stoneColorController.dispose();
    super.dispose();
  }

  List<String>? _parseArray(String value) {
    if (value.trim().isEmpty) return null;
    return value
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final combinedNotes = [
          _notesController.text,
        ].where((e) => e.isNotEmpty).join('\n\n');

        await widget.quoteService.submitQuoteRequest(
          product: widget.product,
          user: widget.user,
          phoneNumber: _phoneController.text,
          additionalNotes: combinedNotes,
          metalPurity: _metalPurityController.text.isEmpty
              ? null
              : _metalPurityController.text,
          metalFinish: _metalFinishController.text.isEmpty
              ? null
              : _metalFinishController.text,
          stoneUsed: _parseArray(_stoneUsedController.text),
          stoneCount: _parseArray(_stoneCountController.text),
          metalType: _metalTypeController.text.isEmpty
              ? null
              : _metalTypeController.text,
          metalColor: _metalColorController.text.isEmpty
              ? null
              : _metalColorController.text,
          stoneColor: _parseArray(_stoneColorController.text),
        );

        if (mounted) {
          Navigator.of(context).pop();
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

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter $label',
          border: const OutlineInputBorder(),
        ),
      ),
    );
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
                    placeholder: (context, url) => createBlurUpPlaceholder(),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              const Text('Provide custom specifications below (Optional):',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _buildTextField('Metal Purity', _metalPurityController),
              _buildTextField('Metal Finish', _metalFinishController),
              _buildTextField(
                  'Stone Used (Comma Separated)', _stoneUsedController),
              _buildTextField(
                  'Stone Count (Comma Separated)', _stoneCountController),
              _buildTextField('Metal Type', _metalTypeController),
              _buildTextField('Metal Color', _metalColorController),
              _buildTextField(
                  'Stone Color (Comma Separated)', _stoneColorController),
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
          onPressed: _isLoading ? null : _submitForm,
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
