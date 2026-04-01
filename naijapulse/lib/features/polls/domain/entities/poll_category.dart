import 'package:equatable/equatable.dart';

class PollCategory extends Equatable {
  const PollCategory({
    required this.id,
    required this.name,
    this.colorHex,
    this.description,
  });

  final String id;
  final String name;
  final String? colorHex;
  final String? description;

  @override
  List<Object?> get props => [id, name, colorHex, description];
}
