// lib/presentation/widgets/measure_input_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MeasureInputWidget extends StatelessWidget {
  final double? startMeasure;
  final double? endMeasure;
  final Function(double?, double?) onChanged;

  const MeasureInputWidget({
    super.key,
    this.startMeasure,
    this.endMeasure,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            decoration: const InputDecoration(labelText: 'Início (m)'),
            initialValue: startMeasure?.toString(),
            onChanged: (value) {
              onChanged(double.tryParse(value), endMeasure);
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            decoration: const InputDecoration(labelText: 'Fim (m)'),
            initialValue: endMeasure?.toString(),
            onChanged: (value) {
              onChanged(startMeasure, double.tryParse(value));
            },
          ),
        ),
      ],
    );
  }
}