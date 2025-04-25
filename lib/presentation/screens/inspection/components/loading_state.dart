// lib/presentation/screens/inspection/components/loading_state.dart
import 'package:flutter/material.dart';

class LoadingState extends StatelessWidget {
  final bool isDownloading;
  final bool isApplyingTemplate;

  const LoadingState({
    super.key,
    this.isDownloading = false,
    this.isApplyingTemplate = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: isApplyingTemplate 
                ? Colors.orange 
                : Theme.of(context).primaryColor,
            strokeWidth: 3,
          ),
          const SizedBox(height: 24),
          Text(
            isApplyingTemplate 
                ? 'Aplicando template à inspeção...'
                : isDownloading 
                    ? 'Baixando dados da inspeção...' 
                    : 'Carregando...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold
            ),
          ),
          if (isApplyingTemplate) ...[
            const SizedBox(height: 12),
            const Text(
              'Por favor, aguarde. Isso pode levar alguns instantes...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Criando estrutura da inspeção',
                    style: TextStyle(color: Colors.orange),
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