import 'user.dart';

class Friendship {
  final int id;
  final AppUser user;
  final AppUser friend;
  final String createdAt;

  Friendship({
    required this.id,
    required this.user,
    required this.friend,
    required this.createdAt,
  });

  factory Friendship.fromJson(Map<String, dynamic> json) {
    return Friendship(
      id: json['id'] as int,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      friend: AppUser.fromJson(json['friend'] as Map<String, dynamic>),
      createdAt: (json['created_at'] ?? '') as String,
    );
  }
}
