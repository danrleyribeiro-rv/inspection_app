// lib/presentation/screens/inspection/components/swipeable_level_header.dart
import 'package:flutter/material.dart';

class SwipeableLevelHeader extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int currentIndex;
  final int totalCount;
  final double progress;
  final List<String> items;
  final Function(int) onIndexChanged;
  final VoidCallback onExpansionChanged;
  final bool isExpanded;
  final int level;
  final IconData icon;
  final bool hasObservation;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final Function(int oldIndex, int newIndex)? onReorder;
  final List<double>? itemProgresses;

  const SwipeableLevelHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.currentIndex,
    required this.totalCount,
    required this.progress,
    required this.items,
    required this.onIndexChanged,
    required this.onExpansionChanged,
    required this.isExpanded,
    required this.level,
    required this.icon,
    this.hasObservation = false,
    this.onRename,
    this.onDuplicate,
    this.onDelete,
    this.onReorder,
    this.itemProgresses,
  });

  @override
  State<SwipeableLevelHeader> createState() => _SwipeableLevelHeaderState();
}

class _SwipeableLevelHeaderState extends State<SwipeableLevelHeader> {
  Color get _levelColor {
    switch (widget.level) {
      case 1:
        return Color(0xFFBB8FEB);
      case 2:
        return Colors.orange;
      case 3:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color get _backgroundColor {
    return _levelColor.withAlpha((255 * 0.1).round());
  }

  void _showDropdownMenu(BuildContext context) {
    if (widget.items.isEmpty) return;

    List<String> localItems = List<String>.from(widget.items);
    int localCurrentIndex = widget.currentIndex;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      elevation: 10,
      useSafeArea: false,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _levelColor,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Selecionar ${_getLevelName()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    itemCount: localItems.length,
                    itemBuilder: (context, index) {
                      final itemTitle = localItems[index];
                      final isSelected = index == localCurrentIndex;

                      final itemProgress = (widget.itemProgresses != null && 
                                           index < widget.itemProgresses!.length) 
                                         ? widget.itemProgresses![index] 
                                         : 0.0;
                      
                      return ListTile(
                        key: Key(itemTitle),
                        leading: Icon(
                          widget.icon,
                          color: isSelected ? _levelColor : null,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    itemTitle,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected ? _levelColor : null,
                                      fontSize: 12,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.itemProgresses != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(itemProgress * 100).round()}%',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? _levelColor : Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (widget.itemProgresses != null) ...[
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: itemProgress,
                                backgroundColor: Colors.grey.shade700,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isSelected ? _levelColor : _levelColor.withValues(alpha: 0.7),
                                ),
                                minHeight: 3,
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              Icon(Icons.check, color: _levelColor),
                            if (widget.onReorder != null) ...[
                              const SizedBox(width: 16),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  Icons.drag_handle,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ]
                          ],
                        ),
                        onTap: () {
                          widget.onIndexChanged(index);
                          Navigator.pop(context);
                        },
                      );
                    },
                    onReorder: (int oldIndex, int newIndex) {
                      widget.onReorder?.call(oldIndex, newIndex);
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final String item = localItems.removeAt(oldIndex);
                        localItems.insert(newIndex, item);

                        if (localCurrentIndex == oldIndex) {
                          localCurrentIndex = newIndex;
                        } else if (localCurrentIndex > oldIndex &&
                            localCurrentIndex <= newIndex) {
                          localCurrentIndex--;
                        } else if (localCurrentIndex < oldIndex &&
                            localCurrentIndex >= newIndex) {
                          localCurrentIndex++;
                        }
                      });
                    },
                  ),
                ),
                SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getLevelName() {
    switch (widget.level) {
      case 1:
        return 'Tópico';
      case 2:
        return 'Item';
      case 3:
        return 'Detalhe';
      default:
        return 'Item';
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    double size = 24,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            decoration: BoxDecoration(
              color: color.withAlpha((255 * 0.1).round()),
              shape: BoxShape.circle,
              border: Border.all(color: color.withAlpha((255 * 0.3).round())),
            ),
            child: Icon(icon, color: color, size: size * 0.6),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _levelColor.withAlpha((255 * 0.3).round())),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            InkWell(
              onTap: widget.onExpansionChanged,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chevron_left, color: _levelColor),
                      onPressed: widget.currentIndex > 0
                          ? () =>
                              widget.onIndexChanged(widget.currentIndex - 1)
                          : null,
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 8),
                    // REMOVIDO: O ProgressCircle foi removido daqui.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(widget.icon,
                                  color: _levelColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _showDropdownMenu(context),
                                  child: Row(
                                    children: [
                                      // MODIFICADO: Adicionado Flexible e Row para título + percentual
                                      Flexible(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.baseline,
                                          textBaseline:
                                              TextBaseline.alphabetic,
                                          children: [
                                            Flexible(
                                              child: Text(
                                                widget.title,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: _levelColor,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (widget.hasObservation) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.note_alt,
                                                color: Colors.amber,
                                                size: 14,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_drop_down,
                                          color: _levelColor, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                              if (widget.level == 3) ...[
                                const SizedBox(width: 8),
                                _buildActionButton(
                                  icon: Icons.edit,
                                  onPressed: widget.onRename,
                                  color: Color(0xFF6F4B99),
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                _buildActionButton(
                                  icon: Icons.copy,
                                  onPressed: widget.onDuplicate,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                _buildActionButton(
                                  icon: Icons.delete,
                                  onPressed: widget.onDelete,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ],
                            ],
                          ),
                          if (widget.subtitle != null &&
                              widget.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                fontSize: 12,
                                color: _levelColor
                                    .withAlpha((255 * 0.7).round()),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 2),
                          Text(
                            '${widget.currentIndex + 1} de ${widget.totalCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: _levelColor
                                  .withAlpha((255 * 0.6).round()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.chevron_right, color: _levelColor),
                      onPressed: widget.currentIndex < widget.totalCount - 1
                          ? () =>
                              widget.onIndexChanged(widget.currentIndex + 1)
                          : null,
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      widget.isExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: _levelColor,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            if (widget.totalCount > 1)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.totalCount > 10 ? 10 : widget.totalCount,
                    (index) {
                      if (widget.totalCount > 10 && index == 9) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            '...',
                            style: TextStyle(
                              color:
                                  _levelColor.withAlpha((255 * 0.5).round()),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      final dotIndex =
                          widget.totalCount > 10 && widget.currentIndex >= 9
                              ? widget.currentIndex - 9 + index
                              : index;

                      if (dotIndex >= widget.totalCount) {
                        return const SizedBox.shrink();
                      }

                      final isActive = dotIndex == widget.currentIndex;

                      return GestureDetector(
                        onTap: () => widget.onIndexChanged(dotIndex),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: isActive ? 8 : 6,
                          height: isActive ? 8 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? _levelColor
                                : _levelColor.withAlpha((255 * 0.3).round()),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}