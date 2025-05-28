import 'package:hive_flutter/hive_flutter.dart';
import 'package:inspection_app/models/cached_inspection.dart';

class CacheService {
  static const String _inspectionsBoxName = 'inspections';

  static Future<void> initialize() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CachedInspectionAdapter());
    await Hive.openBox<CachedInspection>(_inspectionsBoxName);
  }

  Box<CachedInspection> get _inspectionsBox => Hive.box<CachedInspection>(_inspectionsBoxName);

  Future<void> cacheInspection(String id, Map<String, dynamic> data) async {
    final cached = CachedInspection(
      id: id,
      data: data,
      lastUpdated: DateTime.now(),
      needsSync: false,
    );
    await _inspectionsBox.put(id, cached);
  }

  CachedInspection? getCachedInspection(String id) {
    return _inspectionsBox.get(id);
  }

  Future<void> markForSync(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = true;
      await cached.save();
    }
  }

  List<CachedInspection> getInspectionsNeedingSync() {
    return _inspectionsBox.values.where((inspection) => inspection.needsSync).toList();
  }

  Future<void> markSynced(String id) async {
    final cached = _inspectionsBox.get(id);
    if (cached != null) {
      cached.needsSync = false;
      await cached.save();
    }
  }

  Future<void> clearCache() async {
    await _inspectionsBox.clear();
  }
}