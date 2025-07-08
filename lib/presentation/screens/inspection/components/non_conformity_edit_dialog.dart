// lib/presentation/screens/inspection/components/non_conformity_edit_dialog.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:inspection_app/presentation/widgets/media/native_camera_widget.dart';

class NonConformityEditDialog extends StatefulWidget {
  final Map<String, dynamic> nonConformity;
  final Function(Map<String, dynamic>) onSave;

  const NonConformityEditDialog({
    super.key,
    required this.nonConformity,
    required this.onSave,
  });

  @override
  State<NonConformityEditDialog> createState() =>
      _NonConformityEditDialogState();
}

class _NonConformityEditDialogState extends State<NonConformityEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _correctiveActionController;
  late String _severity;
  bool _isResolved = false;
  final List<String> _resolutionImagePaths = [];

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.nonConformity['description'] ?? '');
    _correctiveActionController = TextEditingController(
        text: widget.nonConformity['corrective_action'] ?? '');
    _severity = widget.nonConformity['severity'] ?? 'Média';
    _isResolved = widget.nonConformity['is_resolved'] ?? false;
    
    // Load existing resolution images if any
    final resolutionImages = widget.nonConformity['resolution_images'] as List<dynamic>?;
    if (resolutionImages != null) {
      _resolutionImagePaths.addAll(resolutionImages.cast<String>());
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _correctiveActionController.dispose();
    super.dispose();
  }

  Future<void> _addResolutionMedia() async {
    try {
      // Abrir câmera diretamente para capturar imagem de resolução
      final result = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (context) => NativeCameraWidget(
            onImagesSelected: (List<String> imagePaths) {
              Navigator.of(context).pop(imagePaths);
            },
            allowMultiple: true,
          ),
        ),
      );
      
      if (result != null && result.isNotEmpty && mounted) {
        setState(() {
          _resolutionImagePaths.addAll(result);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result.length} imagem(ns) de resolução capturada(s) com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        debugPrint('Imagens de resolução capturadas: $result');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar mídia: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Não Conformidade'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity dropdown
              const Text('Severidade:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _severity,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'Baixa', child: Text('Baixa')),
                  DropdownMenuItem(value: 'Média', child: Text('Média')),
                  DropdownMenuItem(value: 'Alta', child: Text('Alta')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _severity = value);
                  }
                },
              ),

              const SizedBox(height: 16),

              // Description field
              const Text('Descrição:'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty
                    ? 'A descrição é obrigatória'
                    : null,
              ),

              const SizedBox(height: 16),

              // Corrective action field
              const Text('Ação Corretiva (opcional):'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _correctiveActionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Resolution status
              CheckboxListTile(
                title: const Text('Marcar como resolvida'),
                subtitle: _isResolved 
                    ? const Text('Esta não conformidade foi resolvida')
                    : const Text('Marque quando a não conformidade for corrigida'),
                value: _isResolved,
                onChanged: (value) {
                  setState(() => _isResolved = value ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              
              if (_isResolved) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha((255 * 0.1).round()),
                    border: Border.all(color: Colors.green.withAlpha((255 * 0.3).round())),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Imagens de Resolução',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isResolved) // Apenas mostra quando marcado como resolvido
                        ElevatedButton.icon(
                          onPressed: _addResolutionMedia,
                          icon: const Icon(Icons.camera_alt, size: 16),
                          label: const Text('Adicionar Fotos de Resolução'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (_resolutionImagePaths.isNotEmpty) ...[
                        const Text('Imagens de Resolução:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _resolutionImagePaths.asMap().entries.map((entry) {
                            final index = entry.key;
                            final path = entry.value;
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: path.startsWith('http') 
                                    ? Image.network(
                                        path,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          );
                                        },
                                      )
                                    : Image.file(
                                        File(path),
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image, color: Colors.grey),
                                          );
                                        },
                                      ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _resolutionImagePaths.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              // Create updated non-conformity data
              final updatedData = {
                ...widget.nonConformity,
                'description': _descriptionController.text,
                'corrective_action': _correctiveActionController.text.isEmpty
                    ? null
                    : _correctiveActionController.text,
                'severity': _severity,
                'is_resolved': _isResolved,
                'resolution_images': _resolutionImagePaths,
              };

              widget.onSave(updatedData);
            }
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
