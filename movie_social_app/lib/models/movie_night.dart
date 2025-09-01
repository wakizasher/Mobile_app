import 'user.dart';
import 'movie_night_participant.dart';
import 'movie_night_vote.dart';

class MovieNight {
  final int id;
  final AppUser organizer;
  final String title;
  final String? description;
  final DateTime? scheduledDate;
  final String? location;
  final String status;
  final int? maxParticipants;
  final List<MovieNightParticipant> participants;
  final List<MovieNightVote> votes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MovieNight({
    required this.id,
    required this.organizer,
    required this.title,
    this.description,
    this.scheduledDate,
    this.location,
    required this.status,
    this.maxParticipants,
    required this.participants,
    required this.votes,
    this.createdAt,
    this.updatedAt,
  });

  factory MovieNight.fromJson(Map<String, dynamic> json) {
    return MovieNight(
      id: (json['id'] as num).toInt(),
      organizer: AppUser.fromJson(json['organizer'] as Map<String, dynamic>),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] as String?),
      scheduledDate: _parseDateTime(json['scheduled_date']),
      location: (json['location'] as String?),
      status: (json['status'] ?? '').toString(),
      maxParticipants: json['max_participants'] == null ? null : (json['max_participants'] as num).toInt(),
      participants: ((json['participants'] as List?) ?? const [])
          .map((e) => MovieNightParticipant.fromJson(e as Map<String, dynamic>))
          .toList(),
      votes: ((json['votes'] as List?) ?? const [])
          .map((e) => MovieNightVote.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organizer': organizer.toJson(),
        'title': title,
        'description': description,
        'scheduled_date': scheduledDate?.toIso8601String(),
        'location': location,
        'status': status,
        'max_participants': maxParticipants,
        'participants': participants.map((e) => e.toJson()).toList(),
        'votes': votes.map((e) => e.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };
}

DateTime? _parseDateTime(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

