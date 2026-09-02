import 'package:flutter/material.dart';

class PremiumSelect extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String label;
  final String hint;
  final IconData? icon;
  final ValueChanged<String> onChanged;
  final bool isGujarati;
  final String Function(String)? itemLabelBuilder;

  const PremiumSelect({
    super.key,
    this.value,
    required this.items,
    required this.label,
    required this.hint,
    this.icon,
    required this.onChanged,
    required this.isGujarati,
    this.itemLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayValue = value != null ? (itemLabelBuilder?.call(value!) ?? value!) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
        InkWell(
          onTap: () => _showPicker(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withAlpha(50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant.withAlpha(80)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: cs.primary),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    displayValue ?? hint,
                    style: TextStyle(
                      fontSize: 16,
                      color: displayValue == null ? cs.outline : cs.onSurface,
                      fontWeight: displayValue == null ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: cs.outline),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPicker(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                hint,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final isSelected = value == item;
                    final itemLabel = itemLabelBuilder?.call(item) ?? item;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        onTap: () {
                          onChanged(item);
                          Navigator.pop(ctx);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        tileColor: isSelected ? cs.primaryContainer.withAlpha(100) : null,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primary : cs.surfaceContainerHighest.withAlpha(100),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isSelected ? Icons.check_rounded : _getIconForItem(item),
                            size: 20,
                            color: isSelected ? cs.onPrimary : cs.primary,
                          ),
                        ),
                        title: Text(
                          itemLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
                        ),
                        trailing: Radio<String>(
                          value: item,
                          groupValue: value,
                          activeColor: cs.primary,
                          onChanged: (v) {
                            if (v != null) {
                              onChanged(v);
                              Navigator.pop(ctx);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconForItem(String item) {
    final lower = item.toLowerCase();
    if (lower.contains('bataka') || lower.contains('બટાકા')) return Icons.circle;
    if (lower.contains('magfali') || lower.contains('મગફળી')) return Icons.eco_rounded;
    if (lower.contains('bajari') || lower.contains('બાજરી') || lower.contains('wheat') || lower.contains('ઘઉ')) return Icons.grass_rounded;
    if (lower.contains('upaad') || lower.contains('ઉપાડ')) return Icons.upload_rounded;
    if (lower.contains('download') || lower.contains('income')) return Icons.download_rounded;
    if (lower.contains('tractor') || lower.contains('ટ્રેક્ટર')) return Icons.agriculture_rounded;
    return Icons.label_outline_rounded;
  }
}
