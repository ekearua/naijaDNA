import 'package:naijapulse/features/polls/domain/entities/poll_category.dart';

class PollCategoryModel extends PollCategory {
  const PollCategoryModel({
    required super.id,
    required super.name,
    super.colorHex,
    super.description,
  });

  factory PollCategoryModel.fromJson(Map<String, dynamic> json) {
    return PollCategoryModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      colorHex: (json['color_hex'] ?? json['colorHex']) as String?,
      description: json['description'] as String?,
    );
  }
}
