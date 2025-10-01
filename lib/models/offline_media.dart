import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:lince_inspecoes/utils/date_formatter.dart';

part 'offline_media.g.dart';

@HiveType(typeId: 5)
class OfflineMedia {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String inspectionId;
  @HiveField(2)
  final String? topicId;
  @HiveField(3)
  final String? itemId;
  @HiveField(4)
  final String? detailId;
  @HiveField(5)
  final String? nonConformityId;
  @HiveField(6)
  final String type; // image, video
  @HiveField(7)
  final String localPath;
  @HiveField(8)
  final String? cloudUrl;
  @HiveField(9)
  final String filename;
  @HiveField(10)
  final int? fileSize;
  @HiveField(11)
  final String? thumbnailPath;
  @HiveField(12)
  final int? duration; // Para vídeos, em segundos
  @HiveField(13)
  final int? width;
  @HiveField(14)
  final int? height;
  @HiveField(15)
  final bool isUploaded;
  @HiveField(16)
  final double uploadProgress;
  @HiveField(17)
  final DateTime createdAt;
  @HiveField(18)
  final DateTime updatedAt;
  @HiveField(20)
  final bool isDeleted;
  @HiveField(21)
  final String? source; // camera, gallery, import
  @HiveField(22)
  final bool
      isResolutionMedia; // NEW: indicates if this media is for NC resolution (solved_media)
  @HiveField(23)
  final int
      orderIndex; // Índice de ordenação fixa para preservar ordem cronológica

  OfflineMedia({
    required this.id,
    required this.inspectionId,
    this.topicId,
    this.itemId,
    this.detailId,
    this.nonConformityId,
    required this.type,
    required this.localPath,
    this.cloudUrl,
    required this.filename,
    this.fileSize,
    this.thumbnailPath,
    this.duration,
    this.width,
    this.height,
    this.isUploaded = false,
    this.uploadProgress = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.source,
    this.isResolutionMedia = false,
    this.orderIndex = 0,
  });

  factory OfflineMedia.create({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    required String type,
    required String localPath,
    required String filename,
    int? fileSize,
    int? width,
    int? height,
    int? duration,
    String? source,
    bool isResolutionMedia = false,
    int? orderIndex,
  }) {
    final now = DateFormatter.now();
    return OfflineMedia(
      id: const Uuid().v4(),
      inspectionId: inspectionId,
      topicId: topicId,
      itemId: itemId,
      detailId: detailId,
      nonConformityId: nonConformityId,
      type: type,
      localPath: localPath,
      filename: filename,
      fileSize: fileSize,
      width: width,
      height: height,
      duration: duration,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      source: source,
      isResolutionMedia: isResolutionMedia,
      orderIndex: orderIndex ??
          DateFormatter.now()
              .millisecondsSinceEpoch, // Use timestamp as default order
    );
  }

  factory OfflineMedia.fromJson(Map<String, dynamic> json) {
    return OfflineMedia.fromMap(json);
  }

  Map<String, dynamic> toJson() => toMap();

  factory OfflineMedia.fromMap(Map<String, dynamic> map) {
    // Helper to parse datetime from multiple possible formats
    DateTime? parseDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      // Firestore Timestamp
      if (value is Map && value.containsKey('_seconds')) {
        return DateTime.fromMillisecondsSinceEpoch(value['_seconds'] * 1000);
      }
      // Try toDate() method (Firestore Timestamp object)
      try {
        return value?.toDate?.call();
      } catch (e) {
        return null;
      }
    }

    // Try both camelCase (Firestore) and snake_case (local DB) for dates
    final createdAtValue = map['createdAt'] ?? map['created_at'];
    final updatedAtValue = map['updatedAt'] ?? map['updated_at'];

