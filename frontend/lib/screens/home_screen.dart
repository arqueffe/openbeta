import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/route_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/route_card.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/interactive_climbing_wall.dart';
import '../widgets/custom_app_bar.dart';
import '../generated/l10n/app_localizations.dart';
import '../utils/lane_url.dart';
import 'route_detail_screen.dart';
import 'add_route_screen.dart';

class HomeScreen extends StatefulWidget {
  final int? initialLaneId;

  const HomeScreen({super.key, this.initialLaneId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    final routeProvider = context.read<RouteProvider>();
    await routeProvider.loadInitialData();

    if (!mounted) {
      return;
    }

    final laneId = widget.initialLaneId;
    if (laneId == null) {
      return;
    }

    if (routeProvider.lanes.any((lane) => lane.id == laneId)) {
      routeProvider.setLaneIdsFilter({laneId});
    }
  }

  void _toggleLane(RouteProvider routeProvider, int laneId) {
    routeProvider.toggleLaneFilter(laneId);
    _syncLaneUrl(routeProvider.selectedLaneIds);
  }

  void _syncLaneUrl(Set<int> selectedLaneIds) {
    replaceLaneUrl(
      selectedLaneIds.length == 1 ? selectedLaneIds.first : null,
    );
  }

  void _swipeToAdjacentLane(
    DragEndDetails details,
    RouteProvider routeProvider,
  ) {
    if (routeProvider.selectedLaneIds.length != 1) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < 250) {
      return;
    }

    final lanes = [...routeProvider.lanes]
      ..sort((a, b) => a.id.compareTo(b.id));
    final currentLaneId = routeProvider.selectedLaneIds.first;
    final currentIndex = lanes.indexWhere((lane) => lane.id == currentLaneId);
    if (currentIndex < 0) {
      return;
    }

    final direction = velocity < 0 ? 1 : -1;
    final nextIndex = currentIndex + direction;
    if (nextIndex < 0 || nextIndex >= lanes.length) {
      return;
    }

    final nextLaneId = lanes[nextIndex].id;
    routeProvider.setLaneIdsFilter({nextLaneId});
    replaceLaneUrl(nextLaneId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n.appTitle,
        automaticallyImplyLeading:
            false, // Remove back button since we're using bottom nav
        actions: [
          Builder(builder: (BuildContext context) {
            return IconButton(
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
              icon: const Icon(Icons.filter_list),
              tooltip: l10n.filters,
            );
          }),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              // Only show add route button if user has permission
              if (!authProvider.canCreateRoutes) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddRouteScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                tooltip: l10n.addRoute,
              );
            },
          ),
        ],
      ),
      endDrawer: const FilterDrawer(),
      body: Consumer<RouteProvider>(
        builder: (context, routeProvider, child) {
          if (routeProvider.isLoading && routeProvider.routes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routeProvider.error != null && routeProvider.routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    '${l10n.error}: ${routeProvider.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => routeProvider.loadInitialData(),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            );
          }

          final selectedLaneIds = routeProvider.selectedLaneIds;
          final singleLaneId =
              selectedLaneIds.length == 1 ? selectedLaneIds.first : null;
          final laneRoutes = singleLaneId == null
              ? null
              : routeProvider.routesForLane(singleLaneId);
          final backgroundImage = laneRoutes != null && laneRoutes.isNotEmpty
              ? laneRoutes.first.image?.trim()
              : null;
          final hasBackground =
              backgroundImage != null && backgroundImage.isNotEmpty;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragEnd: singleLaneId == null
                ? null
                : (details) =>
                    _swipeToAdjacentLane(details, routeProvider),
            child: Stack(
              children: [
                if (hasBackground)
                  Positioned.fill(
                    child: Image.network(
                      backgroundImage,
                      fit: BoxFit.cover,
                      webHtmlElementStrategy:
                          WebHtmlElementStrategy.never,
                      errorBuilder: (_, __, ___) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                if (hasBackground)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.86),
                    ),
                  ),
                Column(
                  children: [
                    // Interactive Climbing Wall
                    InteractiveClimbingWall(
                      onLaneSelected: (laneId) =>
                          _toggleLane(routeProvider, laneId),
                    ),

                    // Keep the spacer stable when there are no filters, but allow
                    // the active filter bar to grow on narrow screens.
                    routeProvider.hasActiveFilters
                  ? Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 560;
                          final summary = singleLaneId == null
                              ? '${l10n.filters}: ${routeProvider.routes.length}'
                              : '${l10n.laneLabel(singleLaneId)} · '
                                  '${l10n.swipeForAdjacentLanes}';

                          return Row(
                            children: [
                              Icon(
                                singleLaneId == null
                                    ? Icons.filter_alt
                                    : Icons.swipe,
                                size: 16,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              isCompact
                                  ? IconButton(
                                      onPressed: () {
                                        routeProvider.clearAllFilters();
                                        replaceLaneUrl(null);
                                      },
                                      tooltip: l10n.clearAll,
                                      icon: Icon(
                                        Icons.clear,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : TextButton(
                                      onPressed: () {
                                        routeProvider.clearAllFilters();
                                        replaceLaneUrl(null);
                                      },
                                      child: Text(
                                        l10n.clearAll,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                            ],
                          );
                        },
                      ),
                    )
                  : const SizedBox(height: 48),
                    Expanded(
                child: routeProvider.routes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.terrain,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.noRoutesFound,
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.adjustFiltersOrAddRoute,
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => routeProvider.loadRoutes(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: routeProvider.routes.length,
                          itemBuilder: (context, index) {
                            final route = routeProvider.routes[index];
                            final hasLeadSent =
                                routeProvider.hasUserLeadSentRoute(route.id);
                            return RouteCard(
                              route: route,
                              hasLeadSent: hasLeadSent,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RouteDetailScreen(
                                      routeId: route.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
