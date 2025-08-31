import 'user.dart';

class FriendRequest {
  final int id;
  final AppUser fromUser;
  final AppUser toUser;
  final String status; // pending, accepted, declined
  final String createdAt;
  final String updatedAt;

  // For write operations
  final int? toUserId;

  FriendRequest({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.toUserId,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] as int,
      fromUser: AppUser.fromJson(json['from_user'] as Map<String, dynamic>),
      toUser: AppUser.fromJson(json['to_user'] as Map<String, dynamic>),
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'to_user_id': toUserId,
      };
}
