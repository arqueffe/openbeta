import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lane_models.dart';
import '../models/route_models.dart' as models;
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
  Map<int, double> _wallLaneStrengths = const {};

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
    final selectedLaneIds = routeProvider.selectedLaneIds;
    setState(() {
      _wallLaneStrengths =
          selectedLaneIds.length == 1 ? {selectedLaneIds.first: 1} : const {};
    });
  }

  void _syncLaneUrl(Set<int> selectedLaneIds) {
    replaceLaneUrl(
      selectedLaneIds.length == 1 ? selectedLaneIds.first : null,
    );
  }

  void _updateWallLaneStrengths(Map<int, double> strengths) {
    setState(() {
      _wallLaneStrengths = strengths;
    });
  }

  void _selectCarouselLane(RouteProvider routeProvider, int laneId) {
    routeProvider.setLaneIdsFilter({laneId});
    replaceLaneUrl(laneId);
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
          final lanes = [...routeProvider.lanes]
            ..sort((a, b) => a.id.compareTo(b.id));
          final wallLaneStrengths = singleLaneId == null
              ? null
              : (_wallLaneStrengths.containsKey(singleLaneId)
                  ? _wallLaneStrengths
                  : {singleLaneId: 1.0});

          return Column(
            children: [
              InteractiveClimbingWall(
                laneSelectionStrengths: wallLaneStrengths,
                onLaneSelected: (laneId) => _toggleLane(routeProvider, laneId),
              ),
              _FilterSummaryBar(
                routeCount: routeProvider.routes.length,
                singleLaneId: singleLaneId,
                hasActiveFilters: routeProvider.hasActiveFilters,
                onClear: () {
                  routeProvider.clearAllFilters();
                  replaceLaneUrl(null);
                  setState(() => _wallLaneStrengths = const {});
                },
              ),
              Expanded(
                child: singleLaneId == null
                    ? _RouteResultsList(
                        routes: routeProvider.routes,
                        routeProvider: routeProvider,
                      )
                    : _LaneRouteCarousel(
                        lanes: lanes,
                        selectedLaneId: singleLaneId,
                        routeProvider: routeProvider,
                        onLaneChanged: (laneId) =>
                            _selectCarouselLane(routeProvider, laneId),
                        onProgress: _updateWallLaneStrengths,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterSummaryBar extends StatelessWidget {
  final int routeCount;
  final int? singleLaneId;
  final bool hasActiveFilters;
  final VoidCallback onClear;

  const _FilterSummaryBar({
    required this.routeCount,
    required this.singleLaneId,
    required this.hasActiveFilters,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasActiveFilters) {
      return const SizedBox(height: 48);
    }

    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final summary = singleLaneId == null
        ? '${l10n.filters}: $routeCount'
        : '${l10n.laneLabel(singleLaneId!)} · '
            '${l10n.swipeForAdjacentLanes}';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: colorScheme.outline),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 560;
          return Row(
            children: [
              Icon(
                singleLaneId == null ? Icons.filter_alt : Icons.swipe,
                size: 16,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isCompact)
                IconButton(
                  onPressed: onClear,
                  tooltip: l10n.clearAll,
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  visualDensity: VisualDensity.compact,
                )
              else
                TextButton(
                  onPressed: onClear,
                  child: Text(
                    l10n.clearAll,
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _LaneRouteCarousel extends StatefulWidget {
  final List<Lane> lanes;
  final int selectedLaneId;
  final RouteProvider routeProvider;
  final ValueChanged<int> onLaneChanged;
  final ValueChanged<Map<int, double>> onProgress;

  const _LaneRouteCarousel({
    required this.lanes,
    required this.selectedLaneId,
    required this.routeProvider,
    required this.onLaneChanged,
    required this.onProgress,
  });

  @override
  State<_LaneRouteCarousel> createState() => _LaneRouteCarouselState();
}

class _LaneRouteCarouselState extends State<_LaneRouteCarousel> {
  late final PageController _pageController;

  int get _selectedIndex {
    final index = widget.lanes.indexWhere(
      (lane) => lane.id == widget.selectedLaneId,
    );
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _pageController.addListener(_reportProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onProgress({widget.selectedLaneId: 1});
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LaneRouteCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLaneId == widget.selectedLaneId ||
        !_pageController.hasClients) {
      return;
    }

    final page = _pageController.page?.round();
    if (page != _selectedIndex) {
      _pageController.jumpToPage(_selectedIndex);
    }
  }

  void _reportProgress() {
    if (!_pageController.hasClients || widget.lanes.isEmpty) {
      return;
    }

    final page = (_pageController.page ?? _selectedIndex.toDouble()).clamp(
      0.0,
      widget.lanes.length - 1.0,
    );
    final lowerIndex = page.floor();
    final upperIndex = page.ceil();
    final progress = page - lowerIndex;
    final strengths = <int, double>{
      widget.lanes[lowerIndex].id: 1 - progress,
    };
    if (upperIndex != lowerIndex) {
      strengths[widget.lanes[upperIndex].id] = progress;
    }
    widget.onProgress(strengths);
  }

  @override
  void dispose() {
    _pageController
      ..removeListener(_reportProgress)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.lanes.length,
      onPageChanged: (index) {
        widget.onLaneChanged(widget.lanes[index].id);
      },
      itemBuilder: (context, index) {
        final routes = widget.routeProvider.routesForLane(
          widget.lanes[index].id,
        );
        return _LaneRoutePage(
          routes: routes,
          routeProvider: widget.routeProvider,
        );
      },
    );
  }
}

class _LaneRoutePage extends StatelessWidget {
  final List<models.Route> routes;
  final RouteProvider routeProvider;

  const _LaneRoutePage({
    required this.routes,
    required this.routeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final image = routes.isEmpty ? null : routes.first.image?.trim();
    final hasBackground = image != null && image.isNotEmpty;

    return Stack(
      children: [
        if (hasBackground)
          Positioned.fill(
            child: Image.network(
              image,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.never,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        if (hasBackground)
          Positioned.fill(
            child: ColoredBox(
              color:
                  Theme.of(context).colorScheme.surface.withValues(alpha: 0.86),
            ),
          ),
        _RouteResultsList(
          routes: routes,
          routeProvider: routeProvider,
        ),
      ],
    );
  }
}

class _RouteResultsList extends StatelessWidget {
  final List<models.Route> routes;
  final RouteProvider routeProvider;

  const _RouteResultsList({
    required this.routes,
    required this.routeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terrain, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              l10n.noRoutesFound,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adjustFiltersOrAddRoute,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => routeProvider.loadRoutes(),
      child: ListView.builder(
        key: PageStorageKey('lane-routes-${routes.first.lane}'),
        padding: const EdgeInsets.all(16),
        itemCount: routes.length,
        itemBuilder: (context, index) {
          final route = routes[index];
          return RouteCard(
            route: route,
            hasLeadSent: routeProvider.hasUserLeadSentRoute(route.id),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RouteDetailScreen(routeId: route.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
