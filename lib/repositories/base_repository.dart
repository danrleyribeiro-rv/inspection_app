import 'package:uuid/uuid.dart';

// Deprecated: Este padrão de repository não é mais necessário com Hive
// Use diretamente os métodos do DatabaseHelper que já fornecem operações CRUD
@Deprecated('Use DatabaseHelper methods directly')
abstract class BaseRepository<T> {
  String get entityType;

  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T entity);
  String getId(T entity);

  // Métodos básicos que devem ser implementados nas subclasses
  // usando diretamente o DatabaseHelper

  Future<String> insert(T entity) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> update(T entity) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> markNeedsSync(String id) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> delete(String id) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> hardDelete(String id) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<T?> findById(String id) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<List<T>> findAll() async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<List<T>> findWhere(String whereClause, List<dynamic> whereArgs) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<int> count() async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<List<T>> findPendingSync() async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  // REMOVED: markSynced - Always sync all data on demand

  // REMOVED: markAllSynced - Always sync all data on demand

  Future<void> insertOrUpdate(T entity) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> insertOrUpdateFromCloud(T entity) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> batchInsert(List<T> entities) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> batchUpdate(List<T> entities) async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }

  Future<void> clearAll() async {
    throw UnimplementedError('Use DatabaseHelper methods directly');
  }
}