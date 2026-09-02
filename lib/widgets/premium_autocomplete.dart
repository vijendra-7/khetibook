import 'package:flutter/material.dart';

class PremiumAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<String> options;
  final String label;
  final String hint;
  final IconData? icon;
  final bool isGujarati;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSelected;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;

  const PremiumAutocomplete({
    super.key,
    required this.controller,
    this.focusNode,
    required this.options,
    required this.label,
    required this.hint,
    this.icon,
    required this.isGujarati,
    this.validator,
    this.onSelected,
    this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return options.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: onSelected,
          fieldViewBuilder: (context, fieldController, fieldFocusNode, onFieldSubmitted) {
            // Sync controllers if needed, but usually Autocomplete uses fieldController
            if (controller.text.isNotEmpty && fieldController.text.isEmpty) {
              fieldController.text = controller.text;
            }
            fieldController.addListener(() {
              controller.text = fieldController.text;
            });

            return TapRegion(
              groupId: controller,
              onTapOutside: (event) => fieldFocusNode.unfocus(),
              child: TextFormField(
                controller: fieldController,
                focusNode: fieldFocusNode,
                validator: validator,
                decoration: InputDecoration(
                  hintText: hint,
                  prefixIcon: icon != null ? Icon(icon, size: 20, color: cs.primary) : null,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (suffix != null) suffix!,
                      IconButton(
                        icon: Icon(Icons.expand_more_rounded, color: cs.outline),
                        onPressed: () => _showPicker(context, fieldController),
                      ),
                    ],
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withAlpha(50),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.outlineVariant.withAlpha(80)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: cs.primary, width: 2),
                  ),
                ),
                onFieldSubmitted: (value) {
                  onFieldSubmitted();
                },
                onChanged: onChanged,
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return TapRegion(
              groupId: controller,
              child: Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: MediaQuery.of(context).size.width - 40,
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        return ListTile(
                          title: Text(option),
                          onTap: () => onSelected(option),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showPicker(BuildContext context, TextEditingController fieldController) {
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
                label,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final item = options[index];
                    final isSelected = controller.text == item;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ListTile(
                        onTap: () {
                          fieldController.text = item;
                          controller.text = item;
                          onSelected?.call(item);
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
                            isSelected ? Icons.check_rounded : Icons.person_outline_rounded,
                            size: 20,
                            color: isSelected ? cs.onPrimary : cs.primary,
                          ),
                        ),
                        title: Text(
                          item,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? cs.primary : cs.onSurface,
                          ),
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
}
