// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'movie.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Movie _$MovieFromJson(Map<String, dynamic> json) => Movie(
  id: (json['id'] as num?)?.toInt(),
  imdbId: json['imdb_id'] as String,
  title: json['title'] as String?,
  year: json['year'] as String?,
  poster: json['poster'] as String?,
  plot: json['plot'] as String?,
  genre: json['genre'] as String?,
  data: json['data'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$MovieToJson(Movie instance) => <String, dynamic>{
  'id': instance.id,
  'imdb_id': instance.imdbId,
  'title': instance.title,
  'year': instance.year,
  'poster': instance.poster,
  'plot': instance.plot,
  'genre': instance.genre,
  'data': instance.data,
};
