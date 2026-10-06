import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/constants/app_roles.dart';
import '../core/layout/responsive.dart';
import '../core/utils/profile_image_storage.dart';

class BusGoBrandMark extends StatelessWidget {
  const BusGoBrandMark({super.key, this.compact = false, this.light = false});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 11 : 14),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Icon(
            Icons.directions_bus_filled_rounded,
            color: colorScheme.onPrimary,
            size: compact ? 19 : 24,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'BUSGO',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: light ? Colors.white : null,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class BusGoAuthShell extends StatelessWidget {
  const BusGoAuthShell({
    super.key,
    required this.child,
    this.showBack = false,
    this.premium = false,
  });

  final Widget child;
  final bool showBack;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    if (!premium) return _buildLegacyShell(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?auto=format&fit=crop&w=1800&q=85',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF87B9C7), Color(0xFF123B57)],
                ),
              ),
            ),
          ),
          Container(color: const Color(0xFF061B2D).withValues(alpha: 0.48)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            showBack ? 10 : 26,
                            22,
                            26,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.8),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).colorScheme.shadow.withValues(alpha: 0.35),
                                blurRadius: 30,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showBack)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    onPressed: () =>
                                        Navigator.of(context).maybePop(),
                                    icon: const Icon(Icons.arrow_back_rounded),
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              child,
                            ],
                          ),
                        ),
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
  }

  Widget _buildLegacyShell(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF12B8AC), Color(0xFF087F83)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0C7A7B).withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showBack)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 4),
                        SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          child: child,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BusGoSurface extends StatelessWidget {
  const BusGoSurface({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }
}

class BusGoPrimaryButton extends StatelessWidget {
  const BusGoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? const SizedBox(
            width: 19,
            height: 19,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Text(label);
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? FilledButton(onPressed: loading ? null : onPressed, child: child)
          : FilledButton.icon(
              onPressed: loading ? null : onPressed,
              icon: loading ? const SizedBox.shrink() : Icon(icon),
              label: child,
            ),
    );
  }
}

class BusGoSecondaryButton extends StatelessWidget {
  const BusGoSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: icon == null
          ? OutlinedButton(onPressed: onPressed, child: Text(label))
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class BusGoIconButton extends StatelessWidget {
  const BusGoIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest,
              foregroundColor: colorScheme.onSurface,
            )
          : null,
      icon: Icon(icon, color: filled ? colorScheme.onSurface : null),
    );
  }
}

