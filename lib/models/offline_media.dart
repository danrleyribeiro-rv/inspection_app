// lib/models/offline_media.dart
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:flutter/foundation.dart';

part 'offline_media.g.dart';

@HiveType(typeId: 2)
@JsonSerializable()
class OfflineMedia extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String localPath;

  @HiveField(2)
  String inspectionId;

  @HiveField(3)
  String? topicId;

  @HiveField(4)
  String? itemId;

  @HiveField(5)
  String? detailId;

  @HiveField(6)
  String type; // 'image' or 'video'

  @HiveField(7)
  String fileName;

  @HiveField(8)
  DateTime createdAt;

  @HiveField(9)
  bool isProcessed;

  @HiveField(10)
  bool isUploaded;

  @HiveField(11)
  String? uploadUrl;

  @HiveField(12)
  Map<String, dynamic>? metadata;

  @HiveField(13)
  int? fileSize;

  @HiveField(14)
  int retryCount;

  @HiveField(15)
  DateTime? lastRetryAt;

  @HiveField(16)
  String? errorMessage;

  @HiveField(17)
  String? cloudUrl; // URL da mídia na nuvem (Firebase Storage)

  @HiveField(18)
  bool isDownloadedFromCloud; // Indica se foi baixada da nuvem

  OfflineMedia({
    required this.id,
    required this.localPath,
    required this.inspectionId,
    this.topicId,
    this.itemId,
    this.detailId,
    required this.type,
    required this.fileName,
    required this.createdAt,
    this.isProcessed = false,
    this.isUploaded = false,
    this.uploadUrl,
    this.metadata,
    this.fileSize,
    this.retryCount = 0,
    this.lastRetryAt,
    this.errorMessage,
    this.cloudUrl,
    this.isDownloadedFromCloud = false,
  });

  factory OfflineMedia.fromJson(Map<String, dynamic> json) => _$OfflineMediaFromJson(json);
  Map<String, dynamic> toJson() => _$OfflineMediaToJson(this);

  bool get needsUpload => isProcessed && !isUploaded;
  bool get hasError => errorMessage != null;
  bool get canRetry => isProcessed && !isUploaded && retryCount < 5;

  void markProcessed() {
    isProcessed = true;
    save();
  }

  void markUploaded(String url) {
    isUploaded = true;
    uploadUrl = url;
    errorMessage = null;
    debugPrint('OfflineMedia.markUploaded: Media ${id} marked as uploaded with URL: $url');
    save();
  }

  void markError(String error) {
    errorMessage = error;
    retryCount++;
    lastRetryAt = DateTime.now();
    save();
  }

  void resetError() {
    errorMessage = null;
    save();
  }

  void markDownloadedFromCloud(String cloudUrlParam) {
    isDownloadedFromCloud = true;
    cloudUrl = cloudUrlParam;
    isProcessed = true;
    errorMessage = null;
    save();
  }
}