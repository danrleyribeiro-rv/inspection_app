// lib/presentation/screens/inspection/detail_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inspection_app/models/detail.dart';
import 'package:inspection_app/presentation/widgets/media/media_handling_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/non_conformity_screen.dart';
import 'package:inspection_app/presentation/widgets/dialogs/rename_dialog.dart';
import 'package:inspection_app/presentation/widgets/media/media_capture_popup.dart';
import 'package:image_picker/image_picker.dart';

class DetailWidget extends StatefulWidget {
 final Detail detail;
 final Function(Detail) onDetailUpdated;
 final Function(String) onDetailDeleted;
 final Function(Detail) onDetailDuplicated;
 final bool isExpanded;
 final VoidCallback onExpansionChanged;

 const DetailWidget({
   super.key,
   required this.detail,
   required this.onDetailUpdated,
   required this.onDetailDeleted,
   required this.onDetailDuplicated,
   required this.isExpanded,
   required this.onExpansionChanged,
 });

 @override
 State<DetailWidget> createState() => _DetailWidgetState();
}

class _DetailWidgetState extends State<DetailWidget> {
 final TextEditingController _valueController = TextEditingController();
 final TextEditingController _observationController = TextEditingController();
 late bool _isDamaged;
 Timer? _debounce;

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

 Future<void> _editObservationDialog() async {
   final result = await showDialog<String>(
     context: context,
     builder: (context) {
       final controller = TextEditingController(text: _observationController.text);
       return AlertDialog(
         title: const Text('Observações do Detalhe'),
         content: SizedBox(
           width: MediaQuery.of(context).size.width * 0.8,
           child: ConstrainedBox(
             constraints: const BoxConstraints(maxHeight: 220),
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
     _observationController.text = result;
     _updateDetail();
     setState(() {});
   }
 }

 void _showMediaCapturePopup() {
   showModalBottomSheet(
     context: context,
     backgroundColor: Colors.transparent,
     builder: (context) => MediaCapturePopup(
       onMediaSelected: _captureDetailMedia,
     ),
   );
 }

 Future<void> _captureDetailMedia(ImageSource source, String type) async {
   // Implementação básica - você pode expandir conforme necessário
   ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
       content: Text('${type == 'image' ? 'Foto' : 'Vídeo'} capturado via ${source == ImageSource.camera ? 'câmera' : 'galeria'}'),
       backgroundColor: Colors.green,
     ),
   );
 }

 Future<void> _showDeleteConfirmation() async {
   final confirmed = await showDialog<bool>(
     context: context,
     builder: (context) => AlertDialog(
       title: const Text('Excluir Detalhe'),
       content: Text('Tem certeza que deseja excluir "${widget.detail.detailName}"?\n\nTodas as mídias associadas serão excluídas permanentemente.'),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(context).pop(false),
           child: const Text('Cancelar'),
         ),
         TextButton(
           onPressed: () => Navigator.of(context).pop(true),
           style: TextButton.styleFrom(foregroundColor: Colors.red),
           child: const Text('Excluir'),
         ),
       ],
     ),
   );

   if (confirmed == true && widget.detail.id != null) {
     widget.onDetailDeleted(widget.detail.id!);
   }
 }

