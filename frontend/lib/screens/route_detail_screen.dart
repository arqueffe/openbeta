import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../generated/l10n/app_localizations.dart';
import '../models/route_models.dart' as models;
import '../providers/route_provider.dart';
import '../utils/color_utils.dart';
import '../widgets/grade_chip.dart';
import '../widgets/route_detail/name_proposal_section.dart';
import '../widgets/route_detail/route_detail_activity_sections.dart';
import '../widgets/route_interactions.dart';

class RouteDetailScreen extends StatefulWidget {
  final int routeId;

  const RouteDetailScreen({super.key, required this.routeId});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen>
    with SingleTickerProviderStateMixin {
  static const _imageRestoreThreshold = 0.92;
  static const _imageRestoreDragMultiplier = 4.0;

  late final AnimationController _imageRevealController;

  @override
  void initState() {
    super.initState();
    _imageRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final routeProvider = context.read<RouteProvider>();
      routeProvider.loadRoute(widget.routeId);
      routeProvider.loadGradeColors();
    });
  }

  @override
  void dispose() {
    _imageRevealController.dispose();
    super.dispose();
  }

  void _updateImageReveal(double delta) {
    _imageRevealController.value =
        (_imageRevealController.value + delta).clamp(0.0, 1.0);
  }

  void _settleImageReveal() {
    _imageRevealController.animateTo(
      _imageRevealController.value > 0.18 ? 1 : 0,
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildRouteDetails(models.Route route, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RouteSummaryCard(route: route, l10n: l10n),
              const SizedBox(height: 16),
              RouteInteractions(route: route, compact: true),
              if (route.name == 'Unnamed') ...[
                const SizedBox(height: 16),
                NameProposalSection(route: route),
              ],
              if (route.comments != null && route.comments!.isNotEmpty) ...[
                const SizedBox(height: 16),
                RouteCommentsSection(
                  comments: route.comments!,
                  l10n: l10n,
                ),
              ],
              if (route.gradeProposals != null &&
                  route.gradeProposals!.isNotEmpty) ...[
                const SizedBox(height: 16),
                RouteGradeProposalsSection(
                  proposals: route.gradeProposals!,
                  l10n: l10n,
                ),
              ],
              if (route.warnings != null && route.warnings!.isNotEmpty) ...[
                const SizedBox(height: 16),
                RouteWarningsSection(
                  warnings: route.warnings!,
                  l10n: l10n,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardRoute(models.Route route, AppLocalizations l10n) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(route.displayName(unnamedFallback: l10n.unnamed)),
        ),
        SliverToBoxAdapter(child: _buildRouteDetails(route, l10n)),
      ],
    );
  }

  Widget _buildImageRevealRoute(
    BuildContext context,
    models.Route route,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sheetTop =
            (constraints.maxHeight * 0.34).clamp(220.0, 320.0).toDouble();

        return Stack(
          fit: StackFit.expand,
          children: [
            _RouteHero(route: route),
            AnimatedBuilder(
              animation: _imageRevealController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    constraints.maxHeight * _imageRevealController.value,
                  ),
                  child: child,
                );
              },
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is OverscrollNotification &&
                      notification.overscroll < 0) {
                    _updateImageReveal(
                      -notification.overscroll /
                          notification.metrics.viewportDimension,
                    );
                    return true;
                  }
                  if (notification is ScrollEndNotification) {
                    _settleImageReveal();
                  }
                  return false;
                },
                child: CustomScrollView(
                  physics: const ClampingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(child: SizedBox(height: sheetTop)),
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                        ),
                        child: Column(
                          children: [
                            _RouteImageRevealHandle(
                              onTap: () => _imageRevealController.animateTo(
                                1,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            _buildRouteDetails(route, l10n),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_imageRevealController.value > 0.001)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  final delta = details.delta.dy < 0
                      ? details.delta.dy * _imageRestoreDragMultiplier
                      : details.delta.dy;
                  _updateImageReveal(
                    delta / constraints.maxHeight,
                  );
                },
                onVerticalDragEnd: (_) {
                  _imageRevealController.animateTo(
                    _imageRevealController.value < _imageRestoreThreshold
                        ? 0
                        : 1,
                    curve: Curves.easeOutCubic,
                  );
                },
              ),
            const Positioned(
              top: 12,
              left: 12,
              child: SafeArea(child: _RouteBackButton()),
            ),
            if (_imageRevealController.value > 0.001)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  child: IconButton(
                    onPressed: () => _imageRevealController.animateTo(
                      0,
                      curve: Curves.easeOutCubic,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_up),
                    color: Colors.white,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Consumer<RouteProvider>(
        builder: (context, routeProvider, child) {
          if (routeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routeProvider.error != null) {
            return _RouteLoadError(
              message: routeProvider.error!,
              onRetry: () => routeProvider.loadRoute(widget.routeId),
              l10n: l10n,
            );
          }

          final route = routeProvider.selectedRoute;
          if (route == null) {
            return Center(child: Text(l10n.routeNotFound));
          }

          return route.image == null
              ? _buildStandardRoute(route, l10n)
              : _buildImageRevealRoute(context, route, l10n);
        },
      ),
    );
  }
}

