import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'offline_media.g.dart';

@JsonSerializable()
class OfflineMedia {
  final String id;
  final String inspectionId;
  final String? topicId;
  final String? itemId;
  final String? detailId;
  final String? nonConformityId;
  final String type; // image, video
  final String localPath;
  final String? cloudUrl;
  final String filename;
  final int? fileSize;
  final String? mimeType;
  final String? thumbnailPath;
  final int? duration; // Para vídeos, em segundos
  final int? width;
  final int? height;
  final bool isProcessed;
  final bool isUploaded;
  final double uploadProgress;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool needsSync;
  final bool isDeleted;

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
    this.mimeType,
    this.thumbnailPath,
    this.duration,
    this.width,
    this.height,
    this.isProcessed = false,
    this.isUploaded = false,
    this.uploadProgress = 0.0,
    required this.createdAt,
    required this.updatedAt,
    this.needsSync = false,
    this.isDeleted = false,
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
    String? mimeType,
    int? width,
    int? height,
    int? duration,
  }) {
    final now = DateTime.now();
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
      mimeType: mimeType,
      width: width,
      height: height,
      duration: duration,
      createdAt: now,
      updatedAt: now,
      needsSync: true,
      isDeleted: false,
    );
  }

  factory OfflineMedia.fromJson(Map<String, dynamic> json) =>
      _$OfflineMediaFromJson(json);

  Map<String, dynamic> toJson() => _$OfflineMediaToJson(this);

  factory OfflineMedia.fromMap(Map<String, dynamic> map) {
    return OfflineMedia(
      id: map['id'] as String,
      inspectionId: map['inspection_id'] as String,
      topicId: map['topic_id'] as String?,
      itemId: map['item_id'] as String?,
      detailId: map['detail_id'] as String?,
      nonConformityId: map['non_conformity_id'] as String?,
      type: map['type'] as String,
      localPath: map['local_path'] as String,
      cloudUrl: map['cloud_url'] as String?,
      filename: map['filename'] as String,
      fileSize: map['file_size'] as int?,
      mimeType: map['mime_type'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      duration: map['duration'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      isProcessed: (map['is_processed'] as int? ?? 0) == 1,
      isUploaded: (map['is_uploaded'] as int? ?? 0) == 1,
      uploadProgress: (map['upload_progress'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      needsSync: (map['needs_sync'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
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
      'mime_type': mimeType,
      'thumbnail_path': thumbnailPath,
      'duration': duration,
      'width': width,
      'height': height,
      'is_processed': isProcessed ? 1 : 0,
      'is_uploaded': isUploaded ? 1 : 0,
      'upload_progress': uploadProgress,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'needs_sync': needsSync ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
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
    String? mimeType,
    String? thumbnailPath,
    int? duration,
    int? width,
    int? height,
    bool? isProcessed,
    bool? isUploaded,
    double? uploadProgress,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsSync,
    bool? isDeleted,
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
      mimeType: mimeType ?? this.mimeType,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      duration: duration ?? this.duration,
      width: width ?? this.width,
      height: height ?? this.height,
      isProcessed: isProcessed ?? this.isProcessed,
      isUploaded: isUploaded ?? this.isUploaded,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsSync: needsSync ?? this.needsSync,
      isDeleted: isDeleted ?? this.isDeleted,
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
    return 'OfflineMedia(id: $id, filename: $filename, type: $type, isProcessed: $isProcessed, isUploaded: $isUploaded)';
  }

  // Getters utilitários
  bool get isImage => type == 'image';
  bool get isVideo => type == 'video';
  bool get isReadyForUpload => isProcessed && !isUploaded;
  bool get isFullyUploaded => isUploaded && uploadProgress >= 100.0;
  bool get isProcessing => !isProcessed && !isUploaded;
  bool get isUploading => isProcessed && !isUploaded && uploadProgress > 0.0 && uploadProgress < 100.0;
  
  String get displayName => filename.split('.').first;
  String get extension => filename.split('.').last;
  
  String get statusDisplayName {
    if (isUploaded) return 'Enviado';
    if (isUploading) return 'Enviando...';
    if (isReadyForUpload) return 'Pronto para envio';
    if (isProcessing) return 'Processando...';
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