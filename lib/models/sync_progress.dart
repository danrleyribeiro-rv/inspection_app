class SyncProgress {
  final String inspectionId;
  final SyncPhase phase;
  final int current;
  final int total;
  final String message;
  final String? currentItem;
  final String? itemType;
  final String? topicName;
  final int? mediaCount;
  final int? totalInspections;
  final int? currentInspectionIndex;
  final bool isVerifying;
  final List<String>? failedItems;
  
  SyncProgress({
    required this.inspectionId,
    required this.phase,
    required this.current,
    required this.total,
    required this.message,
    this.currentItem,
    this.itemType,
    this.topicName,
    this.mediaCount,
    this.totalInspections,
    this.currentInspectionIndex,
    this.isVerifying = false,
    this.failedItems,
  });
  
  double get progress => total > 0 ? current / total : 0.0;
  
  SyncProgress copyWith({
    String? inspectionId,
    SyncPhase? phase,
    int? current,
    int? total,
    String? message,
    String? currentItem,
    String? itemType,
    String? topicName,
    int? mediaCount,
    int? totalInspections,
    int? currentInspectionIndex,
    bool? isVerifying,
    List<String>? failedItems,
  }) {
    return SyncProgress(
      inspectionId: inspectionId ?? this.inspectionId,
      phase: phase ?? this.phase,
      current: current ?? this.current,
      total: total ?? this.total,
      message: message ?? this.message,
      currentItem: currentItem ?? this.currentItem,
      itemType: itemType ?? this.itemType,
      topicName: topicName ?? this.topicName,
      mediaCount: mediaCount ?? this.mediaCount,
      totalInspections: totalInspections ?? this.totalInspections,
      currentInspectionIndex: currentInspectionIndex ?? this.currentInspectionIndex,
      isVerifying: isVerifying ?? this.isVerifying,
      failedItems: failedItems ?? this.failedItems,
    );
  }
}

enum SyncPhase {
  starting,
  downloading,
  uploading,
  verifying,
  completed,
  error,
}