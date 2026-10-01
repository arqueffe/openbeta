import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/climbing_wall_models.dart';
import '../providers/route_provider.dart';
import '../services/climbing_wall_service.dart';

class InteractiveClimbingWall extends StatefulWidget {
  final ValueChanged<int>? onLaneSelected;
  final int? selectedLaneId;
  final Map<int, double>? laneSelectionStrengths;
  final ValueListenable<Map<int, double>>? laneSelectionStrengthsListenable;
  final double? height;
  final bool showCard;

  const InteractiveClimbingWall({
    super.key,
    this.onLaneSelected,
    this.selectedLaneId,
    this.laneSelectionStrengths,
    this.laneSelectionStrengthsListenable,
    this.height,
    this.showCard = true,
  });

  @override
  State<InteractiveClimbingWall> createState() =>
      _InteractiveClimbingWallState();
}

class _InteractiveClimbingWallState extends State<InteractiveClimbingWall> {
  ClimbingWall? _wallData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWallData();
  }

  Future<void> _loadWallData() async {
    try {
      _wallData = await ClimbingWallService.loadWallData();
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Error loading climbing wall: $_error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    if (_wallData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No wall data available')),
        ),
      );
    }

    return Consumer<RouteProvider>(
      builder: (context, routeProvider, child) {
        final strengthsListenable = widget.laneSelectionStrengthsListenable;
        if (strengthsListenable == null) {
          return _buildWall(
            context,
            routeProvider,
            widget.laneSelectionStrengths,
          );
        }

        return ValueListenableBuilder<Map<int, double>>(
          valueListenable: strengthsListenable,
          builder: (context, strengths, child) =>
              _buildWall(context, routeProvider, strengths),
        );
      },
    );
  }

  Widget _buildWall(
    BuildContext context,
    RouteProvider routeProvider,
    Map<int, double>? laneSelectionStrengths,
  ) {
    final hasActiveFilters = routeProvider.hasActiveFilters;
    final matchingLaneIds = hasActiveFilters
        ? routeProvider.routes.map((route) => route.lane).toSet()
        : <int>{};
    final hasLaneSelectionStrengths =
        laneSelectionStrengths != null && laneSelectionStrengths.isNotEmpty;

    final wall = Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: widget.height ?? MediaQuery.of(context).size.height * 0.3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widthScale =
                constraints.maxWidth / _wallData!.imageInfo.width;
            final heightScale =
                constraints.maxHeight / _wallData!.imageInfo.height;
            final scale = widthScale < heightScale ? widthScale : heightScale;
            final scaledWidth = _wallData!.imageInfo.width * scale;
            final scaledHeight = _wallData!.imageInfo.height * scale;

            return Center(
              child: SizedBox(
                width: scaledWidth,
                height: scaledHeight,
                child: Stack(
                  children: [
                    Container(
                      width: scaledWidth,
                      height: scaledHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: const DecorationImage(
                          image: AssetImage('assets/models/crux.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    ..._wallData!.shapes.map((shape) {
                      final selectionStrength =
                          laneSelectionStrengths?[shape.laneId] ??
                              (widget.selectedLaneId != null
                                  ? (widget.selectedLaneId == shape.laneId
                                      ? 1.0
                                      : 0.0)
                                  : (routeProvider.selectedLaneIds
                                          .contains(shape.laneId)
                                      ? 1.0
                                      : 0.0));
                      final isSelected = selectionStrength > 0.001;
                      final isDimmed = hasLaneSelectionStrengths ||
                              widget.selectedLaneId != null
                          ? !isSelected
                          : hasActiveFilters &&
                              !matchingLaneIds.contains(shape.laneId);
                      final dimStrength = hasLaneSelectionStrengths
                          ? 1 - selectionStrength
                          : (isDimmed ? 1.0 : 0.0);
                      return _buildLaneOverlay(
                        shape,
                        scale,
                        selectionStrength,
                        dimStrength,
                        () => _onLaneSelected(routeProvider, shape.laneId),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    if (!widget.showCard) {
      return wall;
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      clipBehavior: Clip.antiAlias,
      child: wall,
    );
  }

  Widget _buildLaneOverlay(
    LaneShape shape,
    double scale,
    double selectionStrength,
    double dimStrength,
    VoidCallback onTap,
  ) {
    // Convert polygon points to scaled coordinates
    final scaledPoints = shape.points
        .map((point) => Offset(point[0] * scale, point[1] * scale))
        .toList();

    return Positioned(
      left: shape.x1 * scale,
      top: shape.y1 * scale,
      width: shape.width * scale,
      height: shape.height * scale,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: LanePainter(
            points: scaledPoints,
            selectionStrength: selectionStrength,
            dimStrength: dimStrength,
            laneId: shape.laneId,
            offset: Offset(shape.x1 * scale, shape.y1 * scale),
          ),
          size: Size(shape.width * scale, shape.height * scale),
        ),
      ),
    );
  }

  void _onLaneSelected(RouteProvider routeProvider, int laneId) {
    final callback = widget.onLaneSelected;
    if (callback != null) {
      callback(laneId);
      return;
    }
    routeProvider.toggleLaneFilter(laneId);
  }
}

class LanePainter extends CustomPainter {
  final List<Offset> points;
  final double selectionStrength;
  final double dimStrength;
  final int laneId;
  final Offset offset;

  LanePainter({
    required this.points,
    required this.selectionStrength,
    required this.dimStrength,
    required this.laneId,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isSelected = selectionStrength > 0.001;

    // Adjust points relative to the positioned widget
    final adjustedPoints = points
        .map((point) => Offset(point.dx - offset.dx, point.dy - offset.dy))
        .toList();

    if (adjustedPoints.isNotEmpty) {
      final path = Path();
      path.moveTo(adjustedPoints.first.dx, adjustedPoints.first.dy);

      for (int i = 1; i < adjustedPoints.length; i++) {
        path.lineTo(adjustedPoints[i].dx, adjustedPoints[i].dy);
      }
      path.close();

      if (dimStrength > 0.001) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.black.withValues(
              alpha: 0.42 * dimStrength.clamp(0.0, 1.0),
            )
            ..style = PaintingStyle.fill,
        );
      }

      if (isSelected) {
        canvas
          ..drawPath(
            path,
            Paint()
              ..color = const Color(0xFFFCB900).withValues(
                alpha: 0.42 * selectionStrength,
              )
              ..style = PaintingStyle.fill,
          )
          ..drawPath(
            path,
            Paint()
              ..color = const Color(0xFFFCB900).withValues(
                alpha: selectionStrength.clamp(0.2, 1.0),
              )
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1 + selectionStrength,
          );
      } else {
        canvas.drawPath(
          path,
          Paint()
            ..color = Color.lerp(
              Colors.white.withValues(alpha: 0.3),
              Colors.grey.shade500.withValues(alpha: 0.8),
              dimStrength.clamp(0.0, 1.0),
            )!
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      // Draw lane number if selected or on hover
      if (selectionStrength >= 0.5) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: laneId.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();

        // Center the text in the lane
        final center = _getPolygonCenter(adjustedPoints);
        final textOffset = Offset(
          center.dx - textPainter.width / 2,
          center.dy - textPainter.height / 2,
        );

        textPainter.paint(canvas, textOffset);
      }
    }
  }

  Offset _getPolygonCenter(List<Offset> points) {
    double x = 0;
    double y = 0;

    for (final point in points) {
      x += point.dx;
      y += point.dy;
    }

    return Offset(x / points.length, y / points.length);
  }

  @override
  bool shouldRepaint(LanePainter oldDelegate) {
    return oldDelegate.selectionStrength != selectionStrength ||
        oldDelegate.dimStrength != dimStrength ||
        oldDelegate.points != points;
  }
}
