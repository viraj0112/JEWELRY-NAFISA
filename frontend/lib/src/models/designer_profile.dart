class DesignerProfile {
  final String userId;
  final String businessName;
  final String? businessType;
  final String? phone;
  final String? address;
  final String? gstNumber;
  final String? workFileUrl;
  final String? businessCardUrl;

  DesignerProfile({
    required this.userId,
    required this.businessName,
    this.businessType,
    this.phone,
    this.address,
    this.gstNumber,
    this.workFileUrl,
    this.businessCardUrl,
  });

  factory DesignerProfile.fromMap(Map<String, dynamic> map) {
    return DesignerProfile(
        userId: map['user_id'] as String,
        businessName: map['business_name'] as String,
        businessType: map['business_type'] as String?,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        gstNumber: map['gst_number'] as String?,
        workFileUrl: map['work_file_url'] as String?,
        businessCardUrl: map['business_card_url'] as String?);
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'business_name': businessName,
      'business_type': businessType,
      'phone': phone,
      'address': address,
      'gst_number': gstNumber,
      'work_file_url': workFileUrl,
      'business_card_url': businessCardUrl,
    };
  }
}
