// lib/presentation/widgets/avatar_widget.dart
import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  
  const AvatarWidget({
    Key? key,
    this.imageUrl,
    required this.name,
    this.size = 40,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Extrair iniciais do nome
    final nameParts = name.split(' ');
    String initials = '';
    
    if (nameParts.isNotEmpty && nameParts[0].isNotEmpty) {
      initials += nameParts[0][0];
    }
    
    if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
      initials += nameParts[1][0];
    }
    
    initials = initials.toUpperCase();
    
    // Definir avatar
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.grey[800],
        backgroundImage: NetworkImage(imageUrl!),
        onBackgroundImageError: (exception, stackTrace) {
          // Fallback para iniciais em caso de erro ao carregar a imagem
          return;
        },
      );
    } else {
      // Avatar com iniciais
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: _getAvatarColor(name),
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      );
    }
  }
  
  // Gerar uma cor consistente com base no nome
  Color _getAvatarColor(String name) {
    final List<Color> colors = [
      Colors.red[400]!,
      Colors.green[400]!,
      Colors.blue[400]!,
      Colors.orange[400]!,
      Colors.purple[400]!,
      Colors.teal[400]!,
      Colors.pink[400]!,
      Colors.indigo[400]!,
    ];
    
    // Hash simples do nome para selecionar uma cor
    int hash = 0;
    for (var i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    return colors[hash.abs() % colors.length];
  }
}