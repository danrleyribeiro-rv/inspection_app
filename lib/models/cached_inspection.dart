import 'package:hive/hive.dart';

part 'cached_inspection.g.dart';

@HiveType(typeId: 0)
class CachedInspection extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  Map<String, dynamic> data;

  @HiveField(2)
  DateTime lastUpdated;

  @HiveField(3)
  bool needsSync;

  @HiveField(4)
  String localStatus; // Ex: 'cloud_only', 'downloaded', 'modified'

  CachedInspection({
    required this.id,
    required this.data,
    required this.lastUpdated,
    this.needsSync = false,
    this.localStatus = 'cloud_only',
  });
}