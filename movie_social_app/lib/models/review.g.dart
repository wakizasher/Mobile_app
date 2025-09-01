// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Review _$ReviewFromJson(Map<String, dynamic> json) => Review(
  content: json['content'] as String,
  rating: (json['rating'] as num?)?.toInt(),
  sentiment: json['sentiment'] as String,
  sentimentConfidence: (json['sentiment_confidence'] as num?)?.toDouble(),
  emotions: json['emotions'] as Map<String, dynamic>?,
  sentimentBreakdown: json['sentiment_breakdown'] as Map<String, dynamic>?,
  createdAt: json['created_at'] as String,
  user: json['user'] == null
      ? null
      : AppUser.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ReviewToJson(Review instance) => <String, dynamic>{
  'content': instance.content,
  'rating': instance.rating,
  'sentiment': instance.sentiment,
  'sentiment_confidence': instance.sentimentConfidence,
  'emotions': instance.emotions,
  'sentiment_breakdown': instance.sentimentBreakdown,
  'created_at': instance.createdAt,
  'user': instance.user?.toJson(),
};
