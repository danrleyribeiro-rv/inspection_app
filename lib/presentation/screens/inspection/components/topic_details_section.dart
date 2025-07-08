// lib/presentation/screens/inspection/components/topic_details_section.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/presentation/widgets/media/native_camera_widget.dart';

class TopicDetailsSection extends StatefulWidget {
  final Topic topic;
  final String inspectionId;
  final Function(Topic) onTopicUpdated;
  final VoidCallback onTopicAction;

  const TopicDetailsSection({
    super.key,
    required this.topic,
    required this.inspectionId,
    required this.onTopicUpdated,
    required this.onTopicAction,
  });

  @override
  State<TopicDetailsSection> createState() => _TopicDetailsSectionState();
}

class _TopicDetailsSectionState extends State<TopicDetailsSection> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  String _currentTopicName = '';
  int _processingCount = 0;

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.topic.observation ?? '';
    _currentTopicName = widget.topic.topicName;
    _observationController.addListener(_updateTopicObservation);
  }

  @override
  void didUpdateWidget(TopicDetailsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.topic.topicName != _currentTopicName) {
      _currentTopicName = widget.topic.topicName;
    }
    if (widget.topic.observation != _observationController.text) {
      _observationController.text = widget.topic.observation ?? '';
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateTopicObservation() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    // Update UI immediately
    final updatedTopic = widget.topic.copyWith(
      observation: _observationController.text.isEmpty ? null : _observationController.text,
      updatedAt: DateTime.now(),
    );
    widget.onTopicUpdated(updatedTopic);
    
    // Debounce the actual save operation
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _serviceFactory.coordinator.updateTopic(updatedTopic);
    });
  }
  
  void _openTopicGallery() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => MediaGalleryScreen(
        inspectionId: widget.inspectionId,
        initialTopicId: widget.topic.id,
        // THE FIX: Passagem explícita do filtro de nível.
        initialTopicOnly: true, 
      ),
    ));
  }
  
  void _captureTopicMedia() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => NativeCameraWidget(
        onImagesSelected: _handleImagesSelected,
        allowMultiple: true,
        inspectionId: widget.inspectionId,
        topicId: widget.topic.id,
      ),
    ));
  }
  
  Future<void> _handleImagesSelected(List<String> imagePaths) async {
    if (mounted) setState(() => _processingCount += imagePaths.length);
    
    for (final path in imagePaths) {
      _processAndSaveMedia(path, 'image').whenComplete(() {
        if (mounted) setState(() => _processingCount--);
      });
    }
    widget.onTopicAction();
  }

  Future<void> _processAndSaveMedia(String localPath, String type) async {
    try {
      final position = await _serviceFactory.mediaService.getCurrentLocation();
      
      // Usar o fluxo offline-first do MediaService
      final offlineMedia = await _serviceFactory.mediaService.captureAndProcessMedia(
        inputPath: localPath,
        inspectionId: widget.inspectionId,
        type: type,
        topicId: widget.topic.id,
        metadata: {
          'source': 'camera',
          'is_non_conformity': false,
          'location': position != null ? {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy
          } : null,
        },
      );
      
      // Converter OfflineMedia para formato esperado pelo coordinator
      final mediaData = {
        'id': offlineMedia.id,
        'type': offlineMedia.type,
        'localPath': offlineMedia.localPath,
        'url': offlineMedia.uploadUrl,
        'aspect_ratio': '4:3',
        'source': 'camera',
        'is_non_conformity': false,
        'created_at': offlineMedia.createdAt.toIso8601String(),
        'updated_at': offlineMedia.createdAt.toIso8601String(),
        'metadata': offlineMedia.metadata,
      };
      
      await _serviceFactory.coordinator.addMediaToTopic(widget.inspectionId, widget.topic.id!, mediaData);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar mídia: $e')));
    }
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Tópico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          content: TextFormField(controller: controller, maxLines: 6, autofocus: true, decoration: const InputDecoration(hintText: 'Digite suas observações...', hintStyle: TextStyle(fontSize: 12, color: Colors.grey), border: OutlineInputBorder())),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Salvar')),
          ],
        );
      },
    );
    if (result != null) {
      setState(() => _observationController.text = result);
      _updateTopicObservation();
    }
  }

  Future<void> _renameTopic() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(title: 'Renomear Tópico', label: 'Nome do Tópico', initialValue: widget.topic.topicName),
    );
    if (newName != null && newName != widget.topic.topicName) {
      final updatedTopic = widget.topic.copyWith(topicName: newName, updatedAt: DateTime.now());
      setState(() => _currentTopicName = newName);
      widget.onTopicUpdated(updatedTopic);
      await _serviceFactory.coordinator.updateTopic(updatedTopic);
    }
  }

  Future<void> _duplicateTopic() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Duplicar Tópico'), content: Text('Deseja duplicar o tópico "${widget.topic.topicName}"?'), actions: [ TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Duplicar')) ]));
    if (confirmed != true) return;
    try {
      await _serviceFactory.coordinator.duplicateTopic(widget.inspectionId, widget.topic);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tópico duplicado com sucesso'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao duplicar tópico: $e')));
    }
    widget.onTopicAction();
  }

  Future<void> _addTopicNonConformity() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _NonConformityDialog(),
    );
    
    if (result != null && mounted) {
      try {
        await _serviceFactory.coordinator.addNonConformityToTopic(
          widget.inspectionId,
          widget.topic.id!,
          result,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Não conformidade adicionada ao tópico'),
              backgroundColor: Colors.green,
            ),
          );
        }
        widget.onTopicAction();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao adicionar não conformidade: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteTopic() async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Excluir Tópico'), content: Text('Tem certeza que deseja excluir "${widget.topic.topicName}"?\n\nTodos os itens e detalhes serão excluídos permanentemente.'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')), TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Excluir'))]));
    if (confirmed != true) return;
    try {
      await _serviceFactory.coordinator.deleteTopic(widget.inspectionId, widget.topic.id!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tópico excluído com sucesso'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir tópico: $e')));
    }
    widget.onTopicAction();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Color(0xFF6F4B99).withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Color(0xFF6F4B99).withAlpha(50))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _buildActionButton(icon: Icons.camera_alt, label: 'Capturar', onPressed: _captureTopicMedia, color: Colors.purple),
              _buildActionButton(icon: Icons.photo_library, label: 'Galeria', onPressed: _openTopicGallery, color: Colors.purple),
              _buildActionButton(icon: Icons.warning, label: 'NC', onPressed: _addTopicNonConformity, color: Colors.orange),
              _buildActionButton(icon: Icons.edit, label: 'Renomear', onPressed: _renameTopic),
              _buildActionButton(icon: Icons.copy, label: 'Duplicar', onPressed: _duplicateTopic),
              _buildActionButton(icon: Icons.delete, label: 'Excluir', onPressed: _deleteTopic, color: Colors.red),
            ],
          ),
          if (_processingCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text("Processando $_processingCount mídia(s)...", style: const TextStyle(fontStyle: FontStyle.italic)),
              ]),
            ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _editObservationDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(border: Border.all(color: Color(0xFF6F4B99).withAlpha(75)), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.note_alt, size: 14, color: Color(0xFF9F7FD1)),
                    const SizedBox(width: 4),
                    Text('Observações', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9F7FD1))),
                    const Spacer(),
                    Icon(Icons.edit, size: 14, color: Color(0xFF9F7FD1)),
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    _observationController.text.isEmpty ? 'Toque para adicionar observações...' : _observationController.text,
                    style: TextStyle(color: _observationController.text.isEmpty ? Color(0xFFB19EE5) : Colors.white, fontStyle: _observationController.text.isEmpty ? FontStyle.italic : FontStyle.normal),
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onPressed, Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(backgroundColor: color ?? Color(0xFF6F4B99), foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Icon(icon, size: 20),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}

class _NonConformityDialog extends StatefulWidget {
  @override
  State<_NonConformityDialog> createState() => _NonConformityDialogState();
}

class _NonConformityDialogState extends State<_NonConformityDialog> {
  final _descriptionController = TextEditingController();
  final _correctiveActionController = TextEditingController();
  String _severity = 'Média';

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Não Conformidade'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _severity,
              decoration: const InputDecoration(
                labelText: 'Severidade',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                DropdownMenuItem(value: 'Média', child: Text('Média')),
                DropdownMenuItem(value: 'Alta', child: Text('Alta')),
              ],
              onChanged: (value) => setState(() => _severity = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _correctiveActionController,
              decoration: const InputDecoration(
                labelText: 'Ação Corretiva (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_descriptionController.text.isNotEmpty) {
              Navigator.of(context).pop({
                'description': _descriptionController.text,
                'severity': _severity,
                'corrective_action': _correctiveActionController.text.isEmpty 
                    ? null 
                    : _correctiveActionController.text,
              });
            }
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}