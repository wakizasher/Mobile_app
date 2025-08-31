// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'social_stats.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SocialStats _$SocialStatsFromJson(Map<String, dynamic> json) => SocialStats(
  likes: (json['likes'] as num).toInt(),
  favorites: (json['favorites'] as num).toInt(),
  reviews: (json['reviews'] as num).toInt(),
);

Map<String, dynamic> _$SocialStatsToJson(SocialStats instance) =>
    <String, dynamic>{
      'likes': instance.likes,
      'favorites': instance.favorites,
      'reviews': instance.reviews,
    };
