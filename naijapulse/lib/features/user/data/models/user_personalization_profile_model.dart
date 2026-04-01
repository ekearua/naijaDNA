import 'package:naijapulse/features/user/data/models/user_interest_preference_model.dart';

class UserPersonalizationProfileModel {
  const UserPersonalizationProfileModel({
    required this.userId,
    required this.interests,
    required this.topics,
  });

  final String userId;
  final List<UserInterestPreferenceModel> interests;
  final List<String> topics;

  factory UserPersonalizationProfileModel.fromJson(Map<String, dynamic> json) {
    final rawInterests = json['interests'];
    final rawTopics = json['topics'];

    final interests = rawInterests is List
        ? rawInterests
              .whereType<Map<String, dynamic>>()
              .map(UserInterestPreferenceModel.fromJson)
              .toList()
        : <UserInterestPreferenceModel>[];
    final topics = rawTopics is List
        ? rawTopics
              .whereType<Map<String, dynamic>>()
              .map((topic) => (topic['topic'] ?? '').toString())
              .where((topic) => topic.trim().isNotEmpty)
              .toList()
        : <String>[];

    return UserPersonalizationProfileModel(
      userId: (json['user_id'] ?? '').toString(),
      interests: interests,
      topics: topics,
    );
  }
}
