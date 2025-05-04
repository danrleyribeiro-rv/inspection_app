// lib/services/gemini_service.dart
import 'dart:convert';
import 'dart:async'; // For Completer/Future
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  static Completer<void>? _initializerCompleter; // To ensure initialization happens once

  static Future<void> initialize() async {
    // Prevent multiple initializations
    if (_initializerCompleter != null) {
      return _initializerCompleter!.future;
    }
    _initializerCompleter = Completer<void>();
    try {
      await dotenv.load(fileName: ".env");
      _initializerCompleter!.complete();
    } catch (e) {
      print('Error loading .env file: $e');
      _initializerCompleter!.completeError(e);
    }
    return _initializerCompleter!.future;
  }

  late final String _apiKey;
  // Consider allowing model selection or using a more capable model if needed
  // e.g., gemini-1.5-flash-latest or gemini-1.5-pro-latest
  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  factory GeminiService() {
    // Ensure initialization is complete before returning the instance
    if (_initializerCompleter == null || !_initializerCompleter!.isCompleted) {
      // This shouldn't happen if initialize() is called correctly at app startup,
      // but it's a safeguard.
      print('AVISO: GeminiService acessado antes da inicialização completa.');
      // Consider throwing an error or returning a non-functional instance
      // depending on your app's requirements. For now, we proceed but log.
    }
    return _instance;
  }

  GeminiService._internal() {
    // Ensure dotenv is loaded before accessing env vars
    _apiKey = dotenv.maybeGet('GOOGLE_GEMINI_API_KEY', fallback: '')!;
    if (_apiKey.isEmpty) {
      print('AVISO CRÍTICO: GOOGLE_GEMINI_API_KEY não encontrada ou vazia em .env. As sugestões de IA não funcionarão.');
      // Depending on requirements, you might want to throw an exception here
      // throw Exception('GOOGLE_GEMINI_API_KEY is missing in .env');
    }
  }

  /// Sugere rooms completas com estrutura JSON.
  ///
  /// Retorna uma lista de mapas representando as salas sugeridas.
  /// Em caso de erro na API ou parsing, retorna uma lista vazia e loga o erro.
  Future<List<Map<String, dynamic>>> suggestCompleteRooms(String inspectionType, List<String> existingRooms) async {
    if (_apiKey.isEmpty) {
      print('Erro: API Key do Gemini não configurada. Impossível gerar sugestões.');
      return []; // Return empty list if API key is missing
    }

    // Refined Prompt - More explicit instructions for JSON output
    final prompt = '''
    Contexto: Gerar sugestões de estrutura para uma aplicação de vistoria de imóveis.
    Tipo de Vistoria: "$inspectionType"
    Salas já existentes (evitar duplicatas óbvias): ${existingRooms.isEmpty ? "Nenhuma" : existingRooms.join(", ")}

    Tarefa: Sugira 5 novas salas relevantes para este tipo de vistoria que ainda não existem. Para cada sala sugerida, inclua:
    1.  **Nome da sala** (ex: "Cozinha", "Banheiro Social", "Área de Serviço").
    2.  **Lista de 5 a 8 itens** típicos encontrados nessa sala (ex: "Pia", "Fogão", "Janela").
    3.  Para cada item, inclua **3 a 5 detalhes** relevantes para vistoria, com tipos de dados apropriados:
        *   `detail_name`: Nome descritivo do detalhe (ex: "Material da Bancada", "Estado de Conservação", "Número de Bocas", "Possui Vazamentos?").
        *   `type`: Tipo de dado, **estritamente** um dos seguintes: "select", "text", "number".
        *   `options`: Uma lista de strings com 3 a 5 opções pré-definidas. **Obrigatório e somente** se o `type` for "select". Não inclua este campo para "text" ou "number".

    Formato de Saída: Retorne **SOMENTE** um array JSON válido, começando com `[` e terminando com `]`. Não inclua nenhuma explicação, texto introdutório, comentários ou formatação de markdown (como ```json ... ```). O JSON deve seguir **exatamente** a estrutura abaixo:

    [
      {
        "room_name": "string", // Nome da Sala 1
        "items": [
          {
            "item_name": "string", // Nome do Item 1.1
            "details": [
              {
                "detail_name": "string", // Nome do Detalhe 1.1.1
                "type": "select|text|number", // Tipo do Detalhe
                "options": ["string", "string", ...] // APENAS se type="select"
              },
              // ... mais detalhes para o Item 1.1
            ]
          },
          // ... mais itens para a Sala 1
        ]
      },
      // ... mais objetos de sala (total de 5)
    ]
    ''';

    final responseText = await _sendPrompt(prompt);

    if (responseText.isEmpty || responseText.startsWith('Erro:')) {
      print('Falha ao obter resposta válida do Gemini.');
      return []; // Indicate failure with an empty list
    }

    try {
      // Attempt to directly decode the response as JSON
      // First, clean potential markdown fences if the model ignores the instruction
      String cleanedJson = responseText.trim();
      if (cleanedJson.startsWith('```json')) {
         cleanedJson = cleanedJson.substring(7); // Remove ```json
      }
       if (cleanedJson.endsWith('```')) {
         cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3); // Remove ```
      }
       cleanedJson = cleanedJson.trim(); // Trim again after removing fences


      // Find the start and end of the JSON array robustly
      final jsonStartIndex = cleanedJson.indexOf('[');
      final jsonEndIndex = cleanedJson.lastIndexOf(']');

      if (jsonStartIndex != -1 && jsonEndIndex != -1 && jsonEndIndex > jsonStartIndex) {
         final jsonString = cleanedJson.substring(jsonStartIndex, jsonEndIndex + 1);
         final decoded = json.decode(jsonString);

         if (decoded is List) {
           // Basic validation: Check if items are maps with expected keys
           return List<Map<String, dynamic>>.from(decoded.where((item) =>
                item is Map<String, dynamic> && item.containsKey('room_name') && item.containsKey('items')));
         } else {
           print('Erro de Parsing: Resposta decodificada não é uma lista JSON: $decoded');
           return [];
         }
      } else {
          print('Erro de Parsing: Não foi possível encontrar um array JSON válido na resposta: ${cleanedJson.substring(0, 100)}...'); // Log beginning of response
          return [];
      }


    } catch (e, stackTrace) {
      print('Erro Crítico ao processar sugestões de salas completas: $e');
      print('Resposta recebida (início): ${responseText.substring(0, responseText.length > 200 ? 200 : responseText.length)}...'); // Log beginning of raw response
      print('Stack Trace: $stackTrace');
      return []; // Indicate failure with an empty list
    }
  }

  // Método base para enviar prompts para a API Gemini
  Future<String> _sendPrompt(String prompt) async {
    if (_apiKey.isEmpty) {
       print('Erro Interno: _sendPrompt chamado sem API Key.');
       return 'Erro: API Key não configurada';
    }
    final url = Uri.parse('$_baseUrl?key=$_apiKey');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          // Generation Config - Consider adjusting based on model and desired output
          'generationConfig': {
            'temperature': 0.4, // Slightly higher for more variety but still grounded
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 4096, // Increased for potentially larger JSON
            // 'responseMimeType': 'application/json', // NOTE: Check if v1beta supports this directly. If not, rely on prompt.
                                                     // As of now, standard Gemini API often doesn't enforce this like Vertex AI.
          },
          // Safety Settings - Adjust if needed, but default is usually reasonable
           "safetySettings": [
            {
                "category": "HARM_CATEGORY_HARASSMENT",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
                "category": "HARM_CATEGORY_HATE_SPEECH",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
                "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            },
            {
                "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
                "threshold": "BLOCK_MEDIUM_AND_ABOVE"
            }
          ]
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes)); // Decode using utf8

        // Check for safety ratings / blocked prompts first
        if (data['promptFeedback']?['blockReason'] != null) {
           final reason = data['promptFeedback']['blockReason'];
           print('Erro na API Gemini: Prompt bloqueado. Razão: $reason');
           return 'Erro: Prompt bloqueado ($reason)';
        }

        // Check structure carefully before accessing parts
        if (data['candidates'] != null &&
            data['candidates'] is List &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'] is List &&
            data['candidates'][0]['content']['parts'].isNotEmpty &&
            data['candidates'][0]['content']['parts'][0]['text'] != null)
        {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          // Log the structure if it's unexpected
          print('Erro na API Gemini: Resposta com estrutura inesperada.');
          print('Corpo da Resposta: ${utf8.decode(response.bodyBytes)}');
          return 'Erro: Resposta da API inválida';
        }
      } else {
        // Log detailed error from API response body
        String errorBody = utf8.decode(response.bodyBytes);
        print('Erro na API Gemini: Status ${response.statusCode}');
        print('Corpo do Erro: $errorBody');
        return 'Erro: Falha na API (${response.statusCode})';
      }
    } on TimeoutException catch (e) {
       print('Exceção ao chamar API Gemini: Timeout - $e');
       return 'Erro: Tempo limite de conexão excedido';
    } on http.ClientException catch (e) {
       print('Exceção ao chamar API Gemini: Erro de Cliente HTTP - $e');
       return 'Erro: Falha na conexão com a API';
    } catch (e, stackTrace) {
      print('Exceção desconhecida ao chamar API Gemini: $e');
      print('Stack Trace: $stackTrace');
      return 'Erro: Falha inesperada na comunicação';
    }
  }
}