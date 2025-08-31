// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Favorite _$FavoriteFromJson(Map<String, dynamic> json) => Favorite(
  movie: Movie.fromJson(json['movie'] as Map<String, dynamic>),
  createdAt: json['created_at'] as String,
);

Map<String, dynamic> _$FavoriteToJson(Favorite instance) => <String, dynamic>{
  'movie': instance.movie.toJson(),
  'created_at': instance.createdAt,
};
