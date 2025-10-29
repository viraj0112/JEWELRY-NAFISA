// lib/src/widgets/quote_request_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  State<QuoteRequestDialog> createState() => _QuoteRequestDialogState();
}

class _QuoteRequestDialogState extends State<QuoteRequestDialog> {
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>(); // Used for validation if needed
  bool _isSubmitting = false;
  int _wordCount = 0;
  final int _maxWords = 250; // Maximum allowed words

  @override
  void initState() {
    super.initState();
    _notesController.addListener(_updateWordCount);
  }

  @override
  void dispose() {
    _notesController.removeListener(_updateWordCount);
    _notesController.dispose();
    super.dispose();
  }

  // Counts words based on spaces
  void _updateWordCount() {
    final text = _notesController.text.trim();
    setState(() {
      _wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    });
  }

  // Handles the submission process
  Future<void> _submitQuote() async {
    // Basic validation (optional field doesn't need form validation unless strict rules apply)
     if (_wordCount > _maxWords) {
        ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
            content: Text('Please limit additional details to $_maxWords words.'),
            backgroundColor: Colors.orange), // Use orange for warnings
        );
       return; // Stop submission if word count exceeded
     }

    setState(() => _isSubmitting = true);
    try {
      // Call the service to submit the data
      await widget.quoteService.submitQuoteRequest(
        user: widget.user,
        product: widget.product,
        additionalNotes: _notesController.text.isEmpty ? null : _notesController.text, // Pass null if empty
      );

      // If successful, close dialog and show success message
      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote request submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // If error, show error message
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting quote: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Ensure loading state is reset even if errors occur
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Determine user display name
    final userName = widget.user.username ?? widget.user.fullName ?? widget.user.email ?? 'N/A';

    return AlertDialog(
      title: const Text('Request Quote'),
      // Make content scrollable if it overflows
      content: SingleChildScrollView(
        child: Form( // Wrap in Form if you add more validation later
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // Important for AlertDialog content
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display Product and User info (read-only)
              Text("Product:", style: theme.textTheme.labelLarge),
              Text(widget.product.productTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Text("User:", style: theme.textTheme.labelLarge),
              Text(userName, style: theme.textTheme.titleMedium),
              const SizedBox(height: 20),

              // Text area for additional details
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'Additional Details (Optional)',
                  hintText: 'Max 250 words (e.g., customizations, questions)',
                  border: const OutlineInputBorder(),
                  // Display word count and limit
                  counterText: '$_wordCount/$_maxWords words',
                  counterStyle: TextStyle(
                    color: _wordCount > _maxWords ? Colors.red : theme.hintColor,
                  ),
                  // Show error style if word count exceeded
                  errorText: _wordCount > _maxWords ? 'Word limit exceeded' : null,
                  errorStyle: const TextStyle(color: Colors.red),
                ),
                maxLines: 4, 
              ),
             
              if (_wordCount > _maxWords)
                 Padding(
                   padding: const EdgeInsets.only(top: 8.0),
                   child: Text(
                     'Word limit exceeded. Please shorten your notes.',
                     style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                   ),
                 ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
         
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        
        ElevatedButton(
          onPressed: (_isSubmitting || _wordCount > _maxWords) ? null : _submitQuote,
          child: _isSubmitting
              
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                )
              : const Text('Submit Request'),
        ),
      ],
    );
  }
}