import 'package:naijapulse/features/polls/domain/entities/poll.dart';

class PollOptionModel extends PollOption {
  const PollOptionModel({
    required super.id,
    required super.label,
    required super.votes,
  });

  factory PollOptionModel.fromJson(Map<String, dynamic> json) {
    return PollOptionModel(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      votes: ((json['votes'] ?? 0) as num).toInt(),
    );
  }

  factory PollOptionModel.fromEntity(PollOption entity) {
    return PollOptionModel(
      id: entity.id,
      label: entity.label,
      votes: entity.votes,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'votes': votes};
  }
}

class PollModel extends Poll {
  const PollModel({
    required super.id,
    required super.question,
    super.categoryId,
    super.categoryName,
    required super.options,
    required super.endsAt,
    super.hasVoted,
    super.selectedOptionId,
  });

  factory PollModel.fromJson(Map<String, dynamic> json) {
    final endsAtRaw = json['endsAt'] ?? json['ends_at'];
    if (endsAtRaw == null) {
      throw const FormatException('Missing poll end timestamp.');
    }

    return PollModel(
      id: (json['id'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? json['category_id']) as String?,
      categoryName: (json['categoryName'] ?? json['category_name']) as String?,
      options: (json['options'] as List<dynamic>)
          .map(
            (option) =>
                PollOptionModel.fromJson(option as Map<String, dynamic>),
          )
          .toList(),
      endsAt: DateTime.parse(endsAtRaw.toString()),
      hasVoted: (json['hasVoted'] ?? json['has_voted']) as bool? ?? false,
      selectedOptionId:
          (json['selectedOptionId'] ?? json['selected_option_id']) as String?,
    );
  }

  factory PollModel.fromEntity(Poll entity) {
    return PollModel(
      id: entity.id,
      question: entity.question,
      categoryId: entity.categoryId,
      categoryName: entity.categoryName,
      options: entity.options
          .map((option) => PollOptionModel.fromEntity(option))
          .toList(),
      endsAt: entity.endsAt,
      hasVoted: entity.hasVoted,
      selectedOptionId: entity.selectedOptionId,
    );
  }

  PollModel copyWithVote({required String optionId}) {
    final updatedOptions = options
        .map(
          (option) => option.id == optionId
              ? option.copyWith(votes: option.votes + 1)
              : option,
        )
        .toList();
    return PollModel(
      id: id,
      question: question,
      categoryId: categoryId,
      categoryName: categoryName,
      options: updatedOptions,
      endsAt: endsAt,
      hasVoted: true,
      selectedOptionId: optionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'options': options
          .map((option) => PollOptionModel.fromEntity(option).toJson())
          .toList(),
      'endsAt': endsAt.toIso8601String(),
      'hasVoted': hasVoted,
      'selectedOptionId': selectedOptionId,
    };
  }
}
