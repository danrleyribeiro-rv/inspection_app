// lib/models/inspection.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Inspection {
  final String id;
  final String title;
  final String? street;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? zipCode;
  final String status;
  final String? observation;
  final DateTime? scheduledDate;
  final DateTime? finishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? projectId;
  final String? inspectorId;
  final bool isTemplated;
  final String? templateId;

  final DateTime? lastCheckpointAt;
  final String? lastCheckpointBy;
  final String? lastCheckpointMessage;
  final double? lastCheckpointCompletion;

  Inspection({
    required this.id,
    required this.title,
    this.street,
    this.neighborhood,
    this.city,
    this.state,
    this.zipCode,
    required this.status,
    this.observation,
    this.scheduledDate,
    this.finishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.projectId,
    this.inspectorId,
    this.isTemplated = false,
    this.templateId,
    this.lastCheckpointAt,
    this.lastCheckpointBy,
    this.lastCheckpointMessage,
    this.lastCheckpointCompletion,
  });

  // Create a copy of this inspection with the given fields replaced
  Inspection copyWith({
    String? id,
    String? title,
    String? street,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    String? status,
    String? observation,
    DateTime? scheduledDate,
    DateTime? finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? projectId,
    String? inspectorId,
    bool? isTemplated,
    String? templateId,
    DateTime? lastCheckpointAt,
    String? lastCheckpointBy,
    String? lastCheckpointMessage,
    double? lastCheckpointCompletion,
  }) {
    return Inspection(
      id: id ?? this.id,
      title: title ?? this.title,
      street: street ?? this.street,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      status: status ?? this.status,
      observation: observation ?? this.observation,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectId: projectId ?? this.projectId,
      inspectorId: inspectorId ?? this.inspectorId,
      isTemplated: isTemplated ?? this.isTemplated,
      templateId: templateId ?? this.templateId,
      lastCheckpointAt: lastCheckpointAt ?? this.lastCheckpointAt,
      lastCheckpointBy: lastCheckpointBy ?? this.lastCheckpointBy,
      lastCheckpointMessage:
          lastCheckpointMessage ?? this.lastCheckpointMessage,
      lastCheckpointCompletion:
          lastCheckpointCompletion ?? this.lastCheckpointCompletion,
    );
  }

  // Convert to a Map (JSON)
  Map<String, dynamic> toJson() {
    // Mapa base com todos os campos existentes
    final Map<String, dynamic> data = {
      'id': id,
      'title': title,
      'street': street,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'status': status,
      'observation': observation,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'project_id': projectId,
      'inspector_id': inspectorId,
      'is_templated': isTemplated,
      'template_id': templateId,
    };

    // Adicione os novos campos relacionados a checkpoints
    if (lastCheckpointAt != null) {
      data['last_checkpoint_at'] = lastCheckpointAt!.toIso8601String();
    }
    if (lastCheckpointBy != null) {
      data['last_checkpoint_by'] = lastCheckpointBy;
    }
    if (lastCheckpointMessage != null) {
      data['last_checkpoint_message'] = lastCheckpointMessage;
    }
    if (lastCheckpointCompletion != null) {
      data['last_checkpoint_completion'] = lastCheckpointCompletion;
    }

    return data;
  }

  Map<String, dynamic> toMap() => toJson();

  // Create an Inspection from a Map (JSON)
  factory Inspection.fromJson(Map<String, dynamic> json) {
    // Processando campos relacionados ao template
    bool isTemplated = false;
    if (json.containsKey('is_templated')) {
      if (json['is_templated'] is bool) {
        isTemplated = json['is_templated'];
      } else if (json['is_templated'] is String) {
        isTemplated = json['is_templated'].toLowerCase() == 'true';
      } else if (json['is_templated'] == 1) {
        isTemplated = true;
      }
    }
    DateTime? lastCheckpointAt;
    if (json['last_checkpoint_at'] != null) {
      if (json['last_checkpoint_at'] is Timestamp) {
        lastCheckpointAt = (json['last_checkpoint_at'] as Timestamp).toDate();
      } else if (json['last_checkpoint_at'] is String) {
        lastCheckpointAt = DateTime.parse(json['last_checkpoint_at']);
      }
    }

    String? templateId = json['template_id']?.toString();

    return Inspection(
      id: json['id'].toString(),
      title: json['title'] ?? 'Untitled',
      street: json['street'],
      neighborhood: json['neighborhood'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zip_code'],
      status: json['status'] ?? 'pending',
      observation: json['observation'],
      scheduledDate: _parseDateTime(json['scheduled_date']),
      finishedAt: _parseDateTime(json['finished_at']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      projectId: json['project_id']?.toString(),
      inspectorId: json['inspector_id']?.toString(),
      isTemplated: isTemplated,
      templateId: templateId,
      lastCheckpointAt: lastCheckpointAt,
      lastCheckpointBy: json['last_checkpoint_by'],
      lastCheckpointMessage: json['last_checkpoint_message'],
      lastCheckpointCompletion: json['last_checkpoint_completion'] != null
          ? (json['last_checkpoint_completion'] as num).toDouble()
          : null,
    );
  }

  static Inspection fromMap(Map<String, dynamic> map) =>
      Inspection.fromJson(map);

  // Helper method to parse DateTime from various formats
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.parse(value);
    } else if (value is Map &&
        value['_seconds'] != null &&
        value['_nanoseconds'] != null) {
      // Handle Firestore timestamps
      try {
        // Convert Firestore timestamp to DateTime
        int seconds = value['_seconds'];
        int nanoseconds = value['_nanoseconds'];
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds / 1000000).round(),
        );
      } catch (e) {
        print('Error parsing Firestore timestamp: $e');
        return null;
      }
    } else {
      try {
        // Try to convert to date if it has a toDate() method
        return value.toDate();
      } catch (e) {
        print('Error parsing unknown datetime format: $e');
        return null;
      }
    }
  }
}
