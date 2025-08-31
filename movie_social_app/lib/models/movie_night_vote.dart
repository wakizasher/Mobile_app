import 'user.dart';
import 'movie.dart';

class MovieNightVote {
  final int id;
  final Movie movie;
  final AppUser user;
  final DateTime? createdAt;

  MovieNightVote({required this.id, required this.movie, required this.user, this.createdAt});

  factory MovieNightVote.fromJson(Map<String, dynamic> json) {
    return MovieNightVote(
      id: (json['id'] as num).toInt(),
      movie: Movie.fromJson(json['movie'] as Map<String, dynamic>),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'movie': movie.toJson(),
        'user': user.toJson(),
        'created_at': createdAt?.toIso8601String(),
      };
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}
