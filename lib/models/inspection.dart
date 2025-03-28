// lib/models/inspection.dart
class Inspection {
  final int id;
  final String title;
  final String? observation;
  final String? cep;
  final String? street;
  final String? number;
  final String? neighborhood;
  final String? state;
  final String? city;
  final int? templateId;
  final String? inspectorId;
  final String status;
  final DateTime? scheduledDate;
  final DateTime? finishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? projectId;

  Inspection({
    required this.id,
    required this.title,
    this.observation,
    this.cep,
    this.street,
    this.number,
    this.neighborhood,
    this.state,
    this.city,
    this.templateId,
    this.inspectorId,
    required this.status,
    this.scheduledDate,
    this.finishedAt,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.projectId,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'],
      title: json['title'],
      observation: json['observation'],
      cep: json['cep'],
      street: json['street'],
      number: json['number'],
      neighborhood: json['neighborhood'],
      state: json['state'],
      city: json['city'],
      templateId: json['template_id'],
      inspectorId: json['inspector_id'],
      status: json['status'],
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.parse(json['scheduled_date'])
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.parse(json['deleted_at'])
          : null,
      projectId: json['project_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'observation': observation,
      'cep': cep,
      'street': street,
      'number': number,
      'neighborhood': neighborhood,
      'state': state,
      'city': city,
      'template_id': templateId,
      'inspector_id': inspectorId,
      'status': status,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'project_id': projectId,
    };
  }

  Inspection copyWith({
    int? id,
    String? title,
    String? observation,
    String? cep,
    String? street,
    String? number,
    String? neighborhood,
    String? state,
    String? city,
    int? templateId,
    String? inspectorId,
    String? status,
    DateTime? scheduledDate,
    DateTime? finishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? projectId,
  }) {
    return Inspection(
      id: id ?? this.id,
      title: title ?? this.title,
      observation: observation ?? this.observation,
      cep: cep ?? this.cep,
      street: street ?? this.street,
      number: number ?? this.number,
      neighborhood: neighborhood ?? this.neighborhood,
      state: state ?? this.state,
      city: city ?? this.city,
      templateId: templateId ?? this.templateId,
      inspectorId: inspectorId ?? this.inspectorId,
      status: status ?? this.status,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      finishedAt: finishedAt ?? this.finishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      projectId: projectId ?? this.projectId,
    );
  }
}