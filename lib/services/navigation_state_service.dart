// lib/services/navigation_state_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class NavigationStateService {
  static const String _keyPrefix = 'inspection_nav_';
  
  /// Salva o estado de navegação de uma inspeção
  static Future<void> saveNavigationState({
    required String inspectionId,
    required int currentTopicIndex,
    required int currentItemIndex,
    required bool isTopicExpanded,
    required bool isItemExpanded,
    required bool isDetailsExpanded,
    String? expandedDetailId, // ID do detalhe que deve ficar expandido
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$inspectionId';
    
    final state = {
      'currentTopicIndex': currentTopicIndex,
      'currentItemIndex': currentItemIndex,
      'isTopicExpanded': isTopicExpanded,
      'isItemExpanded': isItemExpanded,
      'isDetailsExpanded': isDetailsExpanded,
      'expandedDetailId': expandedDetailId ?? '',
      'lastSaved': DateTime.now().millisecondsSinceEpoch,
    };
    
    // Converte para string formato "index1,index2,expanded1,expanded2,expanded3,detailId,timestamp"
    final stateString = '${state['currentTopicIndex']},${state['currentItemIndex']},'
        '${state['isTopicExpanded']},${state['isItemExpanded']},${state['isDetailsExpanded']},'
        '${state['expandedDetailId']},${state['lastSaved']}';
    
    await prefs.setString(key, stateString);
  }
  
  /// Carrega o estado de navegação de uma inspeção
  static Future<NavigationState?> loadNavigationState(String inspectionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$inspectionId';
    final stateString = prefs.getString(key);
    
    if (stateString == null) return null;
    
    try {
      final parts = stateString.split(',');
      if (parts.length != 7) return null; // Agora esperamos 7 partes
      
      final lastSaved = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[6]));
      
      // Se o estado foi salvo há mais de 24 horas, ignora
      if (DateTime.now().difference(lastSaved).inHours > 24) {
        await clearNavigationState(inspectionId);
        return null;
      }
      
      return NavigationState(
        currentTopicIndex: int.parse(parts[0]),
        currentItemIndex: int.parse(parts[1]),
        isTopicExpanded: parts[2] == 'true',
        isItemExpanded: parts[3] == 'true',
        isDetailsExpanded: parts[4] == 'true',
        expandedDetailId: parts[5].isEmpty ? null : parts[5],
        lastSaved: lastSaved,
      );
    } catch (e) {
      // Se houver erro no parsing, limpa o estado corrompido
      await clearNavigationState(inspectionId);
      return null;
    }
  }
  
  /// Salva especificamente que um detalhe deve ficar expandido (usado após captura de mídia)
  static Future<void> saveExpandedDetailState({
    required String inspectionId,
    required String detailId,
    required int topicIndex,
    required int itemIndex,
  }) async {
    await saveNavigationState(
      inspectionId: inspectionId,
      currentTopicIndex: topicIndex,
      currentItemIndex: itemIndex,
      isTopicExpanded: false,
      isItemExpanded: false,
      isDetailsExpanded: true, // Força detalhes expandidos
      expandedDetailId: detailId, // Salva qual detalhe específico
    );
  }

  /// Remove o estado de navegação de uma inspeção
  static Future<void> clearNavigationState(String inspectionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_keyPrefix$inspectionId';
    await prefs.remove(key);
  }
  
  /// Limpa todos os estados de navegação antigos (mais de 7 dias)
  static Future<void> cleanupOldStates() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_keyPrefix)).toList();
    
    for (final key in keys) {
      final stateString = prefs.getString(key);
      if (stateString != null) {
        try {
          final parts = stateString.split(',');
          if (parts.length == 7) { // Atualizado para 7 partes
            final lastSaved = DateTime.fromMillisecondsSinceEpoch(int.parse(parts[6]));
            if (DateTime.now().difference(lastSaved).inDays > 7) {
              await prefs.remove(key);
            }
          } else if (parts.length == 6) {
            // Remove formato antigo
            await prefs.remove(key);
          }
        } catch (e) {
          // Remove estados corrompidos
          await prefs.remove(key);
        }
      }
    }
  }
}

class NavigationState {
  final int currentTopicIndex;
  final int currentItemIndex;
  final bool isTopicExpanded;
  final bool isItemExpanded;
  final bool isDetailsExpanded;
  final String? expandedDetailId; // ID do detalhe específico que deve ficar expandido
  final DateTime lastSaved;
  
  const NavigationState({
    required this.currentTopicIndex,
    required this.currentItemIndex,
    required this.isTopicExpanded,
    required this.isItemExpanded,
    required this.isDetailsExpanded,
    this.expandedDetailId,
    required this.lastSaved,
  });
  
  @override
  String toString() {
    return 'NavigationState(topic: $currentTopicIndex, item: $currentItemIndex, '
        'topicExp: $isTopicExpanded, itemExp: $isItemExpanded, detailsExp: $isDetailsExpanded, '
        'expandedDetail: $expandedDetailId)';
  }
}