import 'dart:ui' as ui;

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

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Map<int, double> _wallLaneStrengths = const {};
  final Set<String> _preloadedLaneImages = {};
  late final AnimationController _laneImageRevealController;
  double _fullScreenHorizontalDrag = 0;
  int? _fullScreenLaneTargetId;

  @override
  void initState() {
    super.initState();
    _laneImageRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _laneImageRevealController.dispose();
    super.dispose();
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
    _laneImageRevealController.value = 0;
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
    final keepImageRevealed = _fullScreenLaneTargetId == laneId;
    _fullScreenLaneTargetId = null;
    if (!keepImageRevealed) {
      _laneImageRevealController.value = 0;
    }
    routeProvider.setLaneIdsFilter({laneId});
    replaceLaneUrl(laneId);
  }

  void _updateLaneImageReveal(double delta) {
    _laneImageRevealController.value =
        (_laneImageRevealController.value + delta).clamp(0.0, 1.0);
  }

  void _settleLaneImageReveal() {
    final showImage = _laneImageRevealController.value > 0.18;
    _laneImageRevealController.animateTo(
      showImage ? 1 : 0,
      curve: Curves.easeOutCubic,
    );
  }

  String? _laneImageFor(RouteProvider routeProvider, int laneId) {
    final routes = routeProvider.routesForLane(laneId);
    if (routes.isEmpty) {
      return null;
    }

    final image = routes.first.image?.trim();
    return image == null || image.isEmpty ? null : image;
  }

  void _preloadNearbyLaneImages(
    RouteProvider routeProvider,
    List<Lane> lanes,
    int selectedLaneId,
  ) {
    final selectedIndex = lanes.indexWhere(
      (lane) => lane.id == selectedLaneId,
    );
    if (selectedIndex < 0) {
      return;
    }

    final firstIndex = selectedIndex > 0 ? selectedIndex - 1 : 0;
    final lastIndex =
        selectedIndex < lanes.length - 1 ? selectedIndex + 1 : selectedIndex;
    for (var index = firstIndex; index <= lastIndex; index++) {
      final image = _laneImageFor(routeProvider, lanes[index].id);
      if (image == null || !_preloadedLaneImages.add(image)) {
        continue;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        try {
          await precacheImage(NetworkImage(image), context);
        } catch (error) {
          _preloadedLaneImages.remove(image);
          debugPrint('Could not preload lane image: $error');
        }
      });
    }
  }

  void _selectFullScreenLane(
    RouteProvider routeProvider,
    List<Lane> lanes,
    int selectedLaneId,
    int direction,
  ) {
    final selectedIndex = lanes.indexWhere(
      (lane) => lane.id == selectedLaneId,
    );
    final targetIndex = selectedIndex + direction;
    if (selectedIndex < 0 ||
        targetIndex < 0 ||
        targetIndex >= lanes.length) {
      return;
    }

    final laneId = lanes[targetIndex].id;
    _fullScreenLaneTargetId = laneId;
    routeProvider.setLaneIdsFilter({laneId});
    replaceLaneUrl(laneId);
    setState(() => _wallLaneStrengths = {laneId: 1});
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
          final laneImage = singleLaneId == null
              ? null
              : _laneImageFor(routeProvider, singleLaneId);
          final hasLaneImage = laneImage != null;
          if (singleLaneId != null) {
            _preloadNearbyLaneImages(routeProvider, lanes, singleLaneId);
          }

          final content = Column(
            children: [
              InteractiveClimbingWall(
                laneSelectionStrengths: wallLaneStrengths,
                onLaneSelected: (laneId) => _toggleLane(routeProvider, laneId),
              ),
              _FilterSummaryBar(
                routeCount: routeProvider.routes.length,
                singleLaneId: singleLaneId,
                hasLaneImage: hasLaneImage,
                hasActiveFilters: routeProvider.hasActiveFilters,
                onShowLaneImage: hasLaneImage
                    ? () => _laneImageRevealController.animateTo(
                          1,
                          curve: Curves.easeOutCubic,
                        )
                    : null,
                onClear: () {
                  _laneImageRevealController.value = 0;
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
                        onImagePull: _updateLaneImageReveal,
                        onImagePullEnd: _settleLaneImageReveal,
                      ),
              ),
            ],
          );

          if (!hasLaneImage) {
            return content;
          }

          return AnimatedBuilder(
            animation: _laneImageRevealController,
            child: content,
            builder: (context, child) {
              final progress = _laneImageRevealController.value;
              final laneImageProvider = NetworkImage(laneImage);
              final selectedLaneIndex = lanes.indexWhere(
                (lane) => lane.id == singleLaneId,
              );
              final hasPreviousLane = selectedLaneIndex > 0;
              final hasNextLane =
                  selectedLaneIndex >= 0 &&
                  selectedLaneIndex < lanes.length - 1;
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: SizedBox.expand(
                          key: ValueKey(laneImage),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRect(
                                child: ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(
                                    sigmaX: 22,
                                    sigmaY: 22,
                                  ),
                                  child: Transform.scale(
                                    scale: 1.08,
                                    child: Image(
                                      image: laneImageProvider,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.low,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                              ColoredBox(
                                color: Colors.black.withValues(alpha: 0.2),
                              ),
                              Image(
                                image: laneImageProvider,
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ColoredBox(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.6 - (progress * 0.53)),
                      ),
                      Transform.translate(
                        offset: Offset(0, constraints.maxHeight * progress),
                        child: child,
                      ),
                      if (progress > 0.001)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onHorizontalDragStart: (_) {
                            _fullScreenHorizontalDrag = 0;
                          },
                          onHorizontalDragUpdate: (details) {
                            _fullScreenHorizontalDrag += details.delta.dx;
                          },
                          onHorizontalDragEnd: (details) {
                            final velocity = details.primaryVelocity ?? 0;
                            final threshold = constraints.maxWidth * 0.12;
                            if (_fullScreenHorizontalDrag < -threshold ||
                                velocity < -450) {
                              _selectFullScreenLane(
                                routeProvider,
                                lanes,
                                singleLaneId!,
                                1,
                              );
                            } else if (_fullScreenHorizontalDrag > threshold ||
                                velocity > 450) {
                              _selectFullScreenLane(
                                routeProvider,
                                lanes,
                                singleLaneId!,
                                -1,
                              );
                            }
                            _fullScreenHorizontalDrag = 0;
                          },
                          onHorizontalDragCancel: () {
                            _fullScreenHorizontalDrag = 0;
                          },
                          onVerticalDragUpdate: (details) {
                            _updateLaneImageReveal(
                              details.delta.dy / constraints.maxHeight,
                            );
                          },
                          onVerticalDragEnd: (_) {
                            _laneImageRevealController.animateTo(
                              _laneImageRevealController.value < 0.82 ? 0 : 1,
                              curve: Curves.easeOutCubic,
                            );
                          },
                          child: Stack(
                            children: [
                              if (progress > 0.7)
                                Align(
                                  alignment: Alignment.topCenter,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: Opacity(
                                      opacity:
                                          ((progress - 0.7) / 0.3).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.58,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                          ),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 7,
                                          ),
                                          child: Text(
                                            l10n.laneLabel(singleLaneId!),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (hasPreviousLane)
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: EdgeInsets.only(left: 12),
                                    child: _FullScreenLaneChevron(
                                      icon: Icons.chevron_left,
                                    ),
                                  ),
                                ),
                              if (hasNextLane)
                                const Align(
                                  alignment: Alignment.centerRight,
                                  child: Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: _FullScreenLaneChevron(
                                      icon: Icons.chevron_right,
                                    ),
                                  ),
                                ),
                              const Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: EdgeInsets.only(bottom: 18),
                                  child: _FullScreenLaneChevron(
                                    icon: Icons.keyboard_arrow_up,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FullScreenLaneChevron extends StatelessWidget {
  final IconData icon;

  const _FullScreenLaneChevron({required this.icon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0x59000000),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _FilterSummaryBar extends StatelessWidget {
  final int routeCount;
  final int? singleLaneId;
  final bool hasLaneImage;
  final bool hasActiveFilters;
  final VoidCallback? onShowLaneImage;
  final VoidCallback onClear;

  const _FilterSummaryBar({
    required this.routeCount,
    required this.singleLaneId,
    required this.hasLaneImage,
    required this.hasActiveFilters,
    required this.onShowLaneImage,
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
      constraints: const BoxConstraints(minHeight: 48),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.45),
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
              if (singleLaneId != null && hasLaneImage) ...[
                Tooltip(
                  message: l10n.pullDownForLaneImage,
                  child: Material(
                    color: colorScheme.surface.withValues(alpha: 0.78),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: colorScheme.outline.withValues(alpha: 0.5),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onShowLaneImage,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              l10n.laneImageHint,
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.photo_outlined,
                              size: 14,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
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
  final ValueChanged<double> onImagePull;
  final VoidCallback onImagePullEnd;

  const _LaneRouteCarousel({
    required this.lanes,
    required this.selectedLaneId,
    required this.routeProvider,
    required this.onLaneChanged,
    required this.onProgress,
    required this.onImagePull,
    required this.onImagePullEnd,
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
          onImagePull: widget.onImagePull,
          onImagePullEnd: widget.onImagePullEnd,
        );
      },
    );
  }
}

class _LaneRoutePage extends StatelessWidget {
  final List<models.Route> routes;
  final RouteProvider routeProvider;
  final ValueChanged<double> onImagePull;
  final VoidCallback onImagePullEnd;

  const _LaneRoutePage({
    required this.routes,
    required this.routeProvider,
    required this.onImagePull,
    required this.onImagePullEnd,
  });

  @override
  Widget build(BuildContext context) {
    final routes = this.routes;
    final image = routes.isEmpty ? null : routes.first.image?.trim();
    final hasBackground = image != null && image.isNotEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (hasBackground &&
            notification is OverscrollNotification &&
            notification.overscroll < 0) {
          onImagePull(
            -notification.overscroll /
                notification.metrics.viewportDimension,
          );
          return true;
        }
        if (hasBackground && notification is ScrollEndNotification) {
          onImagePullEnd();
        }
        return false;
      },
      child: _RouteResultsList(
        routes: routes,
        routeProvider: routeProvider,
        enableRefresh: false,
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      ),
    );
  }
}

class _RouteResultCard extends StatelessWidget {
  final models.Route route;
  final RouteProvider routeProvider;

  const _RouteResultCard({
    required this.route,
    required this.routeProvider,
  });

  @override
  Widget build(BuildContext context) {
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
  }
}

class _RouteResultsList extends StatelessWidget {
  final List<models.Route> routes;
  final RouteProvider routeProvider;
  final bool enableRefresh;
  final ScrollPhysics? physics;

  const _RouteResultsList({
    required this.routes,
    required this.routeProvider,
    this.enableRefresh = true,
    this.physics,
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

    final list = ListView.builder(
      key: PageStorageKey('lane-routes-${routes.first.lane}'),
      padding: const EdgeInsets.all(16),
      physics: physics,
      itemCount: routes.length,
      itemBuilder: (context, index) {
        return _RouteResultCard(
          route: routes[index],
          routeProvider: routeProvider,
        );
      },
    );

    if (!enableRefresh) {
      return list;
    }

    return RefreshIndicator(
      onRefresh: () => routeProvider.loadRoutes(),
      child: list,
    );
  }
}
