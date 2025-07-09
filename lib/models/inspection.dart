import 'package:flutter/material.dart';

class Inspection {
  final String id;
  final String title;
  final String? cod;
  final String? street;
  final String? neighborhood;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? addressString;
  final Map<String, dynamic>? address;
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
  final bool isSynced;
  final DateTime? lastSyncAt;
  final bool hasLocalChanges;
  final List<Map<String, dynamic>>? topics;

  Inspection({
    required this.id,
    required this.title,
    this.cod,
    this.street,
    this.neighborhood,
    this.city,
    this.state,
    this.zipCode,
    this.addressString,
    this.address,
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
    this.isSynced = true,
    this.lastSyncAt,
    this.hasLocalChanges = false,
    this.topics,
  });

  Inspection copyWith({
    String? id,
    String? title,
    String? cod,
    String? street,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    String? addressString,
    Map<String, dynamic>? address,
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
    bool? isSynced,
    DateTime? lastSyncAt,
    bool? hasLocalChanges,
    List<Map<String, dynamic>>? topics,
  }) {
    return Inspection(
      id: id ?? this.id,
      title: title ?? this.title,
      cod: cod ?? this.cod,
      street: street ?? this.street,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      addressString: addressString ?? this.addressString,
      address: address ?? this.address,
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
      isSynced: isSynced ?? this.isSynced,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      hasLocalChanges: hasLocalChanges ?? this.hasLocalChanges,
      topics: topics ?? this.topics,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'title': title,
      'cod': cod,
      'street': street,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'address_string': addressString,
      'address': address?.toString(),
      'status': status,
      'observation': observation,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'project_id': projectId,
      'inspector_id': inspectorId,
      'is_templated': isTemplated ? 1 : 0,
      'template_id': templateId,
      'is_synced': isSynced ? 1 : 0,
      'last_sync_at': lastSyncAt?.toIso8601String(),
      'has_local_changes': hasLocalChanges ? 1 : 0,
      'topics': topics?.toString(),
    };

    return data;
  }

  Map<String, dynamic> toMap() => toJson();

  factory Inspection.fromJson(Map<String, dynamic> json) {

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

    bool isSynced = true;
    if (json.containsKey('is_synced')) {
      if (json['is_synced'] is bool) {
        isSynced = json['is_synced'];
      } else if (json['is_synced'] is String) {
        isSynced = json['is_synced'].toLowerCase() == 'true';
      } else if (json['is_synced'] == 1) {
        isSynced = true;
      } else if (json['is_synced'] == 0) {
        isSynced = false;
      }
    }

    bool hasLocalChanges = false;
    if (json.containsKey('has_local_changes')) {
      if (json['has_local_changes'] is bool) {
        hasLocalChanges = json['has_local_changes'];
      } else if (json['has_local_changes'] is String) {
        hasLocalChanges = json['has_local_changes'].toLowerCase() == 'true';
      } else if (json['has_local_changes'] == 1) {
        hasLocalChanges = true;
      }
    }

    List<Map<String, dynamic>>? topics;
    if (json['topics'] != null) {
      if (json['topics'] is List) {
        topics = List<Map<String, dynamic>>.from(json['topics'].map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return item;
        }));
      } else if (json['topics'] is String) {
        // Tentar parsear string JSON se necessário
        try {
          final parsed = json['topics'];
          if (parsed.startsWith('[')) {
            // É um array JSON em string - mas não fazer parse aqui, deixar como string
            topics = null; // Será processado depois
          }
        } catch (e) {
          // Se não conseguir parsear, ignorar
        }
      }
    }

    return Inspection(
      id: json['id'].toString(),
      cod: json['cod']?.toString(),
      title: json['title'] ?? 'Untitled',
      street: json['street'],
      neighborhood: json['neighborhood'],
      city: json['city'],
      state: json['state'],
      zipCode: json['zip_code'],
      addressString: json['address_string'],
      address: json['address'] is Map
          ? Map<String, dynamic>.from(json['address'])
          : null,
      status: json['status'] ?? 'pending',
      observation: json['observation'],
      scheduledDate: _parseDateTime(json['scheduled_date']),
      finishedAt: _parseDateTime(json['finished_at']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
      projectId: json['project_id']?.toString(),
      inspectorId: json['inspector_id']?.toString(),
      isTemplated: isTemplated,
      templateId: json['template_id']?.toString(),
      isSynced: isSynced,
      lastSyncAt: _parseDateTime(json['last_sync_at']),
      hasLocalChanges: hasLocalChanges,
      topics: topics,
    );
  }

  static Inspection fromMap(Map<String, dynamic> map) =>
      Inspection.fromJson(map);

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    } else if (value is String) {
      return DateTime.parse(value);
    } else if (value is Map<String, dynamic>) {
      try {
        int seconds;
        int nanoseconds;

        // Handle new Firestore Timestamp format
        if (value.containsKey('seconds') && value.containsKey('nanoseconds')) {
          seconds = value['seconds'] as int;
          nanoseconds = value['nanoseconds'] as int;
        }
        // Handle legacy format
        else if (value.containsKey('_seconds') &&
            value.containsKey('_nanoseconds')) {
          seconds = value['_seconds'] as int;
          nanoseconds = value['_nanoseconds'] as int;
        } else {
          debugPrint('Invalid Timestamp map format');
          return null;
        }

        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds / 1000000).round(),
        );
      } catch (e) {
        debugPrint('Error parsing Firestore timestamp: $e');
        return null;
      }
    } else if (value.runtimeType.toString().contains('Timestamp')) {
      try {
        // Use dynamic invocation for Timestamp.toDate()
        final toDateMethod = (value as dynamic).toDate;
        if (toDateMethod != null) {
          return toDateMethod();
        }
        debugPrint('Invalid Timestamp object: missing toDate method');
        return null;
      } catch (e) {
        debugPrint('Error parsing Timestamp object: $e');
        return null;
      }
    } else {
      debugPrint('Unsupported datetime format: ${value.runtimeType}');
      return null;
    }
  }
}
