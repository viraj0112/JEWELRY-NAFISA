import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditBusinessProfileDialog extends StatefulWidget {
  final dynamic profile; // DesignerProfile or ManufacturerProfile
  final String profileType; // 'designer' or 'manufacturer'
  final VoidCallback onProfileUpdated;

  const EditBusinessProfileDialog({
    super.key,
    required this.profile,
    required this.profileType,
    required this.onProfileUpdated,
  });

  @override
  State<EditBusinessProfileDialog> createState() =>
      _EditBusinessProfileDialogState();
}

class _EditBusinessProfileDialogState extends State<EditBusinessProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _typeController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _gstController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.profile?.businessName ?? '');
    _typeController =
        TextEditingController(text: widget.profile?.businessType ?? '');
    _phoneController = TextEditingController(text: widget.profile?.phone ?? '');
    _addressController =
        TextEditingController(text: widget.profile?.address ?? '');
    _gstController =
        TextEditingController(text: widget.profile?.gstNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final table = widget.profileType == 'manufacturer'
          ? 'manufacturer_profiles'
          : 'designer_profiles';

      final updates = {
        'business_name': _nameController.text.trim(),
        'business_type': _typeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'gst_number': _gstController.text.trim(),
      };

      await supabase.from(table).update(updates).eq('user_id', user.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onProfileUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFAFAFA),
      surfaceTintColor: Colors.transparent,
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Business Profile',
                  style: TextStyle(
                    fontFamily:
                        'PlayfairDisplay', // Or any serif fallback you have
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 18, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildFormField(
                        icon: Icons.work_outline,
                        label: 'Business Name',
                        controller: _nameController,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      _buildFormField(
                        icon: Icons.inventory_2_outlined,
                        label: 'Business Type',
                        controller: _typeController,
                      ),
                      _buildFormField(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildFormField(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        controller: _addressController,
                        maxLines: 2,
                      ),
                      _buildFormField(
                        icon: Icons.description_outlined,
                        label: 'GST Number',
                        controller: _gstController,
                        hintText: 'Enter GST Number',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                        isLast: true, // No divider after the last item
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF286A55), // Dark green
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular Icon
            Container(
              margin: const EdgeInsets.only(top: 4, right: 16),
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            ),
            // Text Field Area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  TextFormField(
                    controller: controller,
                    maxLines: maxLines,
                    keyboardType: keyboardType,
                    validator: validator,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1F2937),
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.normal,
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none, // Removes the default underline
                      errorStyle: const TextStyle(height: 1),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.only(
                left: 52, top: 4, bottom: 16), // Aligned with the text field
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          ),
      ],
    );
  }
}
