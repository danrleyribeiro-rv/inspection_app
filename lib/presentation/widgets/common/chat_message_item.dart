// lib/presentation/widgets/chat_message_item.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inspection_app/models/chat_message.dart';
import 'package:intl/intl.dart';
import 'package:inspection_app/presentation/screens/media/media_preview_screen.dart';

class ChatMessageItem extends StatelessWidget {
  final ChatMessage message;
  final bool isCurrentUser;
  final VoidCallback onLongPress;
  final bool previousIsSameSender;

  const ChatMessageItem({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.onLongPress,
    this.previousIsSameSender = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: EdgeInsets.only(
          left: isCurrentUser ? 40 : 0,
          right: isCurrentUser ? 0 : 40,
          bottom: previousIsSameSender ? 2 : 8,
          top: 2,
        ),
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildMessageContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    // Estilo para o corpo da mensagem
    final messageStyle = BoxDecoration(
      color: isCurrentUser ? Colors.blue.shade700 : Colors.grey.shade800,
      borderRadius: BorderRadius.circular(6),
    );

    // Texto do horário
    final timeText = DateFormat('HH:mm').format(message.timestamp);

    // Indicador de status
    IconData? statusIcon;
    if (message.readBy.isNotEmpty) {
      statusIcon = Icons.done_all;
    } else if (message.receivedBy.isNotEmpty) {
      statusIcon = Icons.done;
    } else {
      statusIcon = Icons.schedule;
    }

    // Construir com base no tipo de mensagem
    switch (message.type) {
      case 'image':
        return Container(
          decoration: messageStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Imagem
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MediaPreviewScreen(
                          mediaUrl: message.fileUrl!,
                          mediaType: 'image',
                        ),
                      ),
                    );
                  },
                  child: Image.network(
                    message.fileUrl!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[700],
                        child: const Center(
                          child: Icon(Icons.error, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Hora e status
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        color:
                            isCurrentUser ? Colors.white70 : Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        statusIcon,
                        size: 12,
                        color:
                            message.readBy.isNotEmpty
                                ? Colors.blue[300]
                                : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

      case 'video':
        return Container(
          decoration: messageStyle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Thumbnail de vídeo com play button
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MediaPreviewScreen(
                          mediaUrl: message.fileUrl!,
                          mediaType: 'video',
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 150,
                        color: Colors.black,
                      ),
                      Icon(
                        Icons.play_circle_fill,
                        size: 50,
                        color: Colors.white.withAlpha((255 * 0.8).round()),
                      ),
                    ],
                  ),
                ),
              ),

              // Hora e status
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        color:
                            isCurrentUser ? Colors.white70 : Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        statusIcon,
                        size: 12,
                        color:
                          message.readBy.isNotEmpty
                              ? Colors.blue[300]
                              : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

      case 'file':
        return Container(
          decoration: messageStyle,
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card de arquivo
              GestureDetector(
                onTap: () {
                  // Implementar visualização/download do arquivo
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getFileIcon(message.fileName ?? ''),
                        color: Colors.white,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.fileName ?? 'Arquivo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              message.getFormattedFileSize(),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.download,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),

              // Hora e status
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeText,
                      style: TextStyle(
                        color:
                            isCurrentUser ? Colors.white70 : Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        statusIcon,
                        size: 12,
                        color:
                            message.readBy.isNotEmpty
                                ? Colors.blue[300]
                                : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );

      case 'text':
      default:
        return Container(
          decoration: messageStyle,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Texto da mensagem
              GestureDetector(
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Texto copiado'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // Hora e status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeText,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white70 : Colors.grey[400],
                      fontSize: 10,
                    ),
                  ),
                  if (isCurrentUser) ...[
                    const SizedBox(width: 4),
                    Icon(
                      statusIcon,
                      size: 12,
                      color:
                          message.readBy.isNotEmpty
                              ? Colors.blue[300]
                              : Colors.white70,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }
}
