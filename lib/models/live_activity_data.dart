// lib/models/live_activity_data.dart
import 'dart:convert';

/// Modelo de dados para Live Activities (Dynamic Island no iOS)
class LiveActivityData {
  final String inspectionId;
  final String title;
  final String message;
  final int current;
  final int total;
  final double progress;
  final String? currentItem;
  final String? topicName;
  final String phase; // 'uploading', 'downloading', 'verifying', 'completed', 'error'
  final int? mediaCount;
  final String? estimatedTime;
  final String? speed;

  LiveActivityData({
    required this.inspectionId,
    required this.title,
    required this.message,
    required this.current,
    required this.total,
    required this.progress,
    this.currentItem,
    this.topicName,
    required this.phase,
    this.mediaCount,
    this.estimatedTime,
    this.speed,
  });

  Map<String, dynamic> toMap() {
    return {
      'inspectionId': inspectionId,
      'title': title,
      'message': message,
      'current': current,
      'total': total,
      'progress': progress,
      'currentItem': currentItem,
      'topicName': topicName,
      'phase': phase,
      'mediaCount': mediaCount,
      'estimatedTime': estimatedTime,
      'speed': speed,
    };
  }

  factory LiveActivityData.fromMap(Map<String, dynamic> map) {
    return LiveActivityData(
      inspectionId: map['inspectionId'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      current: map['current'] as int,
      total: map['total'] as int,
      progress: (map['progress'] as num).toDouble(),
      currentItem: map['currentItem'] as String?,
      topicName: map['topicName'] as String?,
      phase: map['phase'] as String,
      mediaCount: map['mediaCount'] as int?,
      estimatedTime: map['estimatedTime'] as String?,
      speed: map['speed'] as String?,
    );
  }

  String toJson() => json.encode(toMap());

  factory LiveActivityData.fromJson(String source) =>
      LiveActivityData.fromMap(json.decode(source) as Map<String, dynamic>);

  LiveActivityData copyWith({
    String? inspectionId,
    String? title,
    String? message,
    int? current,
    int? total,
    double? progress,
    String? currentItem,
    String? topicName,
    String? phase,
    int? mediaCount,
    String? estimatedTime,
    String? speed,
  }) {
    return LiveActivityData(
      inspectionId: inspectionId ?? this.inspectionId,
      title: title ?? this.title,
      message: message ?? this.message,
      current: current ?? this.current,
      total: total ?? this.total,
      progress: progress ?? this.progress,
      currentItem: currentItem ?? this.currentItem,
      topicName: topicName ?? this.topicName,
      phase: phase ?? this.phase,
      mediaCount: mediaCount ?? this.mediaCount,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      speed: speed ?? this.speed,
    );
  }
}
