// lib/presentation/screens/inspection/components/detail_details_section.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/models/item.dart';
import 'package:inspection_app/models/topic.dart';
import 'package:inspection_app/services/service_factory.dart';
import 'package:inspection_app/presentation/widgets/media/media_capture_popup.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/widgets/media/media_handling_widget.dart';
import 'package:image_picker/image_picker.dart';

class DetailDetailsSection extends StatefulWidget {
  final Detail detail;
  final Item item;
  final Topic topic;
  final String inspectionId;
  final Function(Detail) onDetailUpdated;

  const DetailDetailsSection({
    super.key,
    required this.detail,
    required this.item,
    required this.topic,
    required this.inspectionId,
    required this.onDetailUpdated,
  });

  @override
  State<DetailDetailsSection> createState() => _DetailDetailsSectionState();
}

class _DetailDetailsSectionState extends State<DetailDetailsSection> {
  final ServiceFactory _serviceFactory = ServiceFactory();
  final TextEditingController _valueController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  Timer? _debounce;
  bool _isDamaged = false;

  @override
  void initState() {
    super.initState();
    _valueController.text = widget.detail.detailValue ?? '';
    _observationController.text = widget.detail.observation ?? '';
    _isDamaged = widget.detail.isDamaged ?? false;
  }

  @override
  void dispose() {
    _valueController.dispose();
    _observationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _updateDetail() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final updatedDetail = widget.detail.copyWith(
        detailValue: _valueController.text.isEmpty ? null : _valueController.text,
        observation: _observationController.text.isEmpty ? null : _observationController.text,
        isDamaged: _isDamaged,
        updatedAt: DateTime.now(),
      );
      widget.onDetailUpdated(updatedDetail);
    });
  }

  Future<void> _editObservationDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _observationController.text);
        return AlertDialog(
          title: const Text('Observações do Detalhe'),
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
      _updateDetail();
    }
  }

  Future<void> _renameDetail() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => RenameDialog(
        title: 'Renomear Detalhe',
        label: 'Nome do Detalhe',
        initialValue: widget.detail.detailName,
      ),
    );

    if (newName != null && newName != widget.detail.detailName) {
      final updatedDetail = widget.detail.copyWith(
        detailName: newName,
        updatedAt: DateTime.now(),
      );
      widget.onDetailUpdated(updatedDetail);
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
              content: Text('${type == 'image' ? 'Foto' : 'Vídeo'} capturado via ${source == ImageSource.camera ? 'câmera' : 'galeria'}'),
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
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withAlpha((255 * 0.2).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Campo de valor
          if (widget.detail.type == 'select' && 
              widget.detail.options != null && 
              widget.detail.options!.isNotEmpty)
            DropdownButtonFormField<String>(
              value: _valueController.text.isNotEmpty ? _valueController.text : null,
              decoration: InputDecoration(
                labelText: 'Valor',
                border: const OutlineInputBorder(),
                hintText: 'Selecione um valor',
                labelStyle: TextStyle(color: Colors.green.shade300),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.green.shade300),
                ),
              ),
              dropdownColor: const Color(0xFF2A3749),
              style: const TextStyle(color: Colors.white),
              items: widget.detail.options!.map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _valueController.text = value);
                  _updateDetail();
                }
              },
            )
          else
            TextFormField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: 'Valor',
                border: const OutlineInputBorder(),
                hintText: 'Digite um valor',
                labelStyle: TextStyle(color: Colors.green.shade300),
focusedBorder: OutlineInputBorder(
                 borderSide: BorderSide(color: Colors.green.shade300),
               ),
             ),
             style: const TextStyle(color: Colors.white),
             onChanged: (_) => _updateDetail(),
           ),
         
         const SizedBox(height: 16),
         
         // Campo de observações
         GestureDetector(
           onTap: _editObservationDialog,
           child: Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               border: Border.all(color: Colors.green.withAlpha((255 * 0.3).round())),
               borderRadius: BorderRadius.circular(8),
             ),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Icon(Icons.note_alt, size: 16, color: Colors.green.shade300),
                     const SizedBox(width: 8),
                     Text(
                       'Observações',
                       style: TextStyle(
                         fontWeight: FontWeight.bold,
                         color: Colors.green.shade300,
                       ),
                     ),
                     const Spacer(),
                     Icon(Icons.edit, size: 16, color: Colors.green.shade300),
                   ],
                 ),
                 const SizedBox(height: 8),
                 Text(
                   _observationController.text.isEmpty 
                       ? 'Toque para adicionar observações...'
                       : _observationController.text,
                   style: TextStyle(
                     color: _observationController.text.isEmpty 
                         ? Colors.green.shade200
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
         
         const SizedBox(height: 16),
         
         // Botões de ação principais (Mídia e NC lado a lado)
         Row(
           children: [
             Expanded(
               child: ElevatedButton.icon(
                 icon: const Icon(Icons.camera_alt, size: 18),
                 label: const Text('Capturar Mídia'),
                 onPressed: _showMediaCapturePopup,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.blue,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 12),
                 ),
               ),
             ),
             const SizedBox(width: 12),
             Expanded(
               child: ElevatedButton.icon(
                 icon: const Icon(Icons.report_problem, size: 18),
                 label: const Text('Add NC'),
                 onPressed: () {
                   if (widget.detail.id != null && 
                       widget.detail.topicId != null && 
                       widget.detail.itemId != null) {
                     Navigator.of(context).push(
                       MaterialPageRoute(
                         builder: (context) => NonConformityScreen(
                           inspectionId: widget.inspectionId,
                           preSelectedTopic: widget.detail.topicId,
                           preSelectedItem: widget.detail.itemId,
                           preSelectedDetail: widget.detail.id,
                         ),
                       ),
                     );
                   }
                 },
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.orange,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 12),
                 ),
               ),
             ),
           ],
         ),
         
         const SizedBox(height: 16),
         
         // Botões de ação secundários
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
           children: [
             _buildActionButton(
               icon: Icons.edit,
               label: 'Renomear',
               onPressed: _renameDetail,
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
         
         // Widget de mídia existente
         if (widget.detail.id != null && 
             widget.detail.topicId != null && 
             widget.detail.itemId != null)
           MediaHandlingWidget(
             inspectionId: widget.inspectionId,
             topicIndex: int.parse(widget.detail.topicId!.replaceFirst('topic_', '')),
             itemIndex: int.parse(widget.detail.itemId!.replaceFirst('item_', '')),
             detailIndex: int.parse(widget.detail.id!.replaceFirst('detail_', '')),
             onMediaAdded: (_) => setState(() {}),
             onMediaDeleted: (_) => setState(() {}),
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
             backgroundColor: color ?? Colors.green,
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