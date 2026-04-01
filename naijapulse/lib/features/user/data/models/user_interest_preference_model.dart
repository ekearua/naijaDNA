class UserInterestPreferenceModel {
  const UserInterestPreferenceModel({
    required this.categoryId,
    required this.categoryName,
    required this.explicitWeight,
    required this.implicitWeight,
    this.colorHex,
  });

  final String categoryId;
  final String categoryName;
  final String? colorHex;
  final double explicitWeight;
  final double implicitWeight;

  bool get isEnabled => explicitWeight > 0;

  factory UserInterestPreferenceModel.fromJson(Map<String, dynamic> json) {
    return UserInterestPreferenceModel(
      categoryId: (json['category_id'] ?? '').toString(),
      categoryName: (json['category_name'] ?? '').toString(),
      colorHex: json['color_hex'] as String?,
      explicitWeight: ((json['explicit_weight'] ?? 0) as num).toDouble(),
      implicitWeight: ((json['implicit_weight'] ?? 0) as num).toDouble(),
    );
  }
}
