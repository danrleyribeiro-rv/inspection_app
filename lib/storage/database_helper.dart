import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static const String _databaseName = 'inspection_offline.db';
  static const int _databaseVersion = 14;

  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    // Tabela de inspeções
    await db.execute('''
      CREATE TABLE inspections (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        cod TEXT,
        street TEXT,
        neighborhood TEXT,
        city TEXT,
        state TEXT,
        zip_code TEXT,
        address_string TEXT,
        address TEXT,
        status TEXT NOT NULL,
        observation TEXT,
        scheduled_date TEXT,
        finished_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        project_id TEXT,
        inspector_id TEXT,
        is_templated INTEGER NOT NULL DEFAULT 0,
        template_id TEXT,
        is_synced INTEGER NOT NULL DEFAULT 1,
        last_sync_at TEXT,
        has_local_changes INTEGER NOT NULL DEFAULT 0,
        topics TEXT,
        needs_sync INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        sync_history TEXT,
        area TEXT,
        deleted_at TEXT
      )
    ''');

    // Tabela de tópicos
    await db.execute('''
      CREATE TABLE topics (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        topic_name TEXT NOT NULL,
        topic_label TEXT,
        description TEXT,
        direct_details INTEGER NOT NULL DEFAULT 0,
        observation TEXT,
        is_damaged INTEGER NOT NULL DEFAULT 0,
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        needs_sync INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de itens
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        topic_id TEXT,
        item_id TEXT,
        position INTEGER NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0,
        item_name TEXT NOT NULL,
        item_label TEXT,
        description TEXT,
        evaluable INTEGER NOT NULL DEFAULT 0,
        evaluation_options TEXT,
        evaluation_value TEXT,
        evaluation TEXT,
        observation TEXT,
        is_damaged INTEGER NOT NULL DEFAULT 0,
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        needs_sync INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE,
        FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de detalhes
    await db.execute('''
      CREATE TABLE details (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        topic_id TEXT,
        item_id TEXT,
        detail_id TEXT,
        position INTEGER,
        order_index INTEGER NOT NULL DEFAULT 0,
        detail_name TEXT NOT NULL,
        detail_value TEXT,
        observation TEXT,
        is_damaged INTEGER NOT NULL DEFAULT 0,
        tags TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        type TEXT,
        options TEXT,
        allow_custom_option INTEGER NOT NULL DEFAULT 0,
        custom_option_value TEXT,
        status TEXT,
        is_required INTEGER NOT NULL DEFAULT 0,
        needs_sync INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE,
        FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de não conformidades
    await db.execute('''
      CREATE TABLE non_conformities (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        topic_id TEXT,
        item_id TEXT,
        detail_id TEXT,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL,
        corrective_action TEXT,
        deadline TEXT,
        is_resolved INTEGER NOT NULL DEFAULT 0,
        resolved_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        needs_sync INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE,
        FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE,
        FOREIGN KEY (detail_id) REFERENCES details (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de mídias offline
    await db.execute('''
      CREATE TABLE offline_media (
        id TEXT PRIMARY KEY,
        inspection_id TEXT NOT NULL,
        topic_id TEXT,
        item_id TEXT,
        detail_id TEXT,
        non_conformity_id TEXT,
        type TEXT NOT NULL,
        local_path TEXT NOT NULL,
        cloud_url TEXT,
        filename TEXT NOT NULL,
        file_size INTEGER,
        mime_type TEXT,
        thumbnail_path TEXT,
        duration INTEGER,
        width INTEGER,
        height INTEGER,
        is_processed INTEGER NOT NULL DEFAULT 0,
        is_uploaded INTEGER NOT NULL DEFAULT 0,
        upload_progress REAL DEFAULT 0.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        needs_sync INTEGER NOT NULL DEFAULT 0,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        source TEXT,
        is_resolution_media INTEGER NOT NULL DEFAULT 0,
        metadata TEXT,
        captured_at TEXT,
        latitude REAL,
        longitude REAL,
        order_index INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE,
        FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES items (id) ON DELETE CASCADE,
        FOREIGN KEY (detail_id) REFERENCES details (id) ON DELETE CASCADE,
        FOREIGN KEY (non_conformity_id) REFERENCES non_conformities (id) ON DELETE CASCADE
      )
    ''');

    // Tabela de templates
    await db.execute('''
      CREATE TABLE templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        version TEXT NOT NULL,
        description TEXT,
        category TEXT,
        structure TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        needs_sync INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabela de sincronização
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        action TEXT NOT NULL,
        data TEXT,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TEXT,
        error_message TEXT,
        is_processed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tabela de histórico de inspeções
    await db.execute('''\n      CREATE TABLE inspection_history (\n        id TEXT PRIMARY KEY,\n        inspection_id TEXT NOT NULL,\n        date TEXT NOT NULL,\n        status TEXT NOT NULL,\n        inspector_id TEXT NOT NULL,\n        description TEXT,\n        metadata TEXT,\n        created_at TEXT NOT NULL,\n        needs_sync INTEGER NOT NULL DEFAULT 1,\n        FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE\n      )\n    ''');

    // Índices para performance
    await db.execute('CREATE INDEX idx_inspections_status ON inspections(status)');
    await db.execute('CREATE INDEX idx_inspections_needs_sync ON inspections(needs_sync)');
    await db.execute('CREATE INDEX idx_topics_inspection_id ON topics(inspection_id)');
    await db.execute('CREATE INDEX idx_items_topic_id ON items(topic_id)');
    await db.execute('CREATE INDEX idx_details_item_id ON details(item_id)');
    await db.execute('CREATE INDEX idx_media_inspection_id ON offline_media(inspection_id)');
    await db.execute('CREATE INDEX idx_media_needs_sync ON offline_media(needs_sync)');
    await db.execute('CREATE INDEX idx_sync_queue_processed ON sync_queue(is_processed)');
    await db.execute('CREATE INDEX idx_inspection_history_inspection_id ON inspection_history(inspection_id)');
    await db.execute('CREATE INDEX idx_inspection_history_date ON inspection_history(date)');
  }

  static Future<bool> _columnExists(Database db, String tableName, String columnName) async {
    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    return result.any((column) => column['name'] == columnName);
  }

  static Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName]
    );
    return result.isNotEmpty;
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // Migração para versão 3: Recriar todas as tabelas com nova estrutura
      
      // Apagar tabelas antigas
      await db.execute('DROP TABLE IF EXISTS sync_queue');
      await db.execute('DROP TABLE IF EXISTS offline_media');
      await db.execute('DROP TABLE IF EXISTS non_conformities');
      await db.execute('DROP TABLE IF EXISTS details');
      await db.execute('DROP TABLE IF EXISTS items');
      await db.execute('DROP TABLE IF EXISTS topics');
      await db.execute('DROP TABLE IF EXISTS inspections');
      await db.execute('DROP TABLE IF EXISTS templates');
      
      // Recriar todas as tabelas com estrutura correta
      await _createTables(db, newVersion);
    }
    
    if (oldVersion < 4) {
      // Migração para versão 4: Adicionar order_index à tabela topics
      if (!await _columnExists(db, 'topics', 'order_index')) {
        await db.execute('ALTER TABLE topics ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0');
        
        // Atualizar order_index com base na position existente
        await db.execute('UPDATE topics SET order_index = position');
      }
    }
    
    if (oldVersion < 5) {
      // Migração para versão 5: Adicionar order_index à tabela items
      if (!await _columnExists(db, 'items', 'order_index')) {
        await db.execute('ALTER TABLE items ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0');
        
        // Atualizar order_index com base na position existente
        await db.execute('UPDATE items SET order_index = position');
      }
    }
    
    if (oldVersion < 6) {
      // Migração para versão 6: Adicionar order_index à tabela details
      if (!await _columnExists(db, 'details', 'order_index')) {
        await db.execute('ALTER TABLE details ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0');
        
        // Atualizar order_index com base na position existente
        await db.execute('UPDATE details SET order_index = COALESCE(position, 0)');
      }
    }
    
    if (oldVersion < 7) {
      // Migração para versão 7: Adicionar corrective_action e deadline à tabela non_conformities
      if (!await _columnExists(db, 'non_conformities', 'corrective_action')) {
        await db.execute('ALTER TABLE non_conformities ADD COLUMN corrective_action TEXT');
      }
      if (!await _columnExists(db, 'non_conformities', 'deadline')) {
        await db.execute('ALTER TABLE non_conformities ADD COLUMN deadline TEXT');
      }
    }
    
    if (oldVersion < 8) {
      // Migração para versão 8: Adicionar is_resolved e resolved_at à tabela non_conformities
      if (!await _columnExists(db, 'non_conformities', 'is_resolved')) {
        await db.execute('ALTER TABLE non_conformities ADD COLUMN is_resolved INTEGER NOT NULL DEFAULT 0');
      }
      if (!await _columnExists(db, 'non_conformities', 'resolved_at')) {
        await db.execute('ALTER TABLE non_conformities ADD COLUMN resolved_at TEXT');
      }
    }
    
    if (oldVersion < 9) {
      // Migração para versão 9: Adicionar is_resolution_media à tabela offline_media
      if (!await _columnExists(db, 'offline_media', 'is_resolution_media')) {
        await db.execute('ALTER TABLE offline_media ADD COLUMN is_resolution_media INTEGER NOT NULL DEFAULT 0');
      }
    }
    
    if (oldVersion < 10) {
      // Migração para versão 10: Adicionar tabela inspection_history
      if (!await _tableExists(db, 'inspection_history')) {
        await db.execute('''\n        CREATE TABLE inspection_history (\n          id TEXT PRIMARY KEY,\n          inspection_id TEXT NOT NULL,\n          date TEXT NOT NULL,\n          status TEXT NOT NULL,\n          inspector_id TEXT NOT NULL,\n          description TEXT,\n          metadata TEXT,\n          created_at TEXT NOT NULL,\n          needs_sync INTEGER NOT NULL DEFAULT 1,\n          FOREIGN KEY (inspection_id) REFERENCES inspections (id) ON DELETE CASCADE\n        )\n      ''');
        
        // Adicionar índices para a nova tabela
        await db.execute('CREATE INDEX idx_inspection_history_inspection_id ON inspection_history(inspection_id)');
        await db.execute('CREATE INDEX idx_inspection_history_date ON inspection_history(date)');
      }
    }
    
    if (oldVersion < 11) {
      // Migração para versão 11: Adicionar captured_at, latitude e longitude à tabela offline_media
      debugPrint('DatabaseHelper: Migrating from version $oldVersion to 11');
      
      if (!await _columnExists(db, 'offline_media', 'captured_at')) {
        debugPrint('DatabaseHelper: Adding captured_at column');
        await db.execute('ALTER TABLE offline_media ADD COLUMN captured_at TEXT');
      } else {
        debugPrint('DatabaseHelper: captured_at column already exists');
      }
      
      if (!await _columnExists(db, 'offline_media', 'latitude')) {
        debugPrint('DatabaseHelper: Adding latitude column');
        await db.execute('ALTER TABLE offline_media ADD COLUMN latitude REAL');
      } else {
        debugPrint('DatabaseHelper: latitude column already exists');
      }
      
      if (!await _columnExists(db, 'offline_media', 'longitude')) {
        debugPrint('DatabaseHelper: Adding longitude column');
        await db.execute('ALTER TABLE offline_media ADD COLUMN longitude REAL');
      } else {
        debugPrint('DatabaseHelper: longitude column already exists');
      }
      
      debugPrint('DatabaseHelper: Migration to version 11 completed');
    }
    
    if (oldVersion < 12) {
      // Migração para versão 12: Adicionar novos campos para hierarquias flexíveis
      debugPrint('DatabaseHelper: Migrating from version $oldVersion to 12');
      
      // Adicionar campos aos tópicos
      if (!await _columnExists(db, 'topics', 'description')) {
        debugPrint('DatabaseHelper: Adding description column to topics');
        await db.execute('ALTER TABLE topics ADD COLUMN description TEXT');
      }
      
      if (!await _columnExists(db, 'topics', 'direct_details')) {
        debugPrint('DatabaseHelper: Adding direct_details column to topics');
        await db.execute('ALTER TABLE topics ADD COLUMN direct_details INTEGER NOT NULL DEFAULT 0');
      }
      
      // Adicionar campos aos itens
      if (!await _columnExists(db, 'items', 'description')) {
        debugPrint('DatabaseHelper: Adding description column to items');
        await db.execute('ALTER TABLE items ADD COLUMN description TEXT');
      }
      
      if (!await _columnExists(db, 'items', 'evaluable')) {
        debugPrint('DatabaseHelper: Adding evaluable column to items');
        await db.execute('ALTER TABLE items ADD COLUMN evaluable INTEGER NOT NULL DEFAULT 0');
      }
      
      if (!await _columnExists(db, 'items', 'evaluation_options')) {
        debugPrint('DatabaseHelper: Adding evaluation_options column to items');
        await db.execute('ALTER TABLE items ADD COLUMN evaluation_options TEXT');
      }
      
      if (!await _columnExists(db, 'items', 'evaluation_value')) {
        debugPrint('DatabaseHelper: Adding evaluation_value column to items');
        await db.execute('ALTER TABLE items ADD COLUMN evaluation_value TEXT');
      }
      
      // Adicionar campos aos detalhes
      if (!await _columnExists(db, 'details', 'allow_custom_option')) {
        debugPrint('DatabaseHelper: Adding allow_custom_option column to details');
        await db.execute('ALTER TABLE details ADD COLUMN allow_custom_option INTEGER NOT NULL DEFAULT 0');
      }
      
      if (!await _columnExists(db, 'details', 'custom_option_value')) {
        debugPrint('DatabaseHelper: Adding custom_option_value column to details');
        await db.execute('ALTER TABLE details ADD COLUMN custom_option_value TEXT');
      }
      
      debugPrint('DatabaseHelper: Migration to version 12 completed');
    }
    
    if (oldVersion < 13) {
      // Migração para versão 13: Adicionar campos de histórico de sincronização e ordem de mídia
      debugPrint('DatabaseHelper: Migrating from version $oldVersion to 13');
      
      // Adicionar campos à tabela inspections
      if (!await _columnExists(db, 'inspections', 'sync_history')) {
        debugPrint('DatabaseHelper: Adding sync_history column to inspections');
        await db.execute('ALTER TABLE inspections ADD COLUMN sync_history TEXT');
      }
      
      if (!await _columnExists(db, 'inspections', 'area')) {
        debugPrint('DatabaseHelper: Adding area column to inspections');
        await db.execute('ALTER TABLE inspections ADD COLUMN area TEXT');
      }
      
      // Adicionar campo order_index à tabela offline_media
      if (!await _columnExists(db, 'offline_media', 'order_index')) {
        debugPrint('DatabaseHelper: Adding order_index column to offline_media');
        await db.execute('ALTER TABLE offline_media ADD COLUMN order_index INTEGER NOT NULL DEFAULT 0');
        
        // Atualizar order_index baseado no timestamp para mídias existentes
        debugPrint('DatabaseHelper: Updating order_index for existing media');
        await db.execute('''
          UPDATE offline_media 
          SET order_index = (
            CASE 
              WHEN captured_at IS NOT NULL THEN strftime('%s', captured_at) * 1000
              ELSE strftime('%s', created_at) * 1000
            END
          )
        ''');
      }
      
      debugPrint('DatabaseHelper: Migration to version 13 completed');
    }
    
    if (oldVersion < 14) {
      // Migração para versão 14: Adicionar campo deleted_at à tabela inspections
      debugPrint('DatabaseHelper: Migrating from version $oldVersion to 14');
      
      if (!await _columnExists(db, 'inspections', 'deleted_at')) {
        debugPrint('DatabaseHelper: Adding deleted_at column to inspections');
        await db.execute('ALTER TABLE inspections ADD COLUMN deleted_at TEXT');
      }
      
      debugPrint('DatabaseHelper: Migration to version 14 completed');
    }
  }

  // Métodos utilitários
  static Future<void> closeDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  static Future<void> deleteDatabase() async {
    final String path = join(await getDatabasesPath(), _databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }

  static Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  static Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  static Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  static Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawDelete(sql, arguments);
  }

  // Métodos de transação
  static Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction(action);
  }

  // Métodos para limpar dados
  static Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('sync_queue');
      await txn.delete('offline_media');
      await txn.delete('non_conformities');
      await txn.delete('details');
      await txn.delete('items');
      await txn.delete('topics');
      await txn.delete('inspections');
      await txn.delete('templates');
    });
  }

  // Métodos para estatísticas
  static Future<Map<String, int>> getStatistics() async {
    final db = await database;
    final results = await Future.wait([
      db.rawQuery('SELECT COUNT(*) as count FROM inspections'),
      db.rawQuery('SELECT COUNT(*) as count FROM topics'),
      db.rawQuery('SELECT COUNT(*) as count FROM items'),
      db.rawQuery('SELECT COUNT(*) as count FROM details'),
      db.rawQuery('SELECT COUNT(*) as count FROM offline_media'),
      db.rawQuery('SELECT COUNT(*) as count FROM non_conformities'),
      db.rawQuery('SELECT COUNT(*) as count FROM inspections WHERE needs_sync = 1'),
      db.rawQuery('SELECT COUNT(*) as count FROM offline_media WHERE needs_sync = 1'),
    ]);

    return {
      'inspections': results[0].first['count'] as int,
      'topics': results[1].first['count'] as int,
      'items': results[2].first['count'] as int,
      'details': results[3].first['count'] as int,
      'media': results[4].first['count'] as int,
      'non_conformities': results[5].first['count'] as int,
      'inspections_pending_sync': results[6].first['count'] as int,
      'media_pending_sync': results[7].first['count'] as int,
    };
  }
}