class _RouteHero extends StatelessWidget {
  final models.Route route;

  const _RouteHero({required this.route});

  @override
  Widget build(BuildContext context) {
    final image = route.image;
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (image != null)
          ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Transform.scale(
                scale: 1.08,
                child: Image.network(
                  image,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  webHtmlElementStrategy: WebHtmlElementStrategy.never,
                  errorBuilder: (_, __, ___) => _RouteImagePlaceholder(
                    color: theme.colorScheme.primaryContainer,
                  ),
                ),
              ),
            ),
          )
        else
          _RouteImagePlaceholder(color: theme.colorScheme.primaryContainer),
        if (image != null)
          ColoredBox(color: Colors.black.withValues(alpha: 0.2)),
        if (image != null)
          Image.network(
            image,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            webHtmlElementStrategy: WebHtmlElementStrategy.never,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x22000000),
                Color(0x11000000),
                Color(0xB8000000),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RouteImagePlaceholder extends StatelessWidget {
  final Color color;

  const _RouteImagePlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Center(
        child: Icon(
          Icons.terrain_outlined,
          size: 68,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _RouteBackButton extends StatelessWidget {
  const _RouteBackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => Navigator.maybePop(context),
      icon: const Icon(Icons.arrow_back),
      color: Colors.white,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.38),
      ),
    );
  }
}

class _RouteImageRevealHandle extends StatelessWidget {
  final VoidCallback onTap;

  const _RouteImageRevealHandle({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteSummaryCard extends StatelessWidget {
  final models.Route route;
  final AppLocalizations l10n;

  const _RouteSummaryCard({required this.route, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = route.description?.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GradeChip(
                  grade: route.gradeName ?? '-',
                  gradeColorHex: route.gradeColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  fontSize: 16,
                ),
                const Spacer(),
                if (route.colorHex != null)
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: ColorUtils.parseHexColor(route.colorHex!),
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              route.displayName(unnamedFallback: l10n.unnamed),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RouteMetadata(
                  icon: Icons.location_on_outlined,
                  label: route.wallSection,
                ),
                _RouteMetadata(
                  icon: Icons.format_list_numbered,
                  label: l10n.laneLabel(route.lane),
                ),
                _RouteMetadata(
                  icon: Icons.person_outline,
                  label: l10n.setBy(route.routeSetter),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              const SizedBox(height: 18),
              Divider(color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 14),
              Text(description, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 18),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: [
                _RouteStat(
                  icon: Icons.favorite_border,
                  label: '${route.likesCount}',
                ),
                _RouteStat(
                  icon: Icons.check_circle_outline,
                  label: '${route.ticksCount}',
                ),
                _RouteStat(
                  icon: Icons.chat_bubble_outline,
                  label: '${route.commentsCount}',
                ),
                if (route.warningsCount > 0)
                  _RouteStat(
                    icon: Icons.warning_amber_outlined,
                    label: '${route.warningsCount}',
                    color: theme.colorScheme.error,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMetadata extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RouteMetadata({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _RouteStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _RouteStat({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: foreground)),
      ],
    );
  }
}

class _RouteLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final AppLocalizations l10n;

  const _RouteLoadError({
    required this.message,
    required this.onRetry,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              '${l10n.error}: $message',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
