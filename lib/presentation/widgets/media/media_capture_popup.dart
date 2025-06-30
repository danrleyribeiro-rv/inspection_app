// lib/presentation/widgets/media/media_capture_popup.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MediaCapturePopup extends StatelessWidget {
 final Function(ImageSource, String) onMediaSelected;

 const MediaCapturePopup({
   super.key,
   required this.onMediaSelected,
 });

 @override
 Widget build(BuildContext context) {
   return Container(
     padding: const EdgeInsets.all(16),
     decoration: const BoxDecoration(
       color: Color.fromARGB(255, 40, 47, 87),
       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
     ),
     child: Column(
       mainAxisSize: MainAxisSize.min,
       children: [
         // Handle bar
         Container(
           width: 40,
           height: 4,
           decoration: BoxDecoration(
             color: const Color.fromARGB(255, 24, 6, 128),
             borderRadius: BorderRadius.circular(2),
           ),
         ),
         const SizedBox(height: 20),

         // Title
         const Text(
           'Capturar Mídia',
           style: TextStyle(
             fontSize: 8,
             fontWeight: FontWeight.bold,
             color: Color.fromARGB(221, 255, 255, 255),
           ),
         ),
         const SizedBox(height: 20),

         // Options
         Row(
           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
           children: [
             _buildOption(
               context: context,
               icon: Icons.camera_alt,
               label: 'Foto',
               color: Colors.blue,
               onTap: () {
                 Navigator.of(context).pop();
                 onMediaSelected(ImageSource.camera, 'image');
               },
             ),
             _buildOption(
               context: context,
               icon: Icons.videocam,
               label: 'Vídeo',
               color: Colors.purple,
               onTap: () {
                 Navigator.of(context).pop();
                 onMediaSelected(ImageSource.camera, 'video');
               },
             ),
             _buildOption(
               context: context,
               icon: Icons.photo_library,
               label: 'Galeria',
               color: Colors.green,
               onTap: () {
                 Navigator.of(context).pop();
                 onMediaSelected(ImageSource.gallery, 'image');
               },
             ),
           ],
         ),
         const SizedBox(height: 20),
       ],
     ),
   );
 }

 Widget _buildOption({
   required BuildContext context,
   required IconData icon,
   required String label,
   required Color color,
   required VoidCallback onTap,
 }) {
   return InkWell(
     onTap: onTap,
     borderRadius: BorderRadius.circular(12),
     child: Container(
       width: 80,
       padding: const EdgeInsets.symmetric(vertical: 16),
       decoration: BoxDecoration(
         color: color.withAlpha((255 * 0.1).round()),
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: color.withAlpha((255 * 0.3).round())),
       ),
       child: Column(
         children: [
           Icon(
             icon,
             size: 32,
             color: color,
           ),
           const SizedBox(height: 8),
           Text(
             label,
             style: TextStyle(
               color: color,
               fontWeight: FontWeight.w600,
               fontSize: 8,
             ),
           ),
         ],
       ),
     ),
   );
 }
}