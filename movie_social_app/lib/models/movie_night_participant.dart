import 'user.dart';

class MovieNightParticipant {
  final int id;
  final AppUser user;
  final String status;
  final DateTime? joinedAt;

  MovieNightParticipant({
    required this.id,
    required this.user,
    required this.status,
    this.joinedAt,
  });

  factory MovieNightParticipant.fromJson(Map<String, dynamic> json) {
    return MovieNightParticipant(
      id: (json['id'] as num).toInt(),
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      status: (json['status'] ?? '').toString(),
      joinedAt: _parseDateTime(json['joined_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': user.toJson(),
        'status': status,
        'joined_at': joinedAt?.toIso8601String(),
      };
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v);
  }
  return null;
}
