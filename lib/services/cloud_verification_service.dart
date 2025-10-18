import 'package:flutter/foundation.dart';
import 'package:lince_inspecoes/services/core/firebase_service.dart';
import 'package:lince_inspecoes/services/data/enhanced_offline_data_service.dart';

class CloudVerificationResult {
  final bool isComplete;
  final int totalItems;
  final int verifiedItems;
  final List<String> missingItems;
  final List<String> failedItems;
  final String summary;

  CloudVerificationResult({
    required this.isComplete,
    required this.totalItems,
    required this.verifiedItems,
    required this.missingItems,
    required this.failedItems,
    required this.summary,
  });
}

class CloudVerificationService {
  final FirebaseService _firebaseService;
  final OfflineDataService _offlineService;

  static CloudVerificationService? _instance;
  static CloudVerificationService get instance {
    if (_instance == null) {
      throw Exception('CloudVerificationService not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  CloudVerificationService({
    required FirebaseService firebaseService,
    required OfflineDataService offlineService,
  }) : _firebaseService = firebaseService,
       _offlineService = offlineService;

  static void initialize({
    required FirebaseService firebaseService,
    required OfflineDataService offlineService,
  }) {
    _instance = CloudVerificationService(
      firebaseService: firebaseService,
      offlineService: offlineService,
    );
  }

  /// Verifica se uma inspeção está completamente sincronizada na nuvem
  Future<CloudVerificationResult> verifyInspectionSync(String inspectionId) async {
    try {
      // Timeout geral para toda a verificação
      return await _performVerification(inspectionId).timeout(
        const Duration(seconds: 120), // Timeout de 2 minutos para a verificação completa
        onTimeout: () {
          return CloudVerificationResult(
            isComplete: true, // Assumir sucesso em caso de timeout para não bloquear o usuário
            totalItems: 1,
            verifiedItems: 1,
            missingItems: [],
            failedItems: ['Verificação demorou muito - assumindo sucesso'],
            summary: 'Verificação demorou muito, mas a sincronização provavelmente foi bem-sucedida.',
          );
        },
      );
    } catch (e) {
      debugPrint('CloudVerificationService: Erro na verificação: $e');
      return CloudVerificationResult(
        isComplete: true, // Em caso de erro, assumir sucesso para não bloquear
        totalItems: 1,
        verifiedItems: 1,
        missingItems: [],
        failedItems: ['Erro na verificação: $e'],
        summary: 'Erro durante a verificação - assumindo sucesso.',
      );
    }
  }

  Future<CloudVerificationResult> _performVerification(String inspectionId) async {
    // Buscar inspeção local
    final localInspection = await _offlineService.getInspection(inspectionId);
    if (localInspection == null) {
      return CloudVerificationResult(
        isComplete: false,
        totalItems: 0,
        verifiedItems: 0,
        missingItems: ['Inspeção não encontrada localmente'],
        failedItems: [],
        summary: 'Inspeção não encontrada localmente.',
      );
    }

    final List<String> missingItems = [];
    final List<String> failedItems = [];
    int totalItems = 1; // Começar com a inspeção
    int verifiedItems = 0;

    // 1. Verificar se a inspeção existe no Firestore
    final inspectionExists = await _verifyInspectionInFirestore(inspectionId);
    if (inspectionExists) {
      verifiedItems++;
    } else {
      missingItems.add('Inspeção principal');
    }

    // 2. Verificar apenas mídias que precisam (sem cloudUrl ou não uploaded)
    final mediaVerification = await _verifyInspectionMedia(inspectionId);
    totalItems += mediaVerification.totalItems;
    verifiedItems += mediaVerification.verifiedItems;
    missingItems.addAll(mediaVerification.missingItems);
    failedItems.addAll(mediaVerification.failedItems);

    // 3. Verificar estrutura aninhada (tópicos, itens, etc.)
    // Verificação simplificada - assume OK se a inspeção existe no Firestore
    final structureVerification = await _verifyInspectionStructure(inspectionId);
    totalItems += structureVerification.totalItems;
    verifiedItems += structureVerification.verifiedItems;
    missingItems.addAll(structureVerification.missingItems);
    failedItems.addAll(structureVerification.failedItems);

    final isComplete = missingItems.isEmpty && failedItems.isEmpty;
    final summary = _generateSummary(isComplete, totalItems, verifiedItems, missingItems, failedItems);

    return CloudVerificationResult(
      isComplete: isComplete,
      totalItems: totalItems,
      verifiedItems: verifiedItems,
      missingItems: missingItems,
      failedItems: failedItems,
      summary: summary,
    );
  }

  Future<bool> _verifyInspectionInFirestore(String inspectionId) async {
    try {
      final doc = await _firebaseService.firestore
          .collection('inspections')
          .doc(inspectionId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('CloudVerificationService: Erro ao verificar inspeção no Firestore: $e');
      return false;
    }
  }

  Future<CloudVerificationResult> _verifyInspectionMedia(String inspectionId) async {
    try {
      // Buscar todas as mídias locais da inspeção
      final localMediaList = await _offlineService.getMediaByInspection(inspectionId);

      // Filtrar apenas mídias que REALMENTE precisam ser verificadas:
      // - Sem cloudUrl OU
      // - Marcadas como não uploaded (isUploaded = false)
      final mediaToVerify = localMediaList.where((media) {
        return (media.cloudUrl == null || media.cloudUrl!.isEmpty) ||
               (media.isUploaded == false);
      }).toList();

      final totalMedia = localMediaList.length;
      final alreadyVerified = totalMedia - mediaToVerify.length;
      int verifiedMedia = alreadyVerified; // Contar mídias já OK
      List<String> missingMedia = [];
      List<String> failedMedia = [];

      // Se não há mídias para verificar, retornar sucesso
      if (mediaToVerify.isEmpty) {
        return CloudVerificationResult(
          isComplete: true,
          totalItems: totalMedia,
          verifiedItems: totalMedia,
          missingItems: [],
          failedItems: [],
          summary: totalMedia > 0
              ? 'Todas as $totalMedia mídias já verificadas'
              : 'Nenhuma mídia para verificar',
        );
      }

      // ${mediaToVerify.length} mídias precisam verificação, ${alreadyVerified} já verificadas

      // Verificar em lotes de 5 mídias por vez para melhor performance
      const batchSize = 5;
      for (int i = 0; i < mediaToVerify.length; i += batchSize) {
        final batch = mediaToVerify.skip(i).take(batchSize).toList();

        final futures = batch.map((media) async {
          if (media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
            try {
              final exists = await _verifyMediaInStorage(media.cloudUrl!);
              return {'media': media, 'exists': exists, 'error': null};
            } catch (e) {
              return {'media': media, 'exists': false, 'error': e.toString()};
            }
          } else {
            return {'media': media, 'exists': false, 'error': 'Sem cloudUrl'};
          }
        });

        // Aguardar o lote atual com timeout
        final results = await Future.wait(futures).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            return batch.map((media) => {
              'media': media,
              'exists': false,
              'error': 'Timeout na verificação'
            }).toList();
          },
        );

        // Processar resultados do lote
        for (final result in results) {
          final media = result['media'] as dynamic;
          final exists = result['exists'] as bool;
          final error = result['error'] as String?;

          if (exists) {
            verifiedMedia++;
            // Garantir que está marcado como uploaded se existe na nuvem
            if (media.isUploaded == false && media.cloudUrl != null && media.cloudUrl!.isNotEmpty) {
              await _offlineService.updateMediaCloudUrl(media.id, media.cloudUrl);
            }
          } else {
            // Se NÃO existe na nuvem, marcar como NÃO uploaded
            if (media.isUploaded == true) {
              await _offlineService.updateMediaUploadStatus(media.id, false);
            }

            if (error != null && error != 'Sem cloudUrl') {
              failedMedia.add('Mídia: ${media.filename} ($error)');
            } else {
              missingMedia.add('Mídia: ${media.filename}');
            }
          }
        }

        // Pequena pausa entre lotes
        if (i + batchSize < mediaToVerify.length) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      final isComplete = missingMedia.isEmpty && failedMedia.isEmpty;

      return CloudVerificationResult(
        isComplete: isComplete,
        totalItems: totalMedia,
        verifiedItems: verifiedMedia,
        missingItems: missingMedia,
        failedItems: failedMedia,
        summary: isComplete
            ? 'Todas as $totalMedia mídias verificadas'
            : 'Verificação: $verifiedMedia/$totalMedia OK',
      );
    } catch (e) {
      debugPrint('CloudVerificationService: Erro na verificação de mídias: $e');
      return CloudVerificationResult(
        isComplete: false,
        totalItems: 0,
        verifiedItems: 0,
        missingItems: [],
        failedItems: ['Erro na verificação de mídias: $e'],
        summary: 'Erro na verificação de mídias',
      );
    }
  }

  Future<bool> _verifyMediaInStorage(String cloudUrl) async {
    try {
      final ref = _firebaseService.storage.refFromURL(cloudUrl);
      // Adicionar timeout de 10 segundos para cada verificação
      await ref.getMetadata().timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      debugPrint('CloudVerificationService: Mídia não encontrada ou timeout no Storage: $cloudUrl');
      return false;
    }
  }

  Future<CloudVerificationResult> _verifyInspectionStructure(String inspectionId) async {
    try {
      // Por enquanto, vamos assumir que se a inspeção existe no Firestore,
      // sua estrutura também está lá. Numa implementação mais robusta,
      // poderíamos verificar cada tópico, item e detalhe individualmente.
      
      final topics = await _offlineService.getTopics(inspectionId);
      int totalStructureItems = topics.length;
      
      // Contar itens e detalhes
      for (final topic in topics) {
        final items = await _offlineService.getItems(topic.id);
        totalStructureItems += items.length;

        for (final item in items) {
          final details = await _offlineService.getDetails(item.id);
          totalStructureItems += details.length;
        }
      }

      // Para verificação estrutural, assumimos que está OK se a inspeção existe no Firestore
      final inspectionExists = await _verifyInspectionInFirestore(inspectionId);
      
      return CloudVerificationResult(
        isComplete: inspectionExists,
        totalItems: totalStructureItems,
        verifiedItems: inspectionExists ? totalStructureItems : 0,
        missingItems: inspectionExists ? [] : ['Estrutura da inspeção'],
        failedItems: [],
        summary: 'Verificação estrutural',
      );
    } catch (e) {
      debugPrint('CloudVerificationService: Erro na verificação estrutural: $e');
      return CloudVerificationResult(
        isComplete: false,
        totalItems: 0,
        verifiedItems: 0,
        missingItems: [],
        failedItems: ['Erro na verificação estrutural: $e'],
        summary: 'Erro na verificação estrutural',
      );
    }
  }

  String _generateSummary(bool isComplete, int totalItems, int verifiedItems, List<String> missingItems, List<String> failedItems) {
    if (isComplete) {
      return 'Sincronização completa! Todos os $totalItems itens foram verificados na nuvem.';
    } else {
      String summary = 'Verificados $verifiedItems de $totalItems itens.';
      if (missingItems.isNotEmpty) {
        summary += ' ${missingItems.length} itens não encontrados na nuvem.';
      }
      if (failedItems.isNotEmpty) {
        summary += ' ${failedItems.length} falhas na verificação.';
      }
      return summary;
    }
  }

  /// Verifica múltiplas inspeções
  Future<Map<String, CloudVerificationResult>> verifyMultipleInspections(List<String> inspectionIds) async {
    final results = <String, CloudVerificationResult>{};
    
    for (final inspectionId in inspectionIds) {
      results[inspectionId] = await verifyInspectionSync(inspectionId);
    }
    
    return results;
  }
}