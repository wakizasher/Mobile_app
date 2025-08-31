import 'package:json_annotation/json_annotation.dart';

part 'social_stats.g.dart';

/// Social stats for a specific movie returned by `SocialStatsSerializer`.
/// Fields: likes, favorites, reviews
@JsonSerializable()
class SocialStats {
  final int likes;
  final int favorites;
  final int reviews;

  SocialStats({required this.likes, required this.favorites, required this.reviews});

  factory SocialStats.fromJson(Map<String, dynamic> json) => _$SocialStatsFromJson(json);
  Map<String, dynamic> toJson() => _$SocialStatsToJson(this);
}
