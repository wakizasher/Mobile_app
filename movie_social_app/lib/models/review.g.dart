// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Review _$ReviewFromJson(Map<String, dynamic> json) => Review(
  content: json['content'] as String,
  rating: (json['rating'] as num?)?.toInt(),
  sentiment: json['sentiment'] as String,
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$ReviewToJson(Review instance) => <String, dynamic>{
  'content': instance.content,
  'rating': instance.rating,
  'sentiment': instance.sentiment,
  'created_at': instance.createdAt,
};
