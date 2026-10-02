import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_theme.dart';

class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.initialValue = '',
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.debounceDuration = const Duration(milliseconds: 350),
    this.trailing,
    this.leading,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String initialValue;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final Duration debounceDuration;
  final Widget? trailing;
  final Widget? leading;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late TextEditingController _effectiveController;
  Timer? _debounce;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _effectiveController = widget.controller!;
    } else {
      _effectiveController = TextEditingController(text: widget.initialValue);
      _ownsController = true;
    }
    _effectiveController.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      if (widget.controller != null) {
        if (_ownsController) {
          _effectiveController.dispose();
          _ownsController = false;
        }
        _effectiveController = widget.controller!;
      } else {
        _effectiveController = TextEditingController(text: widget.initialValue);
        _ownsController = true;
      }
      _effectiveController.addListener(_onControllerChanged);
    } else if (_ownsController &&
        widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _effectiveController.text.trim()) {
      _effectiveController.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _effectiveController.removeListener(_onControllerChanged);
    if (_ownsController) {
      _effectiveController.dispose();
    }
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration, () => widget.onChanged?.call(value.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? AppColors.slate800 : AppColors.slate100;
    final border = isDark ? AppColors.slate700.withValues(alpha: 0.7) : AppColors.slate200;
    final primary = theme.colorScheme.primary;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: _effectiveController,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onChanged: _changed,
        onSubmitted: (val) {
          _debounce?.cancel();
          widget.onSubmitted?.call(val.trim());
          widget.onChanged?.call(val.trim());
        },
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: isDark ? AppColors.slate100 : AppColors.slate900,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: muted,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: widget.leading ?? Icon(LucideIcons.search, size: 18, color: muted),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_effectiveController.text.isNotEmpty)
                IconButton(
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Hapus pencarian',
                  icon: Icon(LucideIcons.x, size: 16, color: muted),
                  onPressed: () {
                    _effectiveController.clear();
                    _changed('');
                  },
                ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard top header for bottom sheets:
/// Displays centered drag handle, title, optional subtitle, optional actions,
/// and a clean circular close button positioned prominently at the top right.
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onClose,
    this.actions,
    this.showDragHandle = true,
    this.showCloseButton = true,
    this.padding = const EdgeInsets.fromLTRB(20, 10, 16, 12),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onClose;
  final List<Widget>? actions;
  final bool showDragHandle;
  final bool showCloseButton;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showDragHandle) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...?actions,
              if (showCloseButton) ...[
                const SizedBox(width: 8),
                Material(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onClose ?? () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: Icon(
                        LucideIcons.x,
                        size: 18,
                        color: isDark ? AppColors.slate300 : AppColors.slate600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


/// Horizontal single-choice chips; `null` value is the "all" option.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({super.key, required this.options, required this.selected, required this.onSelected});

  final List<(T?, String)> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(label), selected: selected == value, showCheckmark: false, onSelected: (_) => onSelected(value)),
            ),
        ],
      ),
    );
  }
}

/// Centers content and caps its width so tablet layouts don't stretch forms edge to edge.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, this.width = 680, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: width), child: child),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor, this.bold = false});

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
          ?trailing,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.caption, this.icon, this.color, this.onTap});

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = color ?? theme.colorScheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: accent),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 3),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: muted, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet body for small forms: title, keyboard-aware padding, scrollable content.
class FormSheet extends StatelessWidget {
  const FormSheet({super.key, required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  static Future<T?> show<T>(BuildContext context, Widget sheet) =>
      showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => sheet);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BottomSheetHeader(title: title, subtitle: subtitle),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: StatusColors.of(context).danger) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );

  return result ?? false;
}
