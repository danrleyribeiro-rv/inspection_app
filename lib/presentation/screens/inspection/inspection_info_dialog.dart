import 'package:flutter/material.dart';
import 'package:inspection_app/models/inspection.dart';

class InspectionInfoDialog extends StatelessWidget {
  final Inspection inspection;
  final int totalTopics;
  final int totalItems;
  final int totalDetails;
  final int totalMedia;

  const InspectionInfoDialog({
    super.key,
    required this.inspection,
    required this.totalTopics,
    required this.totalItems,
    required this.totalDetails,
    required this.totalMedia,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Informações da Vistoria', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.7,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Total de Tópicos:', totalTopics.toString()),
            _infoRow('Total de Itens:', totalItems.toString()),
            _infoRow('Total de Detalhes:', totalDetails.toString()),
            _infoRow('Total de Mídias:', totalMedia.toString()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
