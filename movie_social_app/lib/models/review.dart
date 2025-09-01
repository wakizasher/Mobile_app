import 'package:json_annotation/json_annotation.dart';
import 'user.dart';

part 'review.g.dart';

/// Review model with fields: content, rating, sentiment, created_at, user
@JsonSerializable()
class Review {
  final String content;
  final int? rating;
  final String sentiment;
  @JsonKey(name: 'sentiment_confidence')
  final double? sentimentConfidence;
  final Map<String, dynamic>? emotions;
  @JsonKey(name: 'sentiment_breakdown')
  final Map<String, dynamic>? sentimentBreakdown;
  @JsonKey(name: 'created_at')
  final String createdAt;
  final AppUser? user;

  Review({
    required this.content,
    this.rating,
    required this.sentiment,
    this.sentimentConfidence,
    this.emotions,
    this.sentimentBreakdown,
    required this.createdAt,
    this.user,
  });

  factory Review.fromJson(Map<String, dynamic> json) => _$ReviewFromJson(json);
  Map<String, dynamic> toJson() => _$ReviewToJson(this);
}
