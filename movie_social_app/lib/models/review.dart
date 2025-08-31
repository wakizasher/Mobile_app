import 'package:json_annotation/json_annotation.dart';

part 'review.g.dart';

/// Review model with fields: content, rating, sentiment, created_at
@JsonSerializable()
class Review {
  final String content;
  final int? rating;
  final String sentiment;
  @JsonKey(name: 'created_at')
  final String createdAt;

  Review({required this.content, this.rating, required this.sentiment, required this.createdAt});

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewToJson(this);
}
