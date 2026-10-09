import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_pos_mobile/core/constants/app_icons.dart';
import 'package:web_pos_mobile/core/constants/app_strings.dart';

import '../theme/app_theme.dart';
import 'package:web_pos_mobile/core/theme/app_spacing.dart';
import 'package:web_pos_mobile/core/theme/app_radius.dart';
import 'package:web_pos_mobile/core/theme/app_sizes.dart';
import 'package:web_pos_mobile/core/theme/app_durations.dart';

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
    this.dense = false,
    this.debounceDuration = AppDurations.milliseconds350,
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
  final bool dense;
  final Duration debounceDuration;
  final Widget? trailing;
  final Widget? leading;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late TextEditingController _effectiveController;
  late FocusNode _effectiveFocusNode;
  Timer? _debounce;
  bool _ownsController = false;
  bool _ownsFocusNode = false;

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

    if (widget.focusNode != null) {
      _effectiveFocusNode = widget.focusNode!;
    } else {
      _effectiveFocusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _effectiveFocusNode.addListener(_onFocusChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
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

    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      if (widget.focusNode != null) {
        if (_ownsFocusNode) {
          _effectiveFocusNode.dispose();
          _ownsFocusNode = false;
        }
        _effectiveFocusNode = widget.focusNode!;
      } else {
        _effectiveFocusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _effectiveFocusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _effectiveController.removeListener(_onControllerChanged);
    if (_ownsController) {
      _effectiveController.dispose();
    }
    _effectiveFocusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) {
      _effectiveFocusNode.dispose();
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
    final isFocused = _effectiveFocusNode.hasFocus;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(widget.dense ? 10 : 12),
        border: Border.all(
          color: isFocused ? primary : border,
          width: isFocused ? 1.4 : 1.0,
        ),
      ),
      child: TextField(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        autofocus: widget.autofocus,
        textAlignVertical: TextAlignVertical.center,
        onChanged: _changed,
        onSubmitted: (val) {
          _debounce?.cancel();
          widget.onSubmitted?.call(val.trim());
          widget.onChanged?.call(val.trim());
        },
        onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: widget.dense ? 13.5 : 14,
          fontWeight: FontWeight.w400,
          color: isDark ? AppColors.slate100 : AppColors.slate900,
        ),
        decoration: InputDecoration(
          isDense: true,
          hintText: widget.hint,
          hintStyle: TextStyle(
            fontSize: widget.dense ? 13.5 : 14,
            fontWeight: FontWeight.w400,
            color: muted,
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s10,
            vertical: widget.dense ? AppSpacing.s9 : AppSpacing.s11,
          ),
          prefixIcon: widget.leading ??
              Icon(
                AppIcons.search,
                size: widget.dense ? 16 : 18,
                color: isFocused ? primary : muted,
              ),
          prefixIconConstraints: BoxConstraints(
            minWidth: widget.dense ? 36 : 40,
            minHeight: widget.dense ? 36 : 40,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_effectiveController.text.isNotEmpty)
                IconButton(
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                  tooltip: CoreStrings.tooltipClearSearch,
                  icon: Icon(AppIcons.x, size: AppSizes.s16, color: muted),
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

/// Standard AppBar with integrated collapsible search mode.
///
/// Features:
/// - By default displays clean [title] and action icons, including a search icon button.
/// - Clicking the search icon smoothly activates search mode with an autofocus [SearchField].
/// - When searching, tapping the back arrow or clearing closes search mode.
/// - If [initialSearch] is already provided, automatically starts in search mode.
class SearchableAppBar extends StatefulWidget implements PreferredSizeWidget {
  const SearchableAppBar({
    super.key,
    required this.title,
    required this.hint,
    required this.onSearchChanged,
    this.onSearchSubmitted,
    this.initialSearch = '',
    this.actions = const [],
    this.onSearchClosed,
    this.leading,
    this.bottom,
    this.titleSpacing,
    this.centerTitle,
  });

  final Widget title;
  final String hint;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final String initialSearch;
  final List<Widget> actions;
  final VoidCallback? onSearchClosed;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final double? titleSpacing;
  final bool? centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  State<SearchableAppBar> createState() => _SearchableAppBarState();
}

class _SearchableAppBarState extends State<SearchableAppBar> {
  late bool _isSearching;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _isSearching = widget.initialSearch.isNotEmpty;
    _controller = TextEditingController(text: widget.initialSearch);
  }

  @override
  void didUpdateWidget(SearchableAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearch != oldWidget.initialSearch) {
      if (widget.initialSearch != _controller.text) {
        _controller.text = widget.initialSearch;
      }
      if (widget.initialSearch.isNotEmpty && !_isSearching) {
        setState(() => _isSearching = true);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _controller.clear();
    widget.onSearchChanged('');
    widget.onSearchClosed?.call();
    setState(() => _isSearching = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isSearching) {
      return AppBar(
        titleSpacing: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(AppIcons.arrowLeft, size: AppSizes.s20),
          tooltip: CoreStrings.tooltipBack,
          onPressed: _closeSearch,
        ),
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s16),
          child: SearchField(
            controller: _controller,
            hint: widget.hint,
            dense: true,
            autofocus: true,
            onChanged: widget.onSearchChanged,
            onSubmitted: widget.onSearchSubmitted,
          ),
        ),
        bottom: widget.bottom,
      );
    }

    return AppBar(
      titleSpacing: widget.titleSpacing,
      centerTitle: widget.centerTitle,
      leading: widget.leading,
      title: widget.title,
      actions: [
        IconButton(
          icon: const Icon(AppIcons.search, size: AppSizes.s20),
          tooltip: CoreStrings.tooltipSearch,
          onPressed: () => setState(() => _isSearching = true),
        ),
        ...widget.actions,
      ],
      bottom: widget.bottom,
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
    this.padding = const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s10, AppSpacing.s16, AppSpacing.s12),
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
          const SizedBox(height: AppSizes.s8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate700 : AppColors.slate300,
                borderRadius: BorderRadius.circular(AppRadius.r2),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.s6),
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
                      const SizedBox(height: AppSizes.s2),
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
                const SizedBox(width: AppSizes.s8),
                Material(
                  color: isDark ? AppColors.slate800 : AppColors.slate100,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onClose ?? () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s7),
                      child: Icon(
                        AppIcons.x,
                        size: AppSizes.s18,
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        children: [
          for (final (value, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s6),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          const SizedBox(width: AppSizes.s12),
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
      padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s16, AppSpacing.s4, AppSpacing.s8),
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
          padding: const EdgeInsets.all(AppSpacing.s14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s6),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r8),
                      ),
                      child: Icon(icon, size: AppSizes.s16, color: accent),
                    ),
                    const SizedBox(width: AppSizes.s8),
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
              const SizedBox(height: AppSizes.s10),
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
                const SizedBox(height: AppSizes.s3),
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
                  padding: const EdgeInsets.fromLTRB(AppSpacing.s20, AppSpacing.s4, AppSpacing.s20, AppSpacing.s20),
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
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(CoreStrings.actionCancel)),
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

/// Standard application SwitchListTile adhering to the theme design system.
///
/// Ensures consistent thumb and track styling across light and dark modes,
/// without ad-hoc color overrides that break knob contrast.
class AppSwitchListTile extends StatelessWidget {
  const AppSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding = EdgeInsets.zero,
    this.dense,
    this.shape,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry contentPadding;
  final bool? dense;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      contentPadding: contentPadding,
      dense: dense,
      shape: shape,
    );
  }
}

class AppFloatingActionButton extends StatelessWidget {
  const AppFloatingActionButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.heroTag,
  });

  factory AppFloatingActionButton.extended({
    Key? key,
    required VoidCallback? onPressed,
    required Widget icon,
    required Widget label,
    String? tooltip,
    Object? heroTag,
  }) =>
      AppFloatingActionButton(
        key: key,
        onPressed: onPressed,
        icon: icon,
        label: label,
        tooltip: tooltip,
        heroTag: heroTag,
      );

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget? label;
  final String? tooltip;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    void handleTap() {
      unawaited(HapticFeedback.lightImpact());
      onPressed?.call();
    }

    if (label == null) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: isDark ? 0.35 : 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          heroTag: heroTag,
          tooltip: tooltip,
          elevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          onPressed: onPressed == null ? null : handleTap,
          child: icon,
        ),
      );
    }

    final button = Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.38 : 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          if (isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: primary,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed == null ? null : handleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconTheme.merge(
                  data: const IconThemeData(size: AppSizes.s18, color: Colors.white),
                  child: icon,
                ),
                const SizedBox(width: AppSizes.s8),
                DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  child: label!,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }
}
