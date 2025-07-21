import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:lince_inspecoes/models/inspection.dart';
import 'package:uuid/uuid.dart';

class SQLiteStorageService {
  static SQLiteStorageService? _instance;
  static SQLiteStorageService get instance =>
      _instance ??= SQLiteStorageService._();

  SQLiteStorageService._();

  Database? _database;
  Directory? _mediaDirectory;
  Directory? _documentsDirectory;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _documentsDirectory = await getApplicationDocumentsDirectory();

    // Criar diretório para arquivos de mídia permanentes
    _mediaDirectory = Directory(p.join(_documentsDirectory!.path, 'media'));
    if (!await _mediaDirectory!.exists()) {
      await _mediaDirectory!.create(recursive: true);
    }

    // Inicializar banco de dados
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'lince_inspecoes.db');

    _database = await openDatabase(
      path,
      version: 2, // Increment version for schema changes
      onCreate: _createDatabase,
      onUpgrade: _onUpgrade, // Add onUpgrade callback
    );

    _isInitialized = true;
    debugPrint('SQLiteStorageService: Initialized with database at $path');
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Tabela de inspeções
    await db.execute('''
      CREATE TABLE inspections (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        status TEXT NOT NULL,
        inspector_id TEXT NOT NULL,
        data TEXT NOT NULL,
        scheduled_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        last_synced INTEGER,
        needs_sync INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabela de templates
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Tabela de arquivos de mídia
    await db.execute('''
      CREATE TABLE media_files (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        topic_id TEXT,
        item_id TEXT,
        detail_id TEXT,
        file_type TEXT NOT NULL,
        file_name TEXT NOT NULL,
        local_path TEXT NOT NULL,
        cloud_url TEXT,
        is_uploaded INTEGER NOT NULL DEFAULT 0,
        is_processed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id)
      )
    ''');

    // Tabela de configurações
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Índices para melhor performance
    await db.execute(
        'CREATE INDEX idx_inspections_inspector ON inspections(inspector_id)');
    await db
        .execute('CREATE INDEX idx_inspections_status ON inspections(status)');
    await db.execute(
        'CREATE INDEX idx_media_inspection ON media_files(inspection_id)');
    await db.execute(
        'CREATE INDEX idx_media_upload ON media_files(is_uploaded, is_processed)');

    debugPrint('SQLiteStorageService: Database created successfully');
  }

  Directory get mediaDirectory => _mediaDirectory!;

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint(
        'SQLiteStorageService: Upgrading database from version $oldVersion to $newVersion');
    // Example of how to handle schema migrations:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE inspections ADD COLUMN new_column TEXT;');
    // }
    // if (oldVersion < 3) {
    //   await db.execute('CREATE TABLE new_table (id TEXT PRIMARY KEY);');
    // }
  }

  // INSPEÇÕES
  Future<void> saveInspection(Inspection inspection) async {
    await _ensureInitialized();

    final inspectionData = {
      'id': inspection.id,
      'title': inspection.title,
      'status': inspection.status,
      'inspector_id': inspection.inspectorId,
      'data': jsonEncode(inspection.toJson()), // Use toJson() for full data
      'scheduled_date': inspection.scheduledDate?.millisecondsSinceEpoch,
      'created_at': inspection.createdAt.millisecondsSinceEpoch,
      'updated_at': inspection.updatedAt.millisecondsSinceEpoch,
      'last_synced': inspection.lastSyncAt?.millisecondsSinceEpoch,
      'needs_sync': (inspection.hasLocalChanges || !inspection.isSynced)
          ? 1
          : 0, // Map to needs_sync
    };

    await _database!.insert(
      'inspections',
      inspectionData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('SQLiteStorageService: Saved inspection ${inspection.id}');
  }

  Future<Inspection?> getInspection(String id) async {
    await _ensureInitialized();

    final result = await _database!.query(
      'inspections',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    try {
      final data =
          jsonDecode(result.first['data'] as String) as Map<String, dynamic>;
      return Inspection.fromMap(data);
    } catch (e) {
      debugPrint('SQLiteStorageService: Error parsing inspection $id: $e');
      return null;
    }
  }

  Future<List<Inspection>> getInspectionsByInspector(String inspectorId) async {
    await _ensureInitialized();

    final result = await _database!.query(
      'inspections',
      where: 'inspector_id = ?',
      whereArgs: [inspectorId],
      orderBy: 'updated_at DESC',
    );

    final inspections = <Inspection>[];

    for (final row in result) {
      try {
        final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        inspections.add(Inspection.fromMap(data));
      } catch (e) {
        debugPrint(
            'SQLiteStorageService: Error parsing inspection ${row['id']}: $e');
      }
    }

    return inspections;
  }

  Future<void> markInspectionSynced(String id) async {
    await _ensureInitialized();

    final inspection = await getInspection(id);
    if (inspection == null) return;

    final updatedInspection = inspection.copyWith(
      isSynced: true,
      lastSyncAt: DateTime.now(),
      hasLocalChanges: false, // Assuming it's synced, local changes are resolved
      status: 'completed', // Reset status from 'modified' to 'completed' after sync
    );
    
    debugPrint('SQLiteStorageService: Original inspection status: "${inspection.status}"');
    debugPrint('SQLiteStorageService: Updated inspection status: "${updatedInspection.status}"');

    await _database!.update(
      'inspections',
      {
        'needs_sync': 0,
        'last_synced': updatedInspection.lastSyncAt?.millisecondsSinceEpoch,
        'updated_at': updatedInspection.updatedAt.millisecondsSinceEpoch,
        'data': jsonEncode(updatedInspection.toJson()), // Update the data field
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    
    debugPrint('SQLiteStorageService: Marked inspection $id as synced - status reset to completed');
  }

  Future<List<Inspection>> getInspectionsNeedingSync() async {
    await _ensureInitialized();

    final result = await _database!.query(
      'inspections',
      where: 'needs_sync = 1',
    );

    final inspections = <Inspection>[];
    for (final row in result) {
      try {
        final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
        inspections.add(Inspection.fromMap(data));
      } catch (e) {
        debugPrint(
            'SQLiteStorageService: Error parsing inspection ${row['id']}: $e');
      }
    }
    return inspections;
  }

  // TEMPLATES
  Future<void> saveTemplate(
      String id, String name, Map<String, dynamic> data) async {
    await _ensureInitialized();

    final templateData = {
      'id': id,
      'name': name,
      'data': jsonEncode(data),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    await _database!.insert(
      'templates',
      templateData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint('SQLiteStorageService: Saved template $id');
  }

  Future<Map<String, dynamic>?> getTemplate(String id) async {
    await _ensureInitialized();

    final result = await _database!.query(
      'templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    try {
      return jsonDecode(result.first['data'] as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('SQLiteStorageService: Error parsing template $id: $e');
      return null;
    }
  }

  // ARQUIVOS DE MÍDIA
  Future<String> saveMediaFile(
    String inspectionId,
    String fileName,
    List<int> fileBytes, {
    String? topicId,
    String? itemId,
    String? detailId,
    String fileType = 'image',
  }) async {
    await _ensureInitialized();

    final mediaId = const Uuid().v4();
    final extension = p.extension(fileName);
    final newFileName = '$mediaId$extension';
    final filePath = p.join(_mediaDirectory!.path, newFileName);

    // Salvar arquivo no sistema de arquivos permanente
    final file = File(filePath);
    await file.writeAsBytes(fileBytes);

    // Salvar metadata no banco
    final mediaData = {
      'id': mediaId,
      'inspection_id': inspectionId,
      'topic_id': topicId,
      'item_id': itemId,
      'detail_id': detailId,
      'file_type': fileType,
      'file_name': fileName,
      'local_path': filePath,
      'is_processed': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    await _database!.insert('media_files', mediaData);

    debugPrint('SQLiteStorageService: Saved media file $mediaId at $filePath');

    return mediaId;
  }

  Future<File?> getMediaFile(String mediaId) async {
    await _ensureInitialized();

    final result = await _database!.query(
      'media_files',
      where: 'id = ?',
      whereArgs: [mediaId],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final filePath = result.first['local_path'] as String;
    final file = File(filePath);
    return await file.exists() ? file : null;
  }

  Future<List<Map<String, dynamic>>> getMediaFilesByInspection(
      String inspectionId) async {
    await _ensureInitialized();

    return await _database!.query(
      'media_files',
      where: 'inspection_id = ?',
      whereArgs: [inspectionId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> markMediaUploaded(String mediaId, String cloudUrl) async {
    await _ensureInitialized();

    await _database!.update(
      'media_files',
      {
        'cloud_url': cloudUrl,
        'is_uploaded': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  // Deletar arquivo de mídia
  Future<void> deleteMediaFile(String mediaId) async {
    await _ensureInitialized();

    await _database!.delete(
      'media_files',
      where: 'id = ?',
      whereArgs: [mediaId],
    );
  }

  Future<List<Map<String, dynamic>>> getMediaFilesNeedingUpload() async {
    await _ensureInitialized();

    return await _database!.query(
      'media_files',
      where: 'is_uploaded = 0 AND is_processed = 1',
    );
  }

  // CONFIGURAÇÕES
  Future<void> setSetting(String key, String value) async {
    await _ensureInitialized();

    final settingData = {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    await _database!.insert(
      'settings',
      settingData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    await _ensureInitialized();

    final result = await _database!.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    return result.isEmpty ? null : result.first['value'] as String?;
  }

  // LIMPEZA
  Future<void> clearAllData() async {
    await _ensureInitialized();

    await _database!.delete('inspections');
    await _database!.delete('templates');
    await _database!.delete('media_files');
    await _database!.delete('settings');

    // Limpar arquivos de mídia
    if (await _mediaDirectory!.exists()) {
      await _mediaDirectory!.delete(recursive: true);
      await _mediaDirectory!.create(recursive: true);
    }

    debugPrint('SQLiteStorageService: Cleared all data');
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Helper para verificar se inspeção existe
  Future<bool> hasInspection(String id) async {
    await _ensureInitialized();

    final result = await _database!.query(
      'inspections',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // Helper para verificar se template existe
  Future<bool> hasTemplate(String id) async {
    await _ensureInitialized();

    final result = await _database!.query(
      'templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // Helper para obter estatísticas
  Future<Map<String, int>> getStats() async {
    await _ensureInitialized();

    final inspections =
        await _database!.rawQuery('SELECT COUNT(*) as count FROM inspections');
    final templates =
        await _database!.rawQuery('SELECT COUNT(*) as count FROM templates');
    final mediaFiles =
        await _database!.rawQuery('SELECT COUNT(*) as count FROM media_files');
    final unsynced = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM inspections WHERE needs_sync = 1');

    return {
      'inspections': inspections.first['count'] as int,
      'templates': templates.first['count'] as int,
      'media_files': mediaFiles.first['count'] as int,
      'unsynced': unsynced.first['count'] as int,
    };
  }

  Future<List<Map<String, dynamic>>> getTemplates() async {
    await _ensureInitialized();
    final result = await _database!.query('templates');
    return result
        .map((row) => jsonDecode(row['data'] as String) as Map<String, dynamic>)
        .toList();
  }
}
