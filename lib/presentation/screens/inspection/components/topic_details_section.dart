// lib/presentation/screens/inspection/components/topic_details_section.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:inspection_app/presentation/screens/media/media_gallery_screen.dart';
import 'package:inspection_app/presentation/widgets/media/custom_camera_widget.dart';

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
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final updatedTopic = widget.topic.copyWith(
        observation: _observationController.text.isEmpty ? null : _observationController.text,
        updatedAt: DateTime.now(),
      );
      _serviceFactory.coordinator.updateTopic(updatedTopic);
      widget.onTopicUpdated(updatedTopic);
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
      builder: (context) => CustomCameraWidget(
        onMediaCaptured: _handleMediaCaptured,
      ),
    ));
  }
  
  Future<void> _handleMediaCaptured(List<String> localPaths, String type) async {
    if (mounted) setState(() => _processingCount += localPaths.length);
    
    for (final path in localPaths) {
      _processAndSaveMedia(path, type).whenComplete(() {
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
          title: const Text('Observações do Tópico', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.blue.withAlpha(15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withAlpha(50))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(icon: Icons.camera_alt, label: 'Capturar', onPressed: _captureTopicMedia, color: Colors.purple),
              _buildActionButton(icon: Icons.photo_library, label: 'Galeria', onPressed: _openTopicGallery, color: Colors.purple),
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
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _editObservationDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.blue.withAlpha(75)), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.note_alt, size: 14, color: Colors.blue.shade300),
                    const SizedBox(width: 4),
                    Text('Observações', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade300)),
                    const Spacer(),
                    Icon(Icons.edit, size: 14, color: Colors.blue.shade300),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    _observationController.text.isEmpty ? 'Toque para adicionar observações...' : _observationController.text,
                    style: TextStyle(color: _observationController.text.isEmpty ? Colors.blue.shade200 : Colors.white, fontStyle: _observationController.text.isEmpty ? FontStyle.italic : FontStyle.normal),
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
            style: ElevatedButton.styleFrom(backgroundColor: color ?? Colors.blue, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Icon(icon, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}