    return OfflineMedia(
      id: map['id']?.toString() ?? const Uuid().v4(),
      inspectionId: map['inspection_id'] as String,
      topicId: map['topic_id']?.toString(),
      itemId: map['item_id']?.toString(),
      detailId: map['detail_id']?.toString(),
      nonConformityId: map['non_conformity_id']?.toString(),
      type: map['type'] as String? ?? 'image',
      localPath: map['local_path'] as String? ?? '',
      cloudUrl: map['cloud_url'] as String?,
      filename: map['filename'] as String? ?? 'unknown',
      fileSize: map['file_size'] as int?,
      thumbnailPath: map['thumbnail_path'] as String?,
      duration: map['duration'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      isUploaded: map['is_uploaded'] is bool
          ? map['is_uploaded']
          : (map['is_uploaded'] as int? ?? 0) == 1,
      uploadProgress: (map['upload_progress'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDateTime(createdAtValue) ?? DateTime.now(),
      updatedAt: parseDateTime(updatedAtValue) ?? DateTime.now(),
      isDeleted: map['is_deleted'] is bool
          ? map['is_deleted']
          : (map['is_deleted'] as int? ?? 0) == 1,
      source: map['source'] as String?,
      isResolutionMedia: map['is_resolution_media'] is bool
          ? map['is_resolution_media']
          : (map['is_resolution_media'] as int? ?? 0) == 1,
      orderIndex: (map['order_index'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'inspection_id': inspectionId,
      'topic_id': topicId,
      'item_id': itemId,
      'detail_id': detailId,
      'non_conformity_id': nonConformityId,
      'type': type,
      'local_path': localPath,
      'cloud_url': cloudUrl,
      'filename': filename,
      'file_size': fileSize,
      'thumbnail_path': thumbnailPath,
      'duration': duration,
      'width': width,
      'height': height,
      'is_uploaded': isUploaded ? 1 : 0,
      'upload_progress': uploadProgress,
      // Use camelCase for Firestore compatibility
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'source': source,
      'is_resolution_media': isResolutionMedia ? 1 : 0,
      'order_index': orderIndex,
    };
  }

  OfflineMedia copyWith({
    String? id,
    String? inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
    String? nonConformityId,
    String? type,
    String? localPath,
    String? cloudUrl,
    String? filename,
    int? fileSize,
    String? thumbnailPath,
    int? duration,
    int? width,
    int? height,
    bool? isUploaded,
    double? uploadProgress,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? source,
    bool? isResolutionMedia,
    int? orderIndex,
  }) {
    return OfflineMedia(
      id: id ?? this.id,
      inspectionId: inspectionId ?? this.inspectionId,
      topicId: topicId ?? this.topicId,
      itemId: itemId ?? this.itemId,
      detailId: detailId ?? this.detailId,
      nonConformityId: nonConformityId ?? this.nonConformityId,
      type: type ?? this.type,
      localPath: localPath ?? this.localPath,
      cloudUrl: cloudUrl ?? this.cloudUrl,
      filename: filename ?? this.filename,
      fileSize: fileSize ?? this.fileSize,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      isUploaded: isUploaded ?? this.isUploaded,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      source: source ?? this.source,
      isResolutionMedia: isResolutionMedia ?? this.isResolutionMedia,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineMedia && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'OfflineMedia(id: $id, filename: $filename, type: $type, isUploaded: $isUploaded)';
  }

  // Getters utilitários
  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isReadyForUpload => !isUploaded;
  bool get isFullyUploaded => isUploaded && uploadProgress >= 100.0;
  bool get isUploading =>
      !isUploaded && uploadProgress > 0.0 && uploadProgress < 100.0;

  String get displayName => filename.split('.').first;
  String get extension => filename.split('.').last;

  String get statusDisplayName {
    if (isUploaded) return 'Enviado';
    if (isUploading) return 'Enviando...';
    if (isReadyForUpload) return 'Pronto para envio';
    return 'Pendente';
  }

  String get typeDisplayName {
    switch (type) {
      case 'image':
        return 'Imagem';
      case 'video':
        return 'Vídeo';
      default:
        return type;
    }
  }

  String get fileSizeDisplayName {
    if (fileSize == null) return 'Tamanho desconhecido';

    final sizeInBytes = fileSize!;
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  String get durationDisplayName {
    if (duration == null) return '';

    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
