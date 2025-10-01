import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

part 'inspection.g.dart';

@HiveType(typeId: 0)
class Inspection {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String? cod;
  @HiveField(3)
  final String? street;
  @HiveField(4)
  final String? neighborhood;
  @HiveField(5)
  final String? city;
  @HiveField(6)
  final String? state;
  @HiveField(7)
  final String? zipCode;
  @HiveField(8)
  final String? addressString;
  @HiveField(9)
  final Map<String, dynamic>? address;
  @HiveField(10)
  final String status;
  @HiveField(11)
  final String? observation;
  @HiveField(12)
  final DateTime? scheduledDate;
  @HiveField(13)
  final DateTime? finishedAt;
  @HiveField(14)
  final DateTime createdAt;
  @HiveField(15)
  final DateTime updatedAt;
  @HiveField(16)
  final String? projectId;
  @HiveField(17)
  final String? inspectorId;
  @HiveField(18)
  final bool isTemplated;
  @HiveField(19)
  final String? templateId;
  @HiveField(26)
  final String? area;
  @HiveField(27)
  final DateTime? deletedAt;
  @HiveField(28)
  final DateTime? lastSyncAt;

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
    this.area,
    this.deletedAt,
    this.lastSyncAt,
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
    String? area,
    DateTime? deletedAt,
    DateTime? lastSyncAt,
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
      area: area ?? this.area,
      deletedAt: deletedAt ?? this.deletedAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
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
      'address': address?.toString(), // Convert to string for local DB
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
      'area': area,
      'deleted_at': deletedAt?.toIso8601String(),
      'is_deleted':
          deletedAt != null ? 1 : 0, // Se tem deleted_at, está deletada
      'last_sync_at': lastSyncAt?.toIso8601String(),
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
      createdAt: _parseDateTime(json['created_at']) ?? DateFormatter.now(),
      updatedAt: _parseDateTime(json['updated_at']) ?? DateFormatter.now(),
      projectId: json['project_id']?.toString(),
      inspectorId: json['inspector_id']?.toString(),
      isTemplated: isTemplated,
      templateId: json['template_id']?.toString(),
      area: json['area']?.toString(),
      deletedAt: _parseDateTime(json['deleted_at']),
      lastSyncAt: _parseDateTime(json['last_sync_at']),
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
