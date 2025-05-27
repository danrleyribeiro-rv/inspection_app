// lib/services/cache_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class CacheService {
  static final _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _inspectionsKey = 'cached_inspections';
  static const String _syncQueueKey = 'sync_queue';

  Future<void> cacheInspection(String id, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = await getCachedInspections();
    cached[id] = {
      'data': data,
      'lastUpdated': DateTime.now().toIso8601String(),
      'needsSync': false,
    };
    await prefs.setString(_inspectionsKey, json.encode(cached));
  }

  Future<Map<String, dynamic>?> getCachedInspection(String id) async {
    final cached = await getCachedInspections();
    return cached[id]?['data'];
  }

  Future<Map<String, dynamic>> getCachedInspections() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString(_inspectionsKey) ?? '{}';
    return Map<String, dynamic>.from(json.decode(cachedString));
  }

// lib/services/cache_service.dart (continuação)
 Future<void> markForSync(String id) async {
   final prefs = await SharedPreferences.getInstance();
   final syncQueue = await getSyncQueue();
   if (!syncQueue.contains(id)) {
     syncQueue.add(id);
     await prefs.setStringList(_syncQueueKey, syncQueue);
   }
 }

 Future<List<String>> getSyncQueue() async {
   final prefs = await SharedPreferences.getInstance();
   return prefs.getStringList(_syncQueueKey) ?? [];
 }

 Future<void> markSynced(String id) async {
   final prefs = await SharedPreferences.getInstance();
   final syncQueue = await getSyncQueue();
   syncQueue.remove(id);
   await prefs.setStringList(_syncQueueKey, syncQueue);
 }

 Future<void> clearCache() async {
   final prefs = await SharedPreferences.getInstance();
   await prefs.remove(_inspectionsKey);
   await prefs.remove(_syncQueueKey);
 }
}