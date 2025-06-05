// lib/services/utils/progress_calculation_service.dart
import 'package:flutter/material.dart';

class ProgressCalculationService {
  
  /// Calcula o progresso geral da inspeção
  static double calculateOverallProgress(Map<String, dynamic>? inspection) {
    if (inspection == null || inspection['topics'] == null) return 0.0;
    
    final topics = List<Map<String, dynamic>>.from(inspection['topics'] ?? []);
    if (topics.isEmpty) return 0.0;

    int totalFields = 0;
    int filledFields = 0;

    for (final topic in topics) {
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      for (final item in items) {
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        for (final detail in details) {
          totalFields++;
          final value = detail['value'];
          if (value != null && value.toString().isNotEmpty) {
            filledFields++;
          }
        }
      }
    }

    return totalFields > 0 ? (filledFields / totalFields) * 100 : 0.0;
  }

  /// Calcula o progresso de um tópico específico
  static double calculateTopicProgress(Map<String, dynamic>? inspection, int topicIndex) {
    if (inspection == null || inspection['topics'] == null) return 0.0;
    
    final topics = List<Map<String, dynamic>>.from(inspection['topics'] ?? []);
    if (topicIndex >= topics.length) return 0.0;

    final topic = topics[topicIndex];
    final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);

    int totalFields = 0;
    int filledFields = 0;

    for (final item in items) {
      final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
      for (final detail in details) {
        totalFields++;
        final value = detail['value'];
        if (value != null && value.toString().isNotEmpty) {
          filledFields++;
        }
      }
    }

    return totalFields > 0 ? (filledFields / totalFields) * 100 : 0.0;
  }

  /// Calcula o progresso de um item específico
  static double calculateItemProgress(Map<String, dynamic>? inspection, int topicIndex, int itemIndex) {
    if (inspection == null || inspection['topics'] == null) return 0.0;
    
    final topics = List<Map<String, dynamic>>.from(inspection['topics'] ?? []);
    if (topicIndex >= topics.length) return 0.0;

    final topic = topics[topicIndex];
    final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
    if (itemIndex >= items.length) return 0.0;

    final item = items[itemIndex];
    final details = List<Map<String, dynamic>>.from(item['details'] ?? []);

    int totalFields = details.length;
    int filledFields = 0;

    for (final detail in details) {
      final value = detail['value'];
      if (value != null && value.toString().isNotEmpty) {
        filledFields++;
      }
    }

    return totalFields > 0 ? (filledFields / totalFields) * 100 : 0.0;
  }

  /// Retorna estatísticas detalhadas da inspeção
  static Map<String, int> getInspectionStats(Map<String, dynamic>? inspection) {
    if (inspection == null || inspection['topics'] == null) {
      return {
        'totalTopics': 0,
        'totalItems': 0,
        'totalDetails': 0,
        'filledDetails': 0,
        'totalMedia': 0,
        'totalNonConformities': 0,
      };
    }

    final topics = List<Map<String, dynamic>>.from(inspection['topics'] ?? []);
    
    int totalTopics = topics.length;
    int totalItems = 0;
    int totalDetails = 0;
    int filledDetails = 0;
    int totalMedia = 0;
    int totalNonConformities = 0;

    for (final topic in topics) {
      final items = List<Map<String, dynamic>>.from(topic['items'] ?? []);
      totalItems += items.length;
      
      for (final item in items) {
        final details = List<Map<String, dynamic>>.from(item['details'] ?? []);
        totalDetails += details.length;
        
        for (final detail in details) {
          final value = detail['value'];
          if (value != null && value.toString().isNotEmpty) {
            filledDetails++;
          }
          
          // Count media
          final media = List<Map<String, dynamic>>.from(detail['media'] ?? []);
          totalMedia += media.length;
          
          // Count non-conformities
          final nonConformities = List<Map<String, dynamic>>.from(detail['non_conformities'] ?? []);
          totalNonConformities += nonConformities.length;
          
          // Count media in non-conformities
          for (final nc in nonConformities) {
            final ncMedia = List<Map<String, dynamic>>.from(nc['media'] ?? []);
            totalMedia += ncMedia.length;
          }
        }
      }
    }

    return {
      'totalTopics': totalTopics,
      'totalItems': totalItems,
      'totalDetails': totalDetails,
      'filledDetails': filledDetails,
      'totalMedia': totalMedia,
      'totalNonConformities': totalNonConformities,
    };
  }

  /// Calcula a porcentagem de completude formatada como string
  static String getFormattedProgress(double progress) {
    return '${progress.toStringAsFixed(1)}%';
  }

  /// Retorna a cor baseada no progresso
  static Color getProgressColor(double progress) {
    if (progress < 30) {
      return Colors.red;
    } else if (progress < 70) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }

  /// Retorna o label de progresso baseado na porcentagem
  static String getProgressLabel(double progress) {
    if (progress < 5) return 'Início';
    if (progress < 20) return 'Fase inicial';
    if (progress < 40) return 'Em andamento';
    if (progress < 60) return 'Avançando';
    if (progress < 80) return 'Fase final';
    if (progress < 95) return 'Quase concluído';
    return 'Concluído';
  }
}