 @override
 Widget build(BuildContext context) {
   return Card(
     margin: const EdgeInsets.only(bottom: 6), // Reduzido
     elevation: 0,
     shape: RoundedRectangleBorder(
       borderRadius: BorderRadius.zero,
       side: BorderSide(
         color: _isDamaged ? Colors.red : Colors.grey.shade300,
         width: _isDamaged ? 2 : 1,
       ),
     ),
     child: Column(
       children: [
         InkWell(
           onTap: widget.onExpansionChanged,
           child: Padding(
             padding: const EdgeInsets.all(10), // Reduzido
             child: Row(
               children: [
                 if (_isDamaged) const Icon(Icons.warning, color: Colors.red, size: 16),
                 const SizedBox(width: 8),
                 Expanded(
                   child: Text(
                     widget.detail.detailName,
                     style: TextStyle(
                       fontSize: 16,
                       fontWeight: FontWeight.bold,
                       color: _isDamaged ? Colors.red : null,
                     ),
                   ),
                 ),
                 if (_valueController.text.isNotEmpty)
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     decoration: BoxDecoration(
                       color: Colors.blue.shade100,
                       borderRadius: BorderRadius.circular(6),
                     ),
                     child: Text(
                       _valueController.text,
                       style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                     ),
                   ),
                 const SizedBox(width: 4),
                 IconButton(
                   icon: const Icon(Icons.edit, size: 18),
                   onPressed: _renameDetail,
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                   tooltip: 'Renomear Detalhe',
                 ),
                 const SizedBox(width: 4),
                 IconButton(
                   icon: const Icon(Icons.copy, size: 18),
                   onPressed: () => widget.onDetailDuplicated(widget.detail),
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                   tooltip: 'Duplicar Detalhe',
                 ),
                 const SizedBox(width: 4),
                 IconButton(
                   icon: const Icon(Icons.delete, size: 18),
                   onPressed: _showDeleteConfirmation,
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                   tooltip: 'Excluir Detalhe',
                 ),
                 const SizedBox(width: 4),
                 Icon(widget.isExpanded ? Icons.expand_less : Icons.expand_more, size: 18),
               ],
             ),
           ),
         ),
         if (widget.isExpanded) ...[
           Divider(height: 1, thickness: 1, color: Colors.grey[300]),
           Padding(
             padding: const EdgeInsets.all(12), // Reduzido
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   children: [
                     Checkbox(
                       value: _isDamaged,
                       onChanged: (value) {
                         setState(() => _isDamaged = value ?? false);
                         _updateDetail();
                       },
                     ),
                     const Text('Com NC'),
                   ],
                 ),
                 const SizedBox(height: 5),
                 
                 // Campo de valor com dropdown ou text
                 if (widget.detail.type == 'select' && 
                     widget.detail.options != null && 
                     widget.detail.options!.isNotEmpty)
                   DropdownButtonFormField<String>(
                     value: _valueController.text.isNotEmpty ? _valueController.text : null,
                     decoration: const InputDecoration(
                       labelText: 'Valor',
                       border: OutlineInputBorder(),
                       hintText: 'Selecione um valor',
                     ),
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
                     decoration: const InputDecoration(
                       labelText: 'Valor',
                       border: OutlineInputBorder(),
                       hintText: 'Digite um valor',
                     ),
                     onChanged: (_) => _updateDetail(),
                   ),
                 const SizedBox(height: 12),
                 
                 // Campo de observação com popup
                 GestureDetector(
                   onTap: _editObservationDialog,
                   child: AbsorbPointer(
                     child: TextFormField(
                       controller: _observationController,
                       decoration: InputDecoration(
                         labelText: 'Observações',
                         border: const OutlineInputBorder(),
                         hintText: _observationController.text.isEmpty 
                             ? 'Toque para adicionar observações...' 
                             : null,
                         suffixIcon: const Icon(Icons.edit, size: 18),
                       ),
                       maxLines: 1,
                     ),
                   ),
                 ),
                 const SizedBox(height: 12),
                 
                 // Botões de mídia
                 Row(
                   children: [
                     Expanded(
                       child: ElevatedButton.icon(
                         icon: const Icon(Icons.camera_alt, size: 18),
                         label: const Text('Capturar Mídia', style: TextStyle(fontSize: 12)),
                         onPressed: _showMediaCapturePopup,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.blue,
                           foregroundColor: Colors.white,
                         ),
                       ),
                     ),
                     const SizedBox(width: 8),
                     Expanded(
                       child: ElevatedButton.icon(
                         icon: const Icon(Icons.report_problem, size: 18),
                         label: const Text('Add NC', style: TextStyle(fontSize: 12)),
                         onPressed: () {
                           if (widget.detail.id != null && 
                               widget.detail.topicId != null && 
                               widget.detail.itemId != null) {
                             Navigator.of(context).push(
                               MaterialPageRoute(
                                 builder: (context) => NonConformityScreen(
                                   inspectionId: widget.detail.inspectionId,
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
                         ),
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 8),
                 
                 // Widget de mídia existente
                 if (widget.detail.id != null && 
                     widget.detail.topicId != null && 
                     widget.detail.itemId != null)
                   MediaHandlingWidget(
                     inspectionId: widget.detail.inspectionId,
                     topicIndex: int.parse(widget.detail.topicId!.replaceFirst('topic_', '')),
                     itemIndex: int.parse(widget.detail.itemId!.replaceFirst('item_', '')),
                     detailIndex: int.parse(widget.detail.id!.replaceFirst('detail_', '')),
                     onMediaAdded: (_) => setState(() {}),
                     onMediaDeleted: (_) => setState(() {}),
                   ),
               ],
             ),
           ),
         ],
       ],
     ),
   );
 }
}