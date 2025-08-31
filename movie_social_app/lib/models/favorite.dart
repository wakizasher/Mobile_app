import 'package:json_annotation/json_annotation.dart';

import 'movie.dart';

part 'favorite.g.dart';

/// Favorite model with fields: movie, created_at
@JsonSerializable(explicitToJson: true)
class Favorite {
  final Movie movie;
  @JsonKey(name: 'created_at')
  final String createdAt;

  Favorite({required this.movie, required this.createdAt});

  factory Favorite.fromJson(Map<String, dynamic> json) => _$FavoriteFromJson(json);
  Map<String, dynamic> toJson() => _$FavoriteToJson(this);
}
