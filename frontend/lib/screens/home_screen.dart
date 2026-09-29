import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/route_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/route_card.dart';
import '../widgets/filter_drawer.dart';
import '../widgets/interactive_climbing_wall.dart';
import '../widgets/custom_app_bar.dart';
import '../generated/l10n/app_localizations.dart';
import 'route_detail_screen.dart';
import 'add_route_screen.dart';
import 'lane_screen.dart';

class HomeScreen extends StatefulWidget {
  final int? initialLaneId;

  const HomeScreen({super.key, this.initialLaneId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _WallInteractionMode {
  explore,
  select,
}

class _HomeScreenState extends State<HomeScreen> {
  bool _initialLaneOpened = false;
  _WallInteractionMode _wallMode = _WallInteractionMode.explore;

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
    if (laneId == null || _initialLaneOpened) {
      return;
    }

    if (routeProvider.lanes.any((lane) => lane.id == laneId)) {
      _initialLaneOpened = true;
      await _openLane(laneId);
    }
  }

  Future<void> _openLane(int laneId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LaneScreen(initialLaneId: laneId),
      ),
    );
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

          return Column(
            children: [
              _WallModeSwitcher(
                mode: _wallMode,
                selectedLaneCount: routeProvider.selectedLaneIds.length,
                onChanged: (mode) {
                  setState(() => _wallMode = mode);
                },
                onClear: routeProvider.selectedLaneIds.isEmpty
                    ? null
                    : () => routeProvider.setLaneIdsFilter(<int>{}),
              ),

              // Interactive Climbing Wall
              InteractiveClimbingWall(
                onLaneSelected: (laneId) {
                  if (_wallMode == _WallInteractionMode.select) {
                    routeProvider.toggleLaneFilter(laneId);
                  } else {
                    _openLane(laneId);
                  }
                },
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
                          final summary =
                              '${l10n.filters}: ${routeProvider.routes.length}';

                          return Row(
                            children: [
                              Icon(
                                Icons.filter_alt,
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
                                      onPressed: () =>
                                          routeProvider.clearAllFilters(),
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
                                      onPressed: () =>
                                          routeProvider.clearAllFilters(),
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
          );
        },
      ),
    );
  }
}

class _WallModeSwitcher extends StatelessWidget {
  final _WallInteractionMode mode;
  final int selectedLaneCount;
  final ValueChanged<_WallInteractionMode> onChanged;
  final VoidCallback? onClear;

  const _WallModeSwitcher({
    required this.mode,
    required this.selectedLaneCount,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isSelecting = mode == _WallInteractionMode.select;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelecting
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelecting
              ? colorScheme.primary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<_WallInteractionMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _WallInteractionMode.explore,
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(l10n.exploreLanes),
                    ),
                    ButtonSegment(
                      value: _WallInteractionMode.select,
                      icon: const Icon(Icons.library_add_check, size: 18),
                      label: Text(l10n.selectLanes),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (selection) {
                    onChanged(selection.first);
                  },
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: isSelecting
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app_outlined,
                          size: 16,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            l10n.tapLanesToFilter,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (selectedLaneCount > 0)
                          TextButton(
                                onPressed: onClear,
                                child: Text(
                                  '$selectedLaneCount · ${l10n.clearAll}',
                                ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
