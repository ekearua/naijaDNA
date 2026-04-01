class UserSettingsModel {
  const UserSettingsModel({
    required this.userId,
    required this.breakingNewsAlerts,
    required this.liveStreamAlerts,
    required this.commentReplies,
    required this.theme,
    required this.textSize,
  });

  final String userId;
  final bool breakingNewsAlerts;
  final bool liveStreamAlerts;
  final bool commentReplies;
  final String theme;
  final String textSize;

  factory UserSettingsModel.fromJson(Map<String, dynamic> json) {
    return UserSettingsModel(
      userId: (json['user_id'] ?? '').toString(),
      breakingNewsAlerts: (json['breaking_news_alerts'] ?? true) as bool,
      liveStreamAlerts: (json['live_stream_alerts'] ?? true) as bool,
      commentReplies: (json['comment_replies'] ?? true) as bool,
      theme: (json['theme'] ?? 'system').toString(),
      textSize: (json['text_size'] ?? 'small').toString(),
    );
  }
}
