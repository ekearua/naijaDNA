import 'package:equatable/equatable.dart';

class PollOption extends Equatable {
  final String id;
  final String label;
  final int votes;

  const PollOption({
    required this.id,
    required this.label,
    required this.votes,
  });

  PollOption copyWith({String? id, String? label, int? votes}) {
    return PollOption(
      id: id ?? this.id,
      label: label ?? this.label,
      votes: votes ?? this.votes,
    );
  }

  @override
  List<Object?> get props => [id, label, votes];
}

class Poll extends Equatable {
  final String id;
  final String question;
  final String? categoryId;
  final String? categoryName;
  final List<PollOption> options;
  final DateTime endsAt;
  final bool hasVoted;
  final String? selectedOptionId;

  const Poll({
    required this.id,
    required this.question,
    this.categoryId,
    this.categoryName,
    required this.options,
    required this.endsAt,
    this.hasVoted = false,
    this.selectedOptionId,
  });

  bool get isClosed => DateTime.now().isAfter(endsAt);

  int get totalVotes =>
      options.fold<int>(0, (sum, option) => sum + option.votes);

  Poll copyWith({
    String? id,
    String? question,
    String? categoryId,
    String? categoryName,
    List<PollOption>? options,
    DateTime? endsAt,
    bool? hasVoted,
    String? selectedOptionId,
  }) {
    return Poll(
      id: id ?? this.id,
      question: question ?? this.question,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      options: options ?? this.options,
      endsAt: endsAt ?? this.endsAt,
      hasVoted: hasVoted ?? this.hasVoted,
      selectedOptionId: selectedOptionId ?? this.selectedOptionId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    question,
    categoryId,
    categoryName,
    options,
    endsAt,
    hasVoted,
    selectedOptionId,
  ];
}
