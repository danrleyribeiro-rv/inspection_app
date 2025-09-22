import 'package:intl/intl.dart';

/// Utilitário centralizado para formatação de datas e timestamps
/// Padroniza todos os formatos de data/hora da aplicação
class DateFormatter {
  // Formatadores padrão
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _fullDateTimeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');

  /// Converte qualquer tipo de data para DateTime
  /// Suporta: Firestore Timestamps, int (milissegundos), String ISO 8601
  static DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;

    try {
      if (dateValue is Map<String, dynamic>) {
        // Handle Firestore Timestamp Map format
        if (dateValue.containsKey('seconds') &&
            dateValue.containsKey('nanoseconds')) {
          // New Firestore Timestamp format
          final seconds = dateValue['seconds'] as int;
          final nanoseconds = dateValue['nanoseconds'] as int;
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          ).toLocal();
        } else if (dateValue.containsKey('_seconds')) {
          // Legacy format support
          final seconds = dateValue['_seconds'] as int;
          final nanoseconds = dateValue['_nanoseconds'] as int? ?? 0;
          return DateTime.fromMillisecondsSinceEpoch(
            seconds * 1000 + (nanoseconds / 1000000).round(),
          ).toLocal();
        }
      } else if (dateValue is int) {
        // Handle timestamp as int (milliseconds)
        return DateTime.fromMillisecondsSinceEpoch(dateValue).toLocal();
      } else if (dateValue is String) {
        // Handle ISO 8601 String
        return DateTime.parse(dateValue).toLocal();
      } else if (dateValue is DateTime) {
        // Handle DateTime object
        return dateValue.toLocal();
      } else if (dateValue.runtimeType.toString().contains('Timestamp')) {
        // Handle actual Firestore Timestamp object
        try {
          // Use dynamic invocation for Timestamp.toDate()
          final toDateMethod = (dateValue as dynamic).toDate;
          if (toDateMethod != null) {
            return toDateMethod().toLocal();
          }
        } catch (e) {
          return null;
        }
      }
    } catch (e) {
      return null;
    }

    return null;
  }

  /// Formata apenas a data (dd/MM/yyyy)
  /// Exemplo: 19/09/2025
  static String formatDate(dynamic dateValue) {
    final date = _parseDateTime(dateValue);
    if (date == null) return 'Data não definida';
    return _dateFormat.format(date);
  }

  /// Formata data e hora (dd/MM/yyyy HH:mm)
  /// Exemplo: 19/09/2025 14:30
  static String formatDateTime(dynamic dateValue) {
    final date = _parseDateTime(dateValue);
    if (date == null) return 'Data não definida';
    return _dateTimeFormat.format(date);
  }

  /// Formata apenas a hora (HH:mm)
  /// Exemplo: 14:30
  static String formatTime(dynamic dateValue) {
    final date = _parseDateTime(dateValue);
    if (date == null) return 'Hora não definida';
    return _timeFormat.format(date);
  }

  /// Formata data e hora completa com segundos (dd/MM/yyyy HH:mm:ss)
  /// Exemplo: 19/09/2025 14:30:45
  static String formatFullDateTime(dynamic dateValue) {
    final date = _parseDateTime(dateValue);
    if (date == null) return 'Data não definida';
    return _fullDateTimeFormat.format(date);
  }

  /// Converte DateTime para String ISO 8601 para armazenamento
  /// Sempre retorna em UTC para consistência
  static String toIsoString(DateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  /// Obtém a data/hora atual em formato ISO 8601 (UTC)
  /// Para uso consistente em toda aplicação
  static String nowIsoString() {
    return DateTime.now().toUtc().toIso8601String();
  }

  /// Obtém a data/hora atual como DateTime local
  static DateTime now() {
    return DateTime.now();
  }

  /// Verifica se uma data é válida
  static bool isValidDate(dynamic dateValue) {
    return _parseDateTime(dateValue) != null;
  }

  /// Retorna a diferença entre duas datas em texto amigável
  /// Exemplo: "há 2 horas", "há 3 dias"
  static String timeAgo(dynamic dateValue) {
    final date = _parseDateTime(dateValue);
    if (date == null) return 'Data inválida';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return 'há $years ano${years > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return 'há $months mes${months > 1 ? 'es' : ''}';
    } else if (difference.inDays > 0) {
      return 'há ${difference.inDays} dia${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'há ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'há ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'agora';
    }
  }
}