// lib/presentation/screens/inspection/components/non_conformity_list.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/presentation/widgets/media/non_conformity_media_widget.dart';
import 'package:inspection_app/presentation/screens/inspection/components/non_conformity_edit_dialog.dart';

class NonConformityList extends StatelessWidget {
 final List<Map<String, dynamic>> nonConformities;
 final String inspectionId;
 final Function(String, String) onStatusUpdate;
 final Function(String) onDeleteNonConformity;
 final Function(Map<String, dynamic>) onEditNonConformity;
 final String? filterByDetailId;
 final Function()? onNonConformityUpdated;

 const NonConformityList({
   super.key,
   required this.nonConformities,
   required this.inspectionId,
   required this.onStatusUpdate,
   required this.onDeleteNonConformity,
   required this.onEditNonConformity,
   this.filterByDetailId,
   this.onNonConformityUpdated,
 });

 Color _getSeverityColor(String? severity) {
   switch (severity) {
     case 'Alta': return Colors.red;
     case 'Média': return Colors.orange;
     case 'Baixa': return Colors.blue;
     default: return Colors.grey;
   }
 }

 @override
 Widget build(BuildContext context) {
   if (nonConformities.isEmpty) {
     return const Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange),
           SizedBox(height: 16),
           Text('Nenhuma não conformidade registrada',
               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
           SizedBox(height: 8),
           Text('Cadastre uma nova não conformidade na outra aba'),
         ],
       ),
     );
   }

   final filteredNCs = filterByDetailId != null 
       ? nonConformities.where((nc) => nc['detail_id'] == filterByDetailId).toList()
       : nonConformities;

   return ListView.builder(
     padding: const EdgeInsets.all(8),
     itemCount: filteredNCs.length,
     itemBuilder: (context, index) => _buildCompactCard(context, filteredNCs[index]),
   );
 }

 Widget _buildCompactCard(BuildContext context, Map<String, dynamic> item) {
   final topic = item['topics'] is Map ? item['topics'] : {'topic_name': 'Tópico não especificado'};
   final topicItem = item['topic_items'] is Map ? item['topic_items'] : {'item_name': 'Item não especificado'};
   final detail = item['item_details'] is Map ? item['item_details'] : {'detail_name': 'Detalhe não especificado'};

   final severity = item['severity'] ?? 'Média';
   final status = item['status'] ?? 'pendente';
   
   final isResolved = item['is_resolved'] == true;
   
   // Se resolvido, usar cor verde. Senão, usar cor baseada na severidade
   Color cardColor = isResolved 
       ? const Color(0xFF1B5E20) // Verde escuro para resolvidos
       : switch (severity) {
           'Alta' => const Color(0xFF4A1E1E),
           'Média' => const Color(0xFF4A3B1E),
           'Baixa' => const Color(0xFF1E2A4A),
           _ => const Color(0xFF3A3A3A),
         };

   final (statusColor, statusText) = isResolved 
       ? (Colors.green, 'RESOLVIDO')
       : (Colors.orange, 'PENDENTE');

   DateTime? createdAt;
   try {
     if (item['created_at'] != null) {
       createdAt = item['created_at'] is String 
           ? DateTime.parse(item['created_at'])
           : item['created_at']?.toDate?.call();
     }
   } catch (e) {
     debugPrint('Error parsing date: ${item['created_at']}');
   }

   String nonConformityId = item['id'] ?? '';
   if (!nonConformityId.contains('-')) {
     nonConformityId = '$inspectionId-${item['topic_id']}-${item['item_id']}-${item['detail_id']}-$nonConformityId';
   }

   final parts = nonConformityId.split('-');
   final topicIndex = int.tryParse(parts[1].replaceFirst('topic_', ''));
   final itemIndex = int.tryParse(parts[2].replaceFirst('item_', ''));
   final detailIndex = int.tryParse(parts[3].replaceFirst('detail_', ''));
   final ncIndex = int.tryParse(parts[4].replaceFirst('nc_', ''));

   return Card(
     margin: const EdgeInsets.only(bottom: 4),
     color: cardColor,
     elevation: 1,
     child: Padding(
       padding: const EdgeInsets.all(8),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           // Header compacto
           Row(
             children: [
               _buildStatusChip(statusText, statusColor),
               const SizedBox(width: 4),
               _buildSeverityChip(severity),
               const Spacer(),
               _buildActionButton(Icons.edit, Colors.blue, () => _showEditDialog(context, item)),
               _buildActionButton(Icons.delete, Colors.red, () => _confirmDelete(context, item)),
             ],
           ),
           const SizedBox(height: 6),

           // Localização compacta - mais visível
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
             decoration: BoxDecoration(
               color: Colors.black26,
               borderRadius: BorderRadius.circular(4),
               border: Border.all(color: Colors.white24, width: 0.5),
             ),
             child: Text(
               '${topic['topic_name'] ?? "N/A"} > ${topicItem['item_name'] ?? "N/A"} > ${detail['detail_name'] ?? "N/A"}',
               style: const TextStyle(
                 color: Colors.white,
                 fontSize: 11,
                 fontWeight: FontWeight.w600,
               ),
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
           ),
           const SizedBox(height: 4),

           // Descrição
           Text(item['description'] ?? "Sem descrição",
             style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
             maxLines: 2, overflow: TextOverflow.ellipsis),

           // Ação corretiva se houver
           if (item['corrective_action'] != null) ...[
             const SizedBox(height: 4),
             Text('Ação: ${item['corrective_action']}',
               style: const TextStyle(color: Colors.white60, fontSize: 10),
               maxLines: 1, overflow: TextOverflow.ellipsis),
           ],

           // Imagens de resolução se houver
           if (isResolved && item['resolution_images'] != null && (item['resolution_images'] as List).isNotEmpty) ...[
             const SizedBox(height: 8),
             const Text('Imagens de Resolução:', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
             const SizedBox(height: 4),
             SizedBox(
               height: 40,
               child: ListView.builder(
                 scrollDirection: Axis.horizontal,
                 itemCount: (item['resolution_images'] as List).length,
                 itemBuilder: (context, index) {
                   final imagePath = (item['resolution_images'] as List)[index] as String;
                   return Container(
                     margin: const EdgeInsets.only(right: 6),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(6),
                       child: imagePath.startsWith('http')
                         ? Image.network(
                             imagePath,
                             width: 40,
                             height: 40,
                             fit: BoxFit.cover,
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                                 width: 40,
                                 height: 40,
                                 color: Colors.grey[600],
                                 child: const Icon(Icons.image, color: Colors.white54, size: 20),
                               );
                             },
                           )
                         : Image.file(
                             File(imagePath),
                             width: 40,
                             height: 40,
                             fit: BoxFit.cover,
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                                 width: 40,
                                 height: 40,
                                 color: Colors.grey[600],
                                 child: const Icon(Icons.image, color: Colors.white54, size: 20),
                               );
                             },
                           ),
                     ),
                   );
                 },
               ),
             ),
           ],

           const SizedBox(height: 6),

           // Widget de mídia
           if (topicIndex != null && itemIndex != null && detailIndex != null && ncIndex != null)
             NonConformityMediaWidget(
               inspectionId: inspectionId,
               topicIndex: topicIndex,
               itemIndex: itemIndex,
               detailIndex: detailIndex,
               ncIndex: ncIndex,
               isReadOnly: status == 'resolvido',
               onMediaAdded: (_) {},
               onNonConformityUpdated: onNonConformityUpdated,
             ),

           // Data de criação e botões de ação
           Row(
             children: [
               if (createdAt != null)
                 Text(DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                   style: const TextStyle(color: Colors.white38, fontSize: 9)),
               const Spacer(),
             ],
           ),
         ],
       ),
     ),
   );
 }

 Widget _buildStatusChip(String text, Color color) {
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
     decoration: BoxDecoration(
       color: color.withAlpha(51),
       borderRadius: BorderRadius.circular(3),
       border: Border.all(color: color, width: 0.5),
     ),
     child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
   );
 }

 Widget _buildSeverityChip(String severity) {
   final color = _getSeverityColor(severity);
   return Container(
     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
     decoration: BoxDecoration(
       color: color.withAlpha(51),
       borderRadius: BorderRadius.circular(3),
       border: Border.all(color: color, width: 0.5),
     ),
     child: Text(severity, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
   );
 }

 Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
   return IconButton(
     icon: Icon(icon, size: 14, color: color),
     onPressed: onPressed,
     padding: const EdgeInsets.all(2),
     constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
   );
 }


 void _showEditDialog(BuildContext context, Map<String, dynamic> item) {
   showDialog(
     context: context,
     builder: (dialogContext) => NonConformityEditDialog(
       nonConformity: item,
       onSave: (updatedData) {
         onEditNonConformity(updatedData);
         Navigator.of(dialogContext).pop();
       },
     ),
   );
 }

 void _confirmDelete(BuildContext context, Map<String, dynamic> item) {
   String nonConformityId = item['id'] ?? '';
   if (!nonConformityId.contains('-')) {
     nonConformityId = '$inspectionId-${item['topic_id']}-${item['item_id']}-${item['detail_id']}-$nonConformityId';
   }

   showDialog(
     context: context,
     builder: (dialogContext) => AlertDialog(
       title: const Text('Excluir Não Conformidade'),
       content: const Text('Tem certeza que deseja excluir esta não conformidade?'),
       actions: [
         TextButton(
           onPressed: () => Navigator.of(dialogContext).pop(),
           child: const Text('Cancelar'),
         ),
         TextButton(
           onPressed: () {
             onDeleteNonConformity(nonConformityId);
             Navigator.of(dialogContext).pop();
           },
           style: TextButton.styleFrom(foregroundColor: Colors.red),
           child: const Text('Excluir'),
         ),
       ],
     ),
   );
 }
}