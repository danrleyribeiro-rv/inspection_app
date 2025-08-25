import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math';
import '../storage/database_helper.dart';

abstract class BaseRepository<T> {
  String get tableName;
  
  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T entity);
  
  Future<Database> get database => DatabaseHelper.database;

  Future<String> insert(T entity) async {
    final db = await database;
    final map = toMap(entity);
    
    // Generate ID if null
    if (map['id'] == null) {
      map['id'] = _generateFirestoreSafeId();
    }
    
    map['created_at'] = DateTime.now().toIso8601String();
    map['updated_at'] = DateTime.now().toIso8601String();
    map['needs_sync'] = 1;
    
    await db.insert(tableName, map);
    return map['id'] as String;
  }
  
  /// Generates a Firestore-safe ID
  String _generateFirestoreSafeId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    // Use uppercase to avoid issues with Firestore field names
    return '$timestamp${random.toString().padLeft(6, '0')}${tableName.toUpperCase()}';
  }

  Future<void> update(T entity) async {
    final db = await database;
    final map = toMap(entity);
    map['updated_at'] = DateTime.now().toIso8601String();
    map['needs_sync'] = 1;
    
    await db.update(
      tableName,
      map,
      where: 'id = ?',
      whereArgs: [map['id']],
    );
  }

  Future<void> markForSync(String id) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'needs_sync': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }


  Future<void> delete(String id) async {
    final db = await database;
    await db.update(
      tableName,
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'needs_sync': 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hardDelete(String id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<T?> findById(String id) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    
    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
  }

  Future<List<T>> findAll() async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'is_deleted = 0',
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<List<T>> findWhere(String whereClause, List<dynamic> whereArgs) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'is_deleted = 0 AND $whereClause',
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableName WHERE is_deleted = 0'
    );
    return result.first['count'] as int;
  }

  Future<List<T>> findPendingSync() async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'needs_sync = 1',
      orderBy: 'updated_at ASC',
    );
    
    return maps.map((map) => fromMap(map)).toList();
  }

  Future<void> markSynced(String id) async {
    final db = await database;
    await db.update(
      tableName,
      {'needs_sync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllSynced() async {
    final db = await database;
    await db.update(
      tableName,
      {'needs_sync': 0},
      where: 'needs_sync = 1',
    );
  }

  Future<void> insertOrUpdate(T entity) async {
    final map = toMap(entity);
    final id = map['id'] as String;
    
    final existing = await findById(id);
    if (existing != null) {
      await update(entity);
    } else {
      await insert(entity);
    }
  }

  // Método específico para inserir dados da nuvem (sem marcar como needs_sync)
  Future<void> insertOrUpdateFromCloud(T entity) async {
    final map = toMap(entity);
    final id = map['id'] as String;
    final db = await database;
    
    
    // Preservar timestamps originais da nuvem
    // Verificar existência sem filtro is_deleted para dados da nuvem
    final existingCheck = await db.query(tableName, where: 'id = ?', whereArgs: [id]);
    if (existingCheck.isNotEmpty) {
      map['needs_sync'] = 0; // Dados da nuvem não precisam sync
      
      await db.update(
        tableName,
        map,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      map['needs_sync'] = 0; // Dados da nuvem não precisam sync
      
      try {
        await db.insert(tableName, map);
        
      } catch (e) {
        
        // Se for erro de constraint UNIQUE, tentar INSERT OR REPLACE como fallback
        if (e.toString().contains('UNIQUE constraint failed')) {
          try {
            await db.execute(
              'INSERT OR REPLACE INTO $tableName (${map.keys.join(', ')}) VALUES (${map.keys.map((_) => '?').join(', ')})',
              map.values.toList(),
            );
          } catch (fallbackError) {
            debugPrint('BaseRepository: Error in fallback INSERT OR REPLACE: $fallbackError');
            rethrow;
          }
        } else {
          rethrow;
        }
      }
    }
  }

  Future<void> batchInsert(List<T> entities) async {
    final db = await database;
    final batch = db.batch();
    
    for (final entity in entities) {
      final map = toMap(entity);
      map['created_at'] = DateTime.now().toIso8601String();
      map['updated_at'] = DateTime.now().toIso8601String();
      map['needs_sync'] = 1;
      
      batch.insert(tableName, map);
    }
    
    await batch.commit();
  }

  Future<void> batchUpdate(List<T> entities) async {
    final db = await database;
    final batch = db.batch();
    
    for (final entity in entities) {
      final map = toMap(entity);
      map['updated_at'] = DateTime.now().toIso8601String();
      map['needs_sync'] = 1;
      
      batch.update(
        tableName,
        map,
        where: 'id = ?',
        whereArgs: [map['id']],
      );
    }
    
    await batch.commit();
  }

  Future<void> batchInsertOrUpdate(List<T> entities) async {
    final db = await database;
    final batch = db.batch();
    
    for (final entity in entities) {
      final map = toMap(entity);
      final id = map['id'] as String;
      
      final existing = await findById(id);
      if (existing != null) {
        map['updated_at'] = DateTime.now().toIso8601String();
        map['needs_sync'] = 1;
        
        batch.update(
          tableName,
          map,
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        map['created_at'] = DateTime.now().toIso8601String();
        map['updated_at'] = DateTime.now().toIso8601String();
        map['needs_sync'] = 1;
        
        batch.insert(tableName, map);
      }
    }
    
    await batch.commit();
  }
}