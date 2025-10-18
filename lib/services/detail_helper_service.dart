import 'package:lince_inspecoes/models/detail.dart';

/// Serviço helper para operações comuns com Details
class DetailHelperService {
  /// Parse multi-select values do formato "a | b | c"
  static Set<String> parseMultiSelectValue(String? value) {
    if (value == null || value.isEmpty) {
      return {};
    }

    return value
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  /// Formata multi-select values para o formato "a | b | c"
  static String formatMultiSelectValue(Set<String> values) {
    if (values.isEmpty) return '';
    return values.join(' | ');
  }

  /// Parse measure values - suporta JSON e CSV
  static Map<String, String> parseMeasureValue(String? value) {
    final result = {'altura': '', 'largura': '', 'profundidade': ''};

    if (value == null || value.isEmpty) {
      return result;
    }

    if (value.startsWith('{') && value.endsWith('}')) {
      // Formato JSON: {largura: 2, altura: 1, profundidade: 5}
      try {
        final content = value.substring(1, value.length - 1);
        final pairs = content.split(',');

        for (final pair in pairs) {
          final keyValue = pair.split(':');
          if (keyValue.length == 2) {
            final key = keyValue[0].trim();
            final val = keyValue[1].trim();

            if (result.containsKey(key)) {
              result[key] = val;
            }
          }
        }
      } catch (e) {
        // Se falhar, retorna valores vazios
      }
    } else {
      // Formato CSV: "2,1,5"
      final measurements = value.split(',');
      if (measurements.isNotEmpty) result['altura'] = measurements[0].trim();
      if (measurements.length > 1) result['largura'] = measurements[1].trim();
      if (measurements.length > 2) result['profundidade'] = measurements[2].trim();
    }

    return result;
  }

  /// Formata measure values para CSV
  static String formatMeasureValue(String altura, String largura, String profundidade) {
    final value = '${altura.trim()},${largura.trim()},${profundidade.trim()}';
    return value == ',,' ? '' : value;
  }

  /// Parse boolean value para estado interno
  static String parseBooleanValue(String? value, String? type) {
    if (value == null || value.isEmpty) {
      return 'não_se_aplica';
    }

    final normalizedValue = value.toLowerCase();

    switch (type ?? '') {
      case 'boolean':
        if (normalizedValue == 'true' || normalizedValue == '1' || normalizedValue == 'sim') {
          return 'sim';
        } else if (normalizedValue == 'false' || normalizedValue == '0' || normalizedValue == 'não') {
          return 'não';
        }
        return 'não_se_aplica';

      case 'boolean01':
        if (normalizedValue == 'true' || normalizedValue == '1' || normalizedValue == 'aprovado') {
          return 'Aprovado';
        } else if (normalizedValue == 'false' || normalizedValue == '0' || normalizedValue == 'reprovado') {
          return 'Reprovado';
        }
        return 'não_se_aplica';

      case 'boolean02':
        if (normalizedValue == 'true' || normalizedValue == '1' || normalizedValue == 'conforme') {
          return 'Conforme';
        } else if (normalizedValue == 'false' || normalizedValue == '0' || normalizedValue == 'não conforme') {
          return 'Não Conforme';
        }
        return 'não_se_aplica';

      default:
        return 'não_se_aplica';
    }
  }

  /// Obtém o valor formatado para salvar no banco
  static String getFormattedValue({
    required String? type,
    String? textValue,
    String? selectValue,
    Set<String>? multiSelectValues,
    String? booleanValue,
    String? altura,
    String? largura,
    String? profundidade,
  }) {
    switch (type ?? '') {
      case 'measure':
        return formatMeasureValue(altura ?? '', largura ?? '', profundidade ?? '');

      case 'boolean':
      case 'boolean01':
      case 'boolean02':
        return booleanValue ?? 'não_se_aplica';

      case 'select':
        return selectValue ?? '';

      case 'multi-select':
        return formatMultiSelectValue(multiSelectValues ?? {});

      default:
        return textValue ?? '';
    }
  }

  /// Verifica se um valor de select é válido
  static bool isValidSelectValue(String? value, List<String>? options, String? currentValue) {
    if (value == null) return true;
    if (options == null) return false;

    return options.contains(value) || value == 'Outro' || value == currentValue;
  }

  /// Cria um Detail atualizado com novo valor
  static Detail createUpdatedDetail({
    required Detail original,
    String? newValue,
    String? newObservation,
    List<String>? newOptions,
  }) {
    return Detail(
      id: original.id,
      inspectionId: original.inspectionId,
      topicId: original.topicId,
      itemId: original.itemId,
      detailId: original.detailId,
      position: original.position,
      orderIndex: original.orderIndex,
      detailName: original.detailName,
      detailValue: newValue ?? original.detailValue,
      observation: newObservation ?? original.observation,
      createdAt: original.createdAt,
      updatedAt: DateTime.now(),
      type: original.type,
      options: newOptions ?? original.options,
      status: original.status,
    );
  }
}
