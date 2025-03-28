// lib/models/room.dart
class Room {
  final int? id;
  final int inspectionId;
  final int? roomId; //Original room_id from the template
  final int position;
  final String roomName;
  final String? roomLabel;
  final String? observation;
  final bool? isDamaged;
  final List<String>? tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Room({
    this.id,
    required this.inspectionId,
    this.roomId,
    required this.position,
    required this.roomName,
    this.roomLabel,
    this.observation,
    this.isDamaged,
    this.tags,
    this.createdAt,
    this.updatedAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      inspectionId: json['inspection_id'],
      roomId: json['room_id'],
      position: json['position'],
      roomName: json['room_name'],
      roomLabel: json['room_label'],
      observation: json['observation'],
      isDamaged: json['is_damaged'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'room_id': roomId,
      'position': position,
      'room_name': roomName,
      'room_label': roomLabel,
      'observation': observation,
      'is_damaged': isDamaged,
      'tags': tags,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Room copyWith({
    int? id,
    int? inspectionId,
    int? roomId,
    int? position,
    String? roomName,
    String? roomLabel,
    String? observation,
    bool? isDamaged,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      roomId: roomId ?? this.roomId,
      position: position ?? this.position,
      roomName: roomName ?? this.roomName,
      roomLabel: roomLabel ?? this.roomLabel,
      observation: observation ?? this.observation,
      isDamaged: isDamaged ?? this.isDamaged,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}