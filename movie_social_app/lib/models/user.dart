import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// User model matching backend `UserSerializer` fields
@JsonSerializable()
class AppUser {
  final int id;
  final String username;
  final String? email;
  @JsonKey(name: 'first_name')
  final String? firstName;
  @JsonKey(name: 'last_name')
  final String? lastName;
  @JsonKey(name: 'display_name')
  final String? displayName;
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;
  final String? bio;

  AppUser({
    required this.id,
    required this.username,
    this.email,
    this.firstName,
    this.lastName,
    this.displayName,
    this.avatarUrl,
    this.bio,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
  Map<String, dynamic> toJson() => _$AppUserToJson(this);
}
