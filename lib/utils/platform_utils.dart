import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Utilitário para verificar se está rodando no iOS
class PlatformUtils {
  static bool get isIOS => Platform.isIOS;
  static bool get isAndroid => Platform.isAndroid;
}

/// Widget adaptativo que mostra CircularProgressIndicator no Android
/// e CupertinoActivityIndicator no iOS
class AdaptiveProgressIndicator extends StatelessWidget {
  final double? value;
  final Color? color;
  final double radius;

  const AdaptiveProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.radius = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoActivityIndicator(
        radius: radius,
        color: color,
      );
    }
    return CircularProgressIndicator(
      value: value,
      color: color,
    );
  }
}

/// Mostra um dialog adaptativo baseado na plataforma
Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required String title,
  required String content,
  String? confirmText,
  String? cancelText,
  VoidCallback? onConfirm,
  VoidCallback? onCancel,
  bool barrierDismissible = true,
}) {
  if (PlatformUtils.isIOS) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            if (cancelText != null)
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.of(context).pop();
                  onCancel?.call();
                },
                child: Text(cancelText),
              ),
            if (confirmText != null)
              CupertinoDialogAction(
                isDestructiveAction: false,
                onPressed: () {
                  Navigator.of(context).pop();
                  onConfirm?.call();
                },
                child: Text(confirmText),
              ),
          ],
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          if (cancelText != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onCancel?.call();
              },
              child: Text(cancelText),
            ),
          if (confirmText != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onConfirm?.call();
              },
              child: Text(confirmText),
            ),
        ],
      );
    },
  );
}

/// Widget para criar botões adaptativos
class AdaptiveButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.color,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoButton(
        onPressed: onPressed,
        color: color,
        padding: padding,
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: color != null
          ? ElevatedButton.styleFrom(backgroundColor: color)
          : null,
      child: child,
    );
  }
}

/// Widget de Switch adaptativo
class AdaptiveSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: activeColor,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      activeTrackColor: activeColor,
    );
  }
}

/// Widget de TextField adaptativo
class AdaptiveTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? placeholder;
  final String? labelText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final String? Function(String?)? validator;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final VoidCallback? onTap;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.labelText,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.onTap,
    this.onChanged,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labelText != null) ...[
            Text(
              labelText!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder ?? labelText,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            enabled: enabled,
            onTap: onTap,
            onChanged: onChanged,
            textInputAction: textInputAction,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: enabled
                  ? CupertinoColors.tertiarySystemFill
                  : CupertinoColors.quaternarySystemFill,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: CupertinoColors.systemGrey4,
              ),
            ),
            prefix: prefixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: prefixIcon,
                  )
                : null,
            suffix: suffixIcon != null
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: suffixIcon,
                  )
                : null,
          ),
        ],
      );
    }

    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: placeholder,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        border: const OutlineInputBorder(),
      ),
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      enabled: enabled,
      onTap: onTap,
      onChanged: onChanged,
      textInputAction: textInputAction,
    );
  }
}

/// Widget de Slider adaptativo
class AdaptiveSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final Color? activeColor;

  const AdaptiveSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return CupertinoSlider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        activeColor: activeColor,
      );
    }
    return Slider(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      activeColor: activeColor,
    );
  }
}

/// Widget de Dropdown adaptativo que usa CupertinoPicker no iOS
class AdaptiveDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final InputDecoration? decoration;
  final TextStyle? style;
  final bool isExpanded;
  final Color? dropdownColor;

  const AdaptiveDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.hint,
    this.decoration,
    this.style,
    this.isExpanded = false,
    this.dropdownColor,
  });

  void _showCupertinoPicker(BuildContext context) {
    final currentIndex = value != null ? items.indexOf(value as T) : 0;
    int selectedIndex = currentIndex >= 0 ? currentIndex : 0;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoButton(
                    child: const Text('Confirmar'),
                    onPressed: () {
                      onChanged(items[selectedIndex]);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: FixedExtentScrollController(
                    initialItem: selectedIndex,
                  ),
                  itemExtent: 40,
                  onSelectedItemChanged: (index) {
                    selectedIndex = index;
                  },
                  children: items.map((item) {
                    return Center(
                      child: Text(
                        itemLabel(item),
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isIOS) {
      return GestureDetector(
        onTap: () => _showCupertinoPicker(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.tertiarySystemFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: CupertinoColors.systemGrey4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  value != null ? itemLabel(value as T) : (hint ?? ''),
                  style: style ??
                      TextStyle(
                        fontSize: 16,
                        color: value != null
                            ? CupertinoColors.label.resolveFrom(context)
                            : CupertinoColors.systemGrey,
                      ),
                ),
              ),
              const Icon(
                CupertinoIcons.chevron_down,
                size: 20,
                color: CupertinoColors.systemGrey,
              ),
            ],
          ),
        ),
      );
    }

    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration:
          decoration ?? const InputDecoration(border: OutlineInputBorder()),
      style: style,
      isExpanded: isExpanded,
      dropdownColor: dropdownColor,
      items: items.map((item) {
        return DropdownMenuItem<T>(
          value: item,
          child: Text(itemLabel(item)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
