import 'package:json_annotation/json_annotation.dart';

part 'movie.g.dart';

/// Movie model mirroring Django `movies.Movie` API representation.
/// Fields: id, imdb_id, title, year, poster, plot, genre, data
@JsonSerializable()
class Movie {
  final int? id;
  @JsonKey(name: 'imdb_id')
  final String imdbId;
  final String? title;
  final String? year; // Django uses CharField
  final String? poster;
  final String? plot;
  final String? genre;
  final Map<String, dynamic>? data;

  Movie({this.id, required this.imdbId, this.title, this.year, this.poster, this.plot, this.genre, this.data});

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
  Map<String, dynamic> toJson() => _$MovieToJson(this);
}