class BusGoSectionHeader extends StatelessWidget {
  const BusGoSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class BusGoEmptyState extends StatelessWidget {
  const BusGoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BusGoSurface(
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: colorScheme.primary, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class BusGoLoadingState extends StatelessWidget {
  const BusGoLoadingState({super.key, this.label = 'Loading BUSGO data...'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return BusGoSurface(
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 14),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class BusGoErrorState extends StatelessWidget {
  const BusGoErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Please check your connection and try again.',
    this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return BusGoEmptyState(
      icon: Icons.cloud_off_rounded,
      title: title,
      message: message,
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }
}

class BusGoBottomBar extends StatelessWidget {
  const BusGoBottomBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<NavigationDestination> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      destinations: items,
    );
  }
}

class BusGoAdaptiveScaffold extends StatelessWidget {
  const BusGoAdaptiveScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  final Widget body;
  final int selectedIndex;
  final List<NavigationDestination> items;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (BusGoBreakpoints.isCompact(constraints.maxWidth)) {
          return Scaffold(
            body: SafeArea(child: body),
            bottomNavigationBar: BusGoBottomBar(
              selectedIndex: selectedIndex,
              items: items,
              onSelected: onSelected,
            ),
          );
        }

        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: SingleChildScrollView(
                    child: SizedBox(
                      height: constraints.maxHeight > items.length * 72
                          ? constraints.maxHeight
                          : items.length * 72,
                      child: NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: onSelected,
                        labelType: NavigationRailLabelType.selected,
                        destinations: [
                          for (final item in items)
                            NavigationRailDestination(
                              icon: item.icon,
                              selectedIcon: item.selectedIcon ?? item.icon,
                              label: Text(item.label),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: BusGoBreakpoints.maxContentWidth(
                          constraints.maxWidth,
                        ),
                      ),
                      child: SizedBox.expand(child: body),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BusGoField extends StatelessWidget {
  const BusGoField({
    super.key,
    required this.label,
    required this.icon,
    this.hint,
  });

  final String label;
  final IconData icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class BusGoPill extends StatelessWidget {
  const BusGoPill({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class BusGoStatusChip extends StatelessWidget {
  const BusGoStatusChip({
    super.key,
    required this.label,
    this.tone = BusGoStatusTone.neutral,
    this.icon,
  });

  final String label;
  final BusGoStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _palette(tone, isDark, colorScheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: palette.$2),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: palette.$2,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _palette(
    BusGoStatusTone value,
    bool isDark,
    ColorScheme colorScheme,
  ) => switch (value) {
    BusGoStatusTone.positive => (
      isDark ? const Color(0xFF123528) : const Color(0xFFE5F7EE),
      isDark ? const Color(0xFFE6FFF0) : const Color(0xFF087443),
    ),
    BusGoStatusTone.warning => (
      isDark ? const Color(0xFF3A2E14) : const Color(0xFFFFF2D9),
      isDark ? const Color(0xFFFFD88A) : const Color(0xFF9A5B00),
    ),
    BusGoStatusTone.negative => (
      isDark ? const Color(0xFF3B1F23) : const Color(0xFFFFE8E8),
      isDark ? const Color(0xFFFFB4B4) : const Color(0xFFB42318),
    ),
    BusGoStatusTone.info => (
      isDark ? const Color(0xFF112B4A) : const Color(0xFFE7F0FF),
      isDark ? Colors.white : BusGoTokens.blue,
    ),
    BusGoStatusTone.neutral => (
      isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFEEF2F7),
      isDark ? colorScheme.onSurface : BusGoTokens.muted,
    ),
  };
}

enum BusGoStatusTone { positive, warning, negative, info, neutral }

class BusGoStatCard extends StatelessWidget {
  const BusGoStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent = BusGoTokens.blue,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return BusGoSurface(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 19),
          ),
          const SizedBox(height: 14),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class BusGoTimeline extends StatelessWidget {
  const BusGoTimeline({
    super.key,
    required this.steps,
    required this.activeIndex,
  });

  final List<String> steps;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < steps.length; index++)
          _TimelineStep(
            label: steps[index],
            isDone: index < activeIndex,
            isCurrent: index == activeIndex,
            isLast: index == steps.length - 1,
          ),
      ],
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.isDone,
    required this.isCurrent,
    required this.isLast,
  });

  final String label;
  final bool isDone;
  final bool isCurrent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = isDone || isCurrent
        ? BusGoTokens.blue
        : const Color(0xFFC9D2DF);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isDone ? color : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : isCurrent
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: color.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDone || isCurrent
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BusGoBusImage extends StatelessWidget {
  const BusGoBusImage({
    super.key,
    this.imageUrl,
    this.height = 170,
    this.borderRadius = 20,
  });

  final String? imageUrl;
  final double height;
  final double borderRadius;

  bool get _hasValidImageUrl => isValidRemoteImageUrl(imageUrl);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A2141), Color(0xFF164B86)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _hasValidImageUrl
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                cacheWidth: 1200,
                cacheHeight: (height * 3).round(),
                errorBuilder: (context, error, stackTrace) =>
                    _fallback(context),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: const Color(0xFFFFB547),
                        strokeWidth: 2,
                        value: progress.expectedTotalBytes == null
                            ? null
                            : progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!,
                      ),
                    ),
                  );
                },
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context, {bool showProgress = false}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: -18,
          bottom: -22,
          child: Icon(
            Icons.route_rounded,
            size: 150,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
        if (showProgress)
          const CircularProgressIndicator(
            color: Color(0xFFFFB547),
            strokeWidth: 2,
          )
        else
          const Icon(
            Icons.directions_bus_filled_rounded,
            size: 76,
            color: Color(0xFFFFB547),
          ),
      ],
    );
  }
}

class BusGoProfileAvatar extends StatelessWidget {
  const BusGoProfileAvatar({
    super.key,
    this.imageUrl,
    this.size = 64,
    this.label = 'B',
    this.onTap,
    this.tooltip,
  });

  final String? imageUrl;
  final double size;
  final String label;
  final VoidCallback? onTap;
  final String? tooltip;

  bool get _hasValidImageUrl => isValidRemoteImageUrl(imageUrl);

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasValidImageUrl
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              },
              errorBuilder: (context, _, _) => Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            )
          : Center(
              child: Text(label, style: Theme.of(context).textTheme.titleLarge),
            ),
    );

    if (onTap == null) return avatar;

    return Tooltip(
      message: tooltip ?? 'Open profile',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(size / 2),
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      ),
    );
  }
}

class BusGoSectionTile extends StatelessWidget {
  const BusGoSectionTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class BusGoRoleSelector extends StatelessWidget {
  const BusGoRoleSelector({
    super.key,
    required this.selectedRole,
    required this.onChanged,
    this.includeAdmin = true,
  });

  final AppUserRole? selectedRole;
  final ValueChanged<AppUserRole?> onChanged;
  final bool includeAdmin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final roles = [
      AppUserRole.customer,
      AppUserRole.owner,
      if (includeAdmin) AppUserRole.admin,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select account type',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        FormField<AppUserRole>(
          initialValue: selectedRole,
          validator: (value) =>
              value == null ? 'Please select your account type' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var index = 0; index < roles.length; index++) ...[
                    Expanded(
                      child: _BusGoRoleCard(
                        role: roles[index],
                        selected: selectedRole == roles[index],
                        onTap: () {
                          onChanged(roles[index]);
                          field.didChange(roles[index]);
                        },
                      ),
                    ),
                    if (index != roles.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              if (field.hasError) ...[
                const SizedBox(height: 6),
                Text(
                  field.errorText!,
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _BusGoRoleCard extends StatelessWidget {
  const _BusGoRoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AppUserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final icon = switch (role) {
      AppUserRole.customer => Icons.person_outline_rounded,
      AppUserRole.owner => Icons.directions_bus_outlined,
      AppUserRole.admin => Icons.admin_panel_settings_outlined,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? accent : colorScheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? accent : colorScheme.onSurface,
              ),
              const SizedBox(height: 5),
              Text(
                role.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? accent : colorScheme.onSurface,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
