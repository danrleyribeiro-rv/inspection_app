class SyncProgress {
  final String inspectionId;
  final SyncPhase phase;
  final int current;
  final int total;
  final String message;
  
  SyncProgress({
    required this.inspectionId,
    required this.phase,
    required this.current,
    required this.total,
    required this.message,
  });
  
  double get progress => total > 0 ? current / total : 0.0;
}

enum SyncPhase {
  starting,
  downloading,
  uploading,
  completed,
  error,
}