// lib/presentation/screens/inspection/components/loading_state.dart
import 'package:flutter/material.dart';

class LoadingState extends StatelessWidget {
  final bool isDownloading;

  const LoadingState({
    Key? key,
    this.isDownloading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            isDownloading 
                ? 'Downloading inspection data...' 
                : 'Loading...',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}