// lib/presentation/screens/inspection/inspection_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/models/inspection.dart';
import 'package:inspection_app/presentation/screens/inspection/components/topics_list.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/components/empty_topic_state.dart';
import 'package:inspection_app/presentation/screens/inspection/components/loading_state.dart';
import 'package:inspection_app/presentation/widgets/common/progress_circle.dart';
import 'package:inspection_app/presentation/widgets/dialogs/template_selector_dialog.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/presentation/screens/inspection/inspection_info_dialog.dart';
import 'package:inspection_app/services/features/chat_service.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/services/utils/checkpoint_dialog_service.dart';
import 'package:inspection_app/services/utils/progress_calculation_service.dart';

class InspectionDetailScreen extends StatefulWidget {
  final String inspectionId;

  const InspectionDetailScreen({super.key, required this.inspectionId});

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  // Services via factory
  final ServiceFactory _serviceFactory = ServiceFactory();
  late CheckpointDialogService _checkpointDialogService;

  // States
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _isOnline = true;
  bool _isApplyingTemplate = false;
  final bool _isRestoringCheckpoint = false;
  double _overallProgress = 0.0;
  Inspection? _inspection;
  List<Topic> _topics = [];
  int _expandedTopicIndex = -1;

  @override
  void initState() {
    super.initState();
    _listenToConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkpointDialogService =
            _serviceFactory.createCheckpointDialogService(
          context,
          _loadInspection,
        );
      }
    });

    _loadInspection();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _listenToConnectivity() {
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      if (mounted) {
        final newOnlineStatus =
            connectivityResult.contains(ConnectivityResult.wifi) ||
                connectivityResult.contains(ConnectivityResult.mobile);
        setState(() {
          _isOnline = newOnlineStatus;
        });

        if (newOnlineStatus &&
            _inspection != null &&
            _inspection!.templateId != null &&
            _inspection!.isTemplated != true) {
          _checkAndApplyTemplate();
        }
      }
    });

    Connectivity().checkConnectivity().then((connectivityResult) {
      if (mounted) {
        setState(() {
          _isOnline = connectivityResult.contains(ConnectivityResult.wifi) ||
              connectivityResult.contains(ConnectivityResult.mobile);
        });
      }
    });
  }

  void _showCreateCheckpointDialog() {
    _checkpointDialogService.showCreateCheckpointDialog(widget.inspectionId);
  }

  void _showCheckpointHistory() {
    _checkpointDialogService.showCheckpointHistory(widget.inspectionId);
  }

  Future<void> _loadInspection() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final inspection =
          await _serviceFactory.cacheService.getInspection(widget.inspectionId);
      if (!mounted) return;

      if (inspection != null) {
        setState(() {
          _inspection = inspection;
        });

        await _loadTopics();
        if (!mounted) return;

        await _loadProgress();
        if (!mounted) return;

        if (_isOnline && inspection.templateId != null) {
          if (inspection.isTemplated != true) {
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

  Future<void> _loadProgress() async {
    if (_inspection != null) {
      final progress = ProgressCalculationService.calculateOverallProgress(
          _inspection!.toMap());
      ProgressCalculationService.getInspectionStats(_inspection!.toMap());

      if (mounted) {
        setState(() {
          _overallProgress = progress;
        });
      }
    }
  }

  Future<void> _checkAndApplyTemplate() async {
    if (_inspection == null || !mounted) return;

    if (_inspection!.templateId != null) {
      final isAlreadyApplied = await _serviceFactory.coordinator
          .isTemplateAlreadyApplied(_inspection!.id);
      if (!mounted || isAlreadyApplied) {
        if (mounted)
          setState(
              () => _inspection = _inspection!.copyWith(isTemplated: true));
        return;
      }
      setState(() => _isApplyingTemplate = true);

      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aplicando template à inspeção...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        final success = await _serviceFactory.coordinator
            .applyTemplateToInspectionSafe(
                _inspection!.id, _inspection!.templateId!);

        if (!mounted) return;

        if (success) {
          await FirebaseFirestore.instance
              .collection('inspections')
              .doc(_inspection!.id)
              .update({
            'is_templated': true,
            'status': 'in_progress',
            'updated_at': FieldValue.serverTimestamp(),
          });

          if (!mounted) return;

          final updatedInspection = _inspection!.copyWith(
            isTemplated: true,
            status: 'in_progress',
            updatedAt: DateTime.now(),
          );
          setState(() => _inspection = updatedInspection);

          await _loadInspection();
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Template aplicado com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
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

  Future<void> _manuallyApplyTemplate() async {
    if (_inspection == null || !_isOnline || _isApplyingTemplate) return;

    final isAlreadyApplied = await _serviceFactory.coordinator
        .isTemplateAlreadyApplied(_inspection!.id);
    if (!mounted) return;

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

    if (!mounted || !shouldApply) return;

    setState(() => _isApplyingTemplate = true);

    try {
      if (isAlreadyApplied) {
        await FirebaseFirestore.instance
            .collection('inspections')
            .doc(_inspection!.id)
            .update({
          'is_templated': false,
          'updated_at': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _inspection = _inspection!.copyWith(isTemplated: false);
          });
        }
      }

      if (mounted) {
        await _checkAndApplyTemplate();
      }
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

  Future<void> _openInspectionChat() async {
    try {
      final chatService = ChatService();
      final chatId = await chatService.createOrGetChat(widget.inspectionId);

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/chat-detail',
          arguments: {'chatId': chatId},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir chat: $e')),
        );
      }
    }
  }

  Future<void> _loadTopics() async {
    if (_inspection?.id == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final topics =
          await _serviceFactory.cacheService.getTopics(widget.inspectionId);

      if (mounted) {
        setState(() {
          _topics = topics;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Erro ao carregar tópicos: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _addTopic() async {
    // Await é um async gap
    final template = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TemplateSelectorDialog(
        title: 'Adicionar Tópico',
        type: 'topic',
        parentName: 'Inspeção',
      ),
    );

    // Após o gap, verificar `mounted`
    if (template == null || !mounted) return;

    final topicName = template['name'] as String;
    final topicLabel = template['value'] as String?;

    setState(() => _isLoading = true);

    try {
      final position = _topics.isNotEmpty ? _topics.last.position + 1 : 0;
      await _serviceFactory.cacheService.addTopic(
        widget.inspectionId,
        topicName,
        label: topicLabel,
        position: position,
      );
      if (!mounted) return;

      await _loadTopics();
      if (!mounted) return;

      if (_topics.isNotEmpty) {
        setState(() {
          _expandedTopicIndex = _topics.length - 1;
        });
      }

      if (_inspection?.status == 'pending') {
        final updatedInspection = _inspection!.copyWith(
          status: 'in_progress',
          updatedAt: DateTime.now(),
        );
        await _serviceFactory.cacheService.saveInspection(updatedInspection);
        if (mounted) {
          setState(() {
            _inspection = updatedInspection;
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tópico adicionado com sucesso'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar tópico: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _duplicateTopic(Topic topic) async {
    setState(() => _isLoading = true);
    try {
      await _serviceFactory.cacheService
          .duplicateTopic(widget.inspectionId, topic.topicName);
      if (!mounted) return;

      await _loadTopics();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tópico "${topic.topicName}" duplicado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao duplicar tópico: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateTopic(Topic updatedTopic) async {
    try {
      await _serviceFactory.cacheService.updateTopic(updatedTopic);
      if (mounted) {
        final index = _topics.indexWhere((r) => r.id == updatedTopic.id);
        if (index >= 0) {
          setState(() {
            _topics[index] = updatedTopic;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar tópico: $e')),
        );
      }
    }
  }

  Future<void> _deleteTopic(dynamic topicId) async {
    setState(() => _isLoading = true);
    try {
      await _serviceFactory.cacheService
          .deleteTopic(widget.inspectionId, topicId);
      if (!mounted) return;

      await _loadTopics();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tópico excluído com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir tópico: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportInspection() async {
    final confirmed = await _serviceFactory.importExportService
        .showExportConfirmationDialog(context);
    if (!mounted || !confirmed) return;
    setState(() => _isSyncing = true);

    try {
      final filePath = await _serviceFactory.importExportService
          .exportInspection(widget.inspectionId);
      if (mounted) {
        _serviceFactory.importExportService.showSuccessMessage(
            context, 'Inspeção exportada com sucesso para:\n$filePath');
      }
    } catch (e) {
      if (mounted) {
        _serviceFactory.importExportService
            .showErrorMessage(context, 'Erro ao exportar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _importInspection() async {
    final confirmed = await _serviceFactory.importExportService
        .showImportConfirmationDialog(context);
    if (!mounted || !confirmed) return;
    setState(() => _isSyncing = true);

    try {
      final jsonData = await _serviceFactory.importExportService.pickJsonFile();
      if (!mounted || jsonData == null) {
        if (mounted) setState(() => _isSyncing = false);
        return;
      }

      final success = await _serviceFactory.importExportService
          .importInspection(widget.inspectionId, jsonData);
      if (!mounted) return;

      if (success) {
        await _loadInspection();
        if (mounted) {
          _serviceFactory.importExportService.showSuccessMessage(
              context, 'Dados da inspeção importados com sucesso');
        }
      } else {
        if (mounted) {
          _serviceFactory.importExportService
              .showErrorMessage(context, 'Falha ao importar dados da inspeção');
        }
      }
    } catch (e) {
      if (mounted) {
        _serviceFactory.importExportService
            .showErrorMessage(context, 'Erro ao importar inspeção: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _navigateToMediaGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MediaGalleryScreen(
          inspectionId: widget.inspectionId,
        ),
      ),
    );
  }

  // =================================================================
  // A CORREÇÃO FINAL: Extrair a lógica para um método separado.
  // =================================================================
  Future<void> _handleMenuSelection(String value) async {
    // A verificação `mounted` no início do método garante a segurança para todas as operações.
    if (!mounted) return;

    switch (value) {
      case 'import':
        await _importInspection();
        break;
      case 'nonConformities':
        // Agora, esta navegação está segura dentro do método.
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
      case 'chat':
        await _openInspectionChat();
        break;
      case 'info':
        if (_inspection != null) {
          final inspectionId = _inspection!.id;
          int totalTopics = _topics.length;
          int totalItems = 0;
          int totalDetails = 0;
          int totalMedia = 0;

          for (final topic in _topics) {
            if (!mounted) return;
            final items = await _serviceFactory.coordinator
                .getItems(inspectionId, topic.id!);
            totalItems += items.length;
            for (final item in items) {
              if (!mounted) return;
              final details = await _serviceFactory.coordinator
                  .getDetails(inspectionId, topic.id!, item.id!);
              totalDetails += details.length;
            }
          }

          if (!mounted) return;
          final allMedia =
              await _serviceFactory.coordinator.getAllMedia(inspectionId);
          totalMedia = allMedia.length;

          // A verificação final antes de usar o context para o dialog.
          if (mounted) {
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
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final screenSize = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                _inspection?.cod ?? 'Inspeção',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
            if (!_isLoading && _inspection != null) ...[
              const SizedBox(width: 8),
              ProgressCircle(
                progress: _overallProgress,
                size: 24,
                showPercentage: true,
              ),
              const SizedBox(width: 1),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined, size: 22),
            tooltip: 'Criar Checkpoint',
            onPressed: _showCreateCheckpointDialog,
            padding: const EdgeInsets.all(8),
            visualDensity: VisualDensity.compact,
          ),
          if (_isOnline &&
              _inspection != null &&
              _inspection!.templateId != null)
            IconButton(
              icon: const Icon(Icons.architecture, size: 22),
              tooltip: _inspection!.isTemplated
                  ? 'Reaplicar Template'
                  : 'Aplicar Template',
              onPressed: _isApplyingTemplate ? null : _manuallyApplyTemplate,
              padding: const EdgeInsets.all(5),
              visualDensity: VisualDensity.compact,
            ),
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
          if (!(_isSyncing || _isApplyingTemplate || _isRestoringCheckpoint))
            PopupMenuButton<String>(
              padding: const EdgeInsets.all(5),
              icon: const Icon(Icons.more_vert, size: 22),
              // Simplesmente chame o método extraído.
              onSelected: _handleMenuSelection,
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
                const PopupMenuItem(
                  value: 'nonConformities',
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Não Conformidades'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'media',
                  child: Row(
                    children: [
                      Icon(Icons.photo_library, color: Colors.purpleAccent),
                      SizedBox(width: 8),
                      Text('Galeria de Mídia'),
                    ],
                  ),
                ),
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
                const PopupMenuItem(
                  value: 'chat',
                  child: Row(
                    children: [
                      Icon(Icons.chat),
                      SizedBox(width: 8),
                      Text('Abrir Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'info',
                  child: Row(
                    children: [
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
              style: TextStyle(fontSize: 16, color: Colors.white),
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

    final double availableHeight = screenSize.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    return Column(
      children: [
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
        if (!_isLoading && _topics.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShortcutButton(
                  icon: Icons.photo_library,
                  label: 'Galeria',
                  onTap: _navigateToMediaGallery,
                  color: Colors.purple,
                ),
                _buildShortcutButton(
                  icon: Icons.warning_amber_rounded,
                  label: 'NCs',
                  onTap: () {
                    // Navegação síncrona dentro de um callback não-async é segura.
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
                _buildShortcutButton(
                  icon: Icons.add_circle_outline,
                  label: '+ Tópico',
                  onTap: _addTopic,
                  color: Colors.blue,
                ),
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

  Widget _buildShortcutButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
          decoration: BoxDecoration(
            color: color.withAlpha((255 * 0.08).round()),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: color,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
