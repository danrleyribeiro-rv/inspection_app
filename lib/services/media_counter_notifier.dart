import 'package:flutter/foundation.dart';

/// Notificador global para mudanças nos contadores de mídia
/// Permite atualização instantânea dos contadores em toda a aplicação
class MediaCounterNotifier extends ChangeNotifier {
  static MediaCounterNotifier? _instance;
  static MediaCounterNotifier get instance => _instance ??= MediaCounterNotifier._();
  
  MediaCounterNotifier._();
  
  // Mapa de contadores por contexto (topic_id, item_id, detail_id)
  final Map<String, int> _counters = {};
  
  /// Notifica que uma mídia foi adicionada em um contexto específico
  void notifyMediaAdded({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
  }) {
    debugPrint('MediaCounterNotifier: Media added to context: topic=$topicId, item=$itemId, detail=$detailId');
    
    // Invalidar contadores relevantes apenas
    if (topicId != null) {
      final topicKey = '${topicId}_topic_only';
      _counters.remove(topicKey);
      debugPrint('MediaCounterNotifier: Invalidated topic counter: $topicKey');
    }
    
    if (itemId != null) {
      final itemKey = '${itemId}_item_only';
      _counters.remove(itemKey);
      debugPrint('MediaCounterNotifier: Invalidated item counter: $itemKey');
    }
    
    if (detailId != null) {
      final detailKey = '${detailId}_detail';
      _counters.remove(detailKey);
      debugPrint('MediaCounterNotifier: Invalidated detail counter: $detailKey');
    }
    
    // Single targeted notification 
    notifyListeners();
    debugPrint('MediaCounterNotifier: Single notification sent for media addition');
  }
  
  /// Notifica que uma mídia foi removida
  void notifyMediaRemoved({
    required String inspectionId,
    String? topicId,
    String? itemId,
    String? detailId,
  }) {
    debugPrint('MediaCounterNotifier: Media removed from context: topic=$topicId, item=$itemId, detail=$detailId');
    
    // Invalidar contadores relevantes apenas
    if (topicId != null) {
      final topicKey = '${topicId}_topic_only';
      _counters.remove(topicKey);
    }
    
    if (itemId != null) {
      final itemKey = '${itemId}_item_only';
      _counters.remove(itemKey);
    }
    
    if (detailId != null) {
      final detailKey = '${detailId}_detail';
      _counters.remove(detailKey);
    }
    
    // Single targeted notification
    notifyListeners();
    debugPrint('MediaCounterNotifier: Single notification sent for media removal');
  }
  
  /// Invalida todos os contadores
  void invalidateAll() {
    debugPrint('MediaCounterNotifier: Invalidating all counters');
    _counters.clear();
    notifyListeners();
  }
  
  /// Invalida contadores para uma inspeção específica
  void invalidateForInspection(String inspectionId) {
    debugPrint('MediaCounterNotifier: Invalidating counters for inspection $inspectionId');
    // Remover todos os contadores que possam estar relacionados à inspeção
    _counters.clear();
    notifyListeners();
  }
  
  /// Armazena um contador calculado
  void setCounter(String key, int count) {
    _counters[key] = count;
  }
  
  /// Recupera um contador armazenado
  int? getCounter(String key) {
    return _counters[key];
  }
  
  /// Limpa contador específico
  void clearCounter(String key) {
    _counters.remove(key);
  }
}