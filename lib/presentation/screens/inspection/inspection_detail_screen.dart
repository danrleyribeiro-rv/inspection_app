// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/services/firebase_inspection_service.dart';
import 'package:inspection_app/presentation/screens/inspection/components/topics_list.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/components/empty_topic_state.dart';
import 'package:inspection_app/presentation/screens/inspection/components/loading_state.dart';
import 'package:inspection_app/presentation/widgets/template_selector_dialog.dart';
import 'package:inspection_app/services/import_export_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/services/inspection_checkpoint_service.dart';
import 'package:inspection_app/services/checkpoint_dialog_service.dart';
import 'package:inspection_app/presentation/screens/inspection/inspection_info_dialog.dart';
import 'package:inspection_app/services/offline_inspection_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  // Serviços
  final OfflineInspectionService _offlineService = OfflineInspectionService();
  final _connectivityService = Connectivity();
  final _importExportService = ImportExportService();
  final _firestore = FirebaseFirestore.instance;
  final _checkpointService = InspectionCheckpointService();
  late CheckpointDialogService _checkpointDialogService;

  // Estados
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _isApplyingTemplate = false;
  bool _isRestoringCheckpoint = false;
  Inspection? _inspection;
  List<Topic> _topics = [];
  int _expandedTopicIndex = -1;

  @override
  void initState() {
    super.initState();
    _offlineService.initialize();
    _listenToConnectivity();

    // Inicializar o serviço de diálogos de checkpoint
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkpointDialogService = CheckpointDialogService(
        context,
        _checkpointService,
        _loadInspection, // Callback para recarregar dados após restauração
      );
    });

    _loadInspection();
  }

  @override
  void dispose() {
    _offlineService.dispose();
    super.dispose();
  }

  // Monitora o estado de conectividade e reage às mudanças
  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.mobile);
        });

        // Se estiver online e tiver um template pendente
        if (_isOnline &&
            _inspection != null &&
            _inspection!.templateId != null &&
            _inspection!.isTemplated != true) {
          _checkAndApplyTemplate();
        }
      }
    });

    _connectivityService.checkConnectivity().then((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.mobile);
        });
      }
    });
  }

  // Exibe o diálogo para criar um novo checkpoint
  void _showCreateCheckpointDialog() {
    _checkpointDialogService.showCreateCheckpointDialog(widget.inspectionId);
  }

  // Exibe o diálogo com o histórico de checkpoints
  void _showCheckpointHistory() {
    _checkpointDialogService.showCheckpointHistory(widget.inspectionId);
  }

  // Carrega os dados da inspeção
  Future<void> _loadInspection() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final inspection =
          await _offlineService.getInspection(widget.inspectionId);

      if (!mounted) return;

      if (inspection != null) {
        setState(() {
          _inspection = inspection;
        });

        // Carrega os tópicos da inspeção
        await _loadTopics();

        // Verifica se há um template para aplicar
        if (_isOnline && inspection.templateId != null) {
          if (inspection.isTemplated != true) {
            // Se o template não foi aplicado ainda
            await _checkAndApplyTemplate();
          }
        }
      } else {
        _showErrorSnackBar('Inspeção não encontrada.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Substituir _checkAndApplyTemplate
  Future<void> _checkAndApplyTemplate() async {
    if (_inspection == null) return;

    // Só prossegue se a inspeção tiver um ID de template e não tiver sido aplicada ainda
    if (_inspection!.templateId != null) {
      final isAlreadyApplied =
          await _offlineService.isTemplateAlreadyApplied(_inspection!.id);
      if (isAlreadyApplied) {
        setState(() {
          _inspection = _inspection!.copyWith(isTemplated: true);
        });
        return;
      }
      setState(() => _isApplyingTemplate = true);

      try {
        // Mostra mensagem de carregamento
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aplicando template à inspeção...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Aplica o template
        final success = await _offlineService.applyTemplateToInspectionSafe(
            _inspection!.id, _inspection!.templateId!);

        if (success) {
          // Atualiza o status da inspeção localmente E no Firestore
          await _firestore
              .collection('inspections')
              .doc(_inspection!.id)
              .update({
            'is_templated': true,
            'status': 'in_progress',
            'updated_at': FieldValue.serverTimestamp(),
          });

          if (mounted) {
            // Atualiza o estado
            final updatedInspection = _inspection!.copyWith(
              isTemplated: true,
              status: 'in_progress',
              updatedAt: DateTime.now(),
            );

            setState(() {
              _inspection = updatedInspection;
            });
          }

          // Recarrega os dados da inspeção para obter a estrutura atualizada
          await _loadInspection();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Template aplicado com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aplicar template: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isApplyingTemplate = false);
        }
      }
    }
  }

  // Substituir _manuallyApplyTemplate
  Future<void> _manuallyApplyTemplate() async {
    if (_inspection == null || !_isOnline || _isApplyingTemplate) return;

    final isAlreadyApplied =
        await _offlineService.isTemplateAlreadyApplied(_inspection!.id);
    // Mostrar diálogo de confirmação
    final shouldApply = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aplicar Template'),
            content: Text(isAlreadyApplied
                ? 'Esta inspeção já tem um template aplicado. Deseja reaplicá-lo?'
                : 'Deseja aplicar o template a esta inspeção?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white),
                child: const Text('Aplicar Template'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldApply) {
      setState(() => _isApplyingTemplate = true);

      try {
        if (isAlreadyApplied) {
          // Forçar redefinição da flag de template no Firestore
          await _firestore
              .collection('inspections')
              .doc(_inspection!.id)
              .update({
            'is_templated': false,
            'updated_at': FieldValue.serverTimestamp(),
          });
          setState(() {
            _inspection = _inspection!.copyWith(isTemplated: false);
          });
        }
        await _checkAndApplyTemplate();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao aplicar template: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isApplyingTemplate = false);
        }
      }
    }
  }

  // Carrega os tópicos da inspeção
  Future<void> _loadTopics() async {
    if (_inspection?.id == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final topics = await _offlineService.getTopics(widget.inspectionId);

      if (!mounted) return;
      setState(() {
        _topics = topics;
      });
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar tópicos: $e');
      }
    }
  }

  // Exibe mensagem de erro como SnackBar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Adiciona um novo tópico à inspeção
  Future<void> _addTopic() async {
    try {
      final template = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => TemplateSelectorDialog(
          title: 'Adicionar Tópico',
          type: 'topic',
          parentName: 'Inspeção',
        ),
      );

      if (template == null || !mounted) return;

      final topicName = template['name'] as String;
      final topicLabel = template['value'] as String?;

      setState(() => _isLoading = true);

      try {
        final position = _topics.isNotEmpty ? _topics.last.position + 1 : 0;
        await _offlineService.addTopic(
          widget.inspectionId,
          topicName,
          label: topicLabel,
          position: position,
        );

        await _loadTopics();

        // Expande o tópico recém-adicionado
        if (_topics.isNotEmpty) {
          setState(() {
            _expandedTopicIndex = _topics.length - 1;
          });
        }

        // Atualiza o status da inspeção para in_progress se estava pendente
        if (_inspection?.status == 'pending') {
          final updatedInspection = _inspection!.copyWith(
            status: 'in_progress',
            updatedAt: DateTime.now(),
          );
          await _offlineService.saveInspection(updatedInspection);
          setState(() {
            _inspection = updatedInspection;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico adicionado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar tópico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      // Error handling
    }
  }

  // Duplica um tópico existente
  Future<void> _duplicateTopic(Topic topic) async {
    setState(() => _isLoading = true);

    try {
      await _offlineService.isTopicDuplicate(
          widget.inspectionId, topic.topicName);

      await _loadTopics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tópico "${topic.topicName}" duplicado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar tópico: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Atualiza um tópico existente
  Future<void> _updateTopic(Topic updatedTopic) async {
    try {
      await _offlineService.updateTopic(updatedTopic);

      final index = _topics.indexWhere((r) => r.id == updatedTopic.id);
      if (index >= 0 && mounted) {
        setState(() {
          _topics[index] = updatedTopic;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar tópico: $e')),
        );
      }
    }
  }

  // Remove um tópico existente
  Future<void> _deleteTopic(dynamic topicId) async {
    setState(() => _isLoading = true);

    try {
      await _offlineService.deleteTopic(widget.inspectionId, topicId);

      await _loadTopics();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico excluído com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir tópico: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Exporta a inspeção para um arquivo JSON
  Future<void> _exportInspection() async {
    final confirmed =
        await _importExportService.showExportConfirmationDialog(context);
    if (!confirmed) return;

    setState(() => _isSyncing = true);

    try {
      final filePath =
          await _importExportService.exportInspection(widget.inspectionId);

      if (mounted) {
        _importExportService.showSuccessMessage(
            context, 'Inspeção exportada com sucesso para:\n$filePath');
      }
    } catch (e) {
      if (mounted) {
        _importExportService.showErrorMessage(
            context, 'Erro ao exportar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // Importa a inspeção de um arquivo JSON
  Future<void> _importInspection() async {
    final confirmed =
        await _importExportService.showImportConfirmationDialog(context);
    if (!confirmed) return;

    setState(() => _isSyncing = true);

    try {
      final jsonData = await _importExportService.pickJsonFile();

      if (jsonData == null) {
        if (mounted) {
          setState(() => _isSyncing = false);
        }
        return;
      }

      final success = await _importExportService.importInspection(
          widget.inspectionId, jsonData);

      if (success) {
        // Recarrega os dados
        await _loadInspection();

        if (mounted) {
          _importExportService.showSuccessMessage(
              context, 'Dados da inspeção importados com sucesso');
        }
      } else {
        if (mounted) {
          _importExportService.showErrorMessage(
              context, 'Falha ao importar dados da inspeção');
        }
      }
    } catch (e) {
      if (mounted) {
        _importExportService.showErrorMessage(
            context, 'Erro ao importar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // Navega para a tela de galeria de mídia
  void _navigateToMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Slate background
      appBar: AppBar(
        title: Text(_inspection?.title ?? 'Inspeção'),
        actions: [
          // Botão de checkpoint
          IconButton(
            icon: const Icon(Icons.save_outlined, size: 22),
            tooltip: 'Criar Checkpoint',
            onPressed: _showCreateCheckpointDialog,
            padding: const EdgeInsets.all(8),
            visualDensity: VisualDensity.compact,
          ),

          // Botão de aplicar template
          if (_isOnline &&
              _inspection != null &&
              _inspection!.templateId != null)
            IconButton(
              icon: const Icon(Icons.architecture, size: 22),
              tooltip: _inspection!.isTemplated
                  ? 'Reaplicar Template'
                  : 'Aplicar Template',
              onPressed: _isApplyingTemplate ? null : _manuallyApplyTemplate,
              padding: const EdgeInsets.all(8),
              visualDensity: VisualDensity.compact,
            ),

          // Indicador de carregamento
          if (_isSyncing || _isApplyingTemplate || _isRestoringCheckpoint)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            ),

          // Botão de menu
          if (!(_isSyncing || _isApplyingTemplate || _isRestoringCheckpoint))
            PopupMenuButton<String>(
              padding: const EdgeInsets.all(8),
              icon: const Icon(Icons.more_vert, size: 22),
              onSelected: (value) async {
                switch (value) {
                  case 'import':
                    await _importInspection();
                    break;
                  case 'nonConformities':
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NonConformityScreen(
                          inspectionId: widget.inspectionId,
                        ),
                      ),
                    );
                    break;
                  case 'media':
                    _navigateToMediaGallery();
                    break;
                  case 'checkpointHistory':
                    _showCheckpointHistory();
                    break;
                  case 'refresh':
                    await _loadInspection();
                    break;
                  case 'info':
                    if (_inspection != null) {
                      final inspectionId = _inspection!.id;
                      final inspectionService = FirebaseInspectionService();
                      int totalTopics = _topics.length;
                      int totalItems = 0;
                      int totalDetails = 0;
                      int totalMedia = 0;
                      for (final topic in _topics) {
                        final items = await inspectionService.getItems(
                            inspectionId, topic.id!);
                        totalItems += items.length;
                        for (final item in items) {
                          final details = await inspectionService.getDetails(
                              inspectionId, topic.id!, item.id!);
                          totalDetails += details.length;
                        }
                      }
                      // Buscar mídias diretamente do Firestore
                      final allMedia =
                          await inspectionService.getAllMedia(inspectionId);
                      totalMedia = allMedia.length;

                      showDialog(
                        context: context,
                        builder: (context) => InspectionInfoDialog(
                          inspection: _inspection!,
                          totalTopics: totalTopics,
                          totalItems: totalItems,
                          totalDetails: totalDetails,
                          totalMedia: totalMedia,
                        ),
                      );
                    }
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Row(
                    children: [
                      Icon(Icons.file_upload),
                      SizedBox(width: 8),
                      Text('Importar Inspeção'),
                    ],
                  ),
                ),
                // Item para histórico de checkpoints
                const PopupMenuItem(
                  value: 'checkpointHistory',
                  child: Row(
                    children: [
                      Icon(Icons.history),
                      SizedBox(width: 8),
                      Text('Histórico de Checkpoints'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Atualizar Dados'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline),
                      SizedBox(width: 8),
                      Text('Informações'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: _buildBody(isLandscape, screenSize),
      ),
    );
  }

  // Constrói o corpo principal da tela
  Widget _buildBody(bool isLandscape, Size screenSize) {
    if (_isLoading) {
      return LoadingState(
          isDownloading: false, isApplyingTemplate: _isApplyingTemplate);
    }

    if (_isRestoringCheckpoint) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 24),
            Text(
              'Restaurando checkpoint...',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Por favor, aguarde enquanto a inspeção é restaurada.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Calcula a altura disponível
    final double availableHeight = screenSize.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
        // Área de conteúdo principal
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: screenSize.width,
              maxHeight: availableHeight,
            ),
            child: _topics.isEmpty
                ? EmptyTopicState(onAddTopic: _addTopic)
                : StatefulBuilder(
                    builder: (context, setState) {
                      return TopicsList(
                        topics: _topics,
                        expandedTopicIndex: _expandedTopicIndex,
                        onTopicUpdated: _updateTopic,
                        onTopicDeleted: _deleteTopic,
                        onTopicDuplicated: _duplicateTopic,
                        onExpansionChanged: (index) {
                          setState(() {
                            _expandedTopicIndex =
                                _expandedTopicIndex == index ? -1 : index;
                          });
                        },
                        inspectionId: widget.inspectionId,
                        onTopicsReordered: _loadTopics,
                      );
                    },
                  ),
          ),
        ),

        // Espaçamento inferior
        const SizedBox(height: 2),

        // Barra de atalhos para funcionalidades principais
        if (!_isLoading && _topics.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Atalho para Galeria de Mídia
                _buildShortcutButton(
                  icon: Icons.photo_library,
                  label: 'Galeria',
                  onTap: _navigateToMediaGallery,
                  color: Colors.purple,
                ),

                // Atalho para Não Conformidades
                _buildShortcutButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'NCs',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => NonConformityScreen(
                          inspectionId: widget.inspectionId,
                        ),
                      ),
                    );
                  },
                  color: const Color.fromARGB(255, 255, 0, 0),
                ),

                // Atalho para Adicionar Tópico
                _buildShortcutButton(
                  icon: Icons.add_circle_outline,
                  label: '+ Tópico',
                  onTap: _addTopic,
                  color: Colors.blue,
                ),

                // Atalho para Exportar
                _buildShortcutButton(
                  icon: Icons.download,
                  label: 'Exportar',
                  onTap: _exportInspection,
                  color: Colors.green,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Constrói um botão de atalho para a barra inferior
  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.zero,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 30,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
