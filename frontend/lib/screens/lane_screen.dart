import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../generated/l10n/app_localizations.dart';
import '../models/lane_models.dart';
import '../providers/route_provider.dart';
import '../utils/lane_url.dart';
import '../widgets/interactive_climbing_wall.dart';
import '../widgets/route_card.dart';
import 'route_detail_screen.dart';

class LaneScreen extends StatefulWidget {
  final int initialLaneId;

  const LaneScreen({super.key, required this.initialLaneId});

  @override
  State<LaneScreen> createState() => _LaneScreenState();
}

class _LaneScreenState extends State<LaneScreen> {
  PageController? _pageController;
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _ensureController(List<Lane> lanes) {
    if (_pageController != null) {
      return;
    }

    final initialIndex = lanes.indexWhere(
      (lane) => lane.id == widget.initialLaneId,
    );
    _currentIndex = initialIndex < 0 ? 0 : initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    replaceLaneUrl(lanes[_currentIndex].id);
  }

  void _goToLane(List<Lane> lanes, int laneId) {
    final index = lanes.indexWhere((lane) => lane.id == laneId);
    if (index >= 0) {
      _pageController?.animateToPage(
        index,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<RouteProvider>(
      builder: (context, routeProvider, child) {
        final lanes = [...routeProvider.lanes]
          ..sort((a, b) => a.id.compareTo(b.id));

        if (lanes.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.lane)),
            body: Center(
              child: routeProvider.isLoading
                  ? const CircularProgressIndicator()
                  : Text(l10n.noRoutesFound),
            ),
          );
        }

        _ensureController(lanes);
        final currentLane = lanes[_currentIndex.clamp(0, lanes.length - 1)];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentLane.name.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  l10n.laneLabel(currentLane.id),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: lanes.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              replaceLaneUrl(lanes[index].id);
            },
            itemBuilder: (context, index) {
              final lane = lanes[index];
              final routes = routeProvider.routesForLane(lane.id);

              return RefreshIndicator(
                onRefresh: () => routeProvider.loadRoutes(forceRefresh: true),
                child: CustomScrollView(
                  key: PageStorageKey('lane-${lane.id}'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _LaneHero(
                        lane: lane,
                        routeCount: routes.length,
                        onLaneSelected: (laneId) => _goToLane(lanes, laneId),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.navRoutes,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${routes.length} ${l10n.navRoutes.toLowerCase()}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _LaneStepButton(
                              icon: Icons.chevron_left,
                              enabled: index > 0,
                              onPressed: () => _pageController?.previousPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _LaneStepButton(
                              icon: Icons.chevron_right,
                              enabled: index < lanes.length - 1,
                              onPressed: () => _pageController?.nextPage(
                                duration: const Duration(milliseconds: 280),
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (routes.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.route_outlined,
                                  size: 48,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.noRoutesFound,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        sliver: SliverList.builder(
                          itemCount: routes.length,
                          itemBuilder: (context, routeIndex) {
                            final route = routes[routeIndex];
                            return RouteCard(
                              route: route,
                              hasLeadSent: routeProvider.hasUserLeadSentRoute(
                                route.id,
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RouteDetailScreen(routeId: route.id),
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
          ),
        );
      },
    );
  }
}

class _LaneHero extends StatelessWidget {
  final Lane lane;
  final int routeCount;
  final ValueChanged<int> onLaneSelected;

  const _LaneHero({
    required this.lane,
    required this.routeCount,
    required this.onLaneSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF242821),
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F172018),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.swipeToChangeLane.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFCED2C8),
                      fontSize: 11,
                      letterSpacing: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.swipe, size: 20, color: Color(0xFFFCB900)),
              ],
            ),
          ),
          InteractiveClimbingWall(
            selectedLaneId: lane.id,
            onLaneSelected: onLaneSelected,
            height: 170,
            showCard: false,
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.24),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lane.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCB900),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$routeCount ${l10n.navRoutes.toLowerCase()}',
                    style: const TextStyle(
                      color: Color(0xFF242821),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LaneStepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  const _LaneStepButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
    );
  }
}
