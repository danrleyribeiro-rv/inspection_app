import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:lince_inspecoes/services/simple_notification_service.dart';
import 'package:lince_inspecoes/utils/platform_utils.dart';

class NotificationPermissionDialog extends StatelessWidget {
  const NotificationPermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoAlertDialog(
        title: const Text('Permitir notificações'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 12),
            Text(
              'Para manter você informado sobre o progresso das sincronizações, precisamos da permissão para enviar notificações.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 12),
            Text(
              'Você receberá notificações quando:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            SizedBox(height: 8),
            Text('• Baixar inspeções', style: TextStyle(fontSize: 12)),
            Text('• Sincronizar dados', style: TextStyle(fontSize: 12)),
            Text('• Operações concluídas', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () {
              Navigator.of(context).pop(false);
            },
            child: const Text('Agora não'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () async {
              final granted = await SimpleNotificationService.instance.initialize();
              if (context.mounted) {
                Navigator.of(context).pop(granted);
              }
            },
            child: const Text('Permitir'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.notifications_active,
            color: Color(0xFF6F4B99),
            size: 28,
          ),
          SizedBox(width: 12),
          Text(
            'Permitir notificações',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D1B3D),
            ),
          ),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Para manter você informado sobre o progresso das sincronizações, precisamos da permissão para enviar notificações.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF666666),
              height: 1.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Você receberá notificações quando:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D1B3D),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.cloud_download,
                color: Color(0xFF6F4B99),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Baixar inspeções',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.sync,
                color: Color(0xFF6F4B99),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Sincronizar dados',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Color(0xFF6F4B99),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'Operações concluídas',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF666666),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text(
            'Agora não',
            style: TextStyle(
              color: Color(0xFF999999),
              fontSize: 14,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            final granted = await SimpleNotificationService.instance.initialize();
            if (context.mounted) {
              Navigator.of(context).pop(granted);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6F4B99),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Permitir',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  static Future<bool> show(BuildContext context) async {
    if (PlatformUtils.isIOS) {
      final result = await showCupertinoDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const NotificationPermissionDialog(),
      );
      return result ?? false;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const NotificationPermissionDialog(),
    );
    return result ?? false;
  }
}