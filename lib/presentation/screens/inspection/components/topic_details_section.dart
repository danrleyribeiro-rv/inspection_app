// lib/presentation/screens/inspection/components/topic_details_section.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/media/media_capture_popup.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:image_picker/image_picker.dart';

class TopicDetailsSection extends StatefulWidget {
  final Topic topic;
  final String inspectionId;
  final Function(Topic) onTopicUpdated;

  const TopicDetailsSection({
    super.key,
    required this.topic,
    required this.inspectionId,
    required this.onTopicUpdated,
  });

  @override
  State<TopicDetailsSection> createState() => _TopicDetailsSectionState();
}

class _TopicDetailsSectionState extends State<TopicDetailsSection> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  bool _isAddingMedia = false;

  @override
  void initState() {
    super.initState();
    _observationController.text = widget.topic.observation ?? '';
  }

  @override
  void dispose() {
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateTopic() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final updatedTopic = widget.topic.copyWith(
        observation: _observationController.text.isEmpty
            ? null
            : _observationController.text,
        updatedAt: DateTime.now(),
      );
      widget.onTopicUpdated(updatedTopic);
    });
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Tópico'),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: TextFormField(
              controller: controller,
              maxLines: 6,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Digite suas observações...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    
    if (result != null) {
      setState(() {
        _observationController.text = result;
      });
      _updateTopic();
    }
  }

  Future<void> _renameTopic() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Tópico',
        label: 'Nome do Tópico',
        initialValue: widget.topic.topicName,
      ),
    );

    if (newName != null && newName != widget.topic.topicName) {
      final updatedTopic = widget.topic.copyWith(
        topicName: newName,
        updatedAt: DateTime.now(),
      );
      widget.onTopicUpdated(updatedTopic);
    }
  }

  void _showMediaCapturePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => MediaCapturePopup(
        onMediaSelected: (source, type) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${type == 'image' ? 'Foto' : 'Vídeo'} do tópico capturado'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withAlpha((255 * 0.2).round())),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Botões de ação
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: Icons.camera_alt,
                label: 'Mídia',
                onPressed: _showMediaCapturePopup,
              ),
              _buildActionButton(
                icon: Icons.edit,
                label: 'Renomear',
                onPressed: _renameTopic,
              ),
              _buildActionButton(
                icon: Icons.copy,
                label: 'Duplicar',
                onPressed: () {
                  // Lógica para duplicar
                },
              ),
              _buildActionButton(
                icon: Icons.delete,
                label: 'Excluir',
                onPressed: () {
                  // Lógica para excluir
                },
                color: Colors.red,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Campo de observações
          GestureDetector(
            onTap: _editObservationDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.withAlpha((255 * 0.3).round())),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.note_alt, size: 16, color: Colors.blue.shade300),
                      const SizedBox(width: 8),
                      Text(
                        'Observações',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade300,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.edit, size: 16, color: Colors.blue.shade300),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _observationController.text.isEmpty 
                        ? 'Toque para adicionar observações...'
                        : _observationController.text,
                    style: TextStyle(
                      color: _observationController.text.isEmpty 
                          ? Colors.blue.shade200
                          : Colors.white,
                      fontStyle: _observationController.text.isEmpty 
                          ? FontStyle.italic 
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color ?? Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Icon(icon, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}