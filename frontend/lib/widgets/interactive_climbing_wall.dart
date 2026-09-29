import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/climbing_wall_models.dart';
import '../providers/route_provider.dart';
import '../services/climbing_wall_service.dart';

class InteractiveClimbingWall extends StatefulWidget {
  final ValueChanged<int>? onLaneSelected;
  final int? selectedLaneId;
  final Map<int, double>? laneSelectionStrengths;
  final double? height;
  final bool showCard;

  const InteractiveClimbingWall({
    super.key,
    this.onLaneSelected,
    this.selectedLaneId,
    this.laneSelectionStrengths,
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
        final hasActiveFilters = routeProvider.hasActiveFilters;
        final matchingLaneIds = hasActiveFilters
            ? routeProvider.routes.map((route) => route.lane).toSet()
            : <int>{};

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
                final scale =
                    widthScale < heightScale ? widthScale : heightScale;
                final scaledWidth = _wallData!.imageInfo.width * scale;
                final scaledHeight = _wallData!.imageInfo.height * scale;
                final transition = _laneTransition();

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
                              widget.laneSelectionStrengths?[shape.laneId] ??
                                  (widget.selectedLaneId != null
                                      ? (widget.selectedLaneId == shape.laneId
                                          ? 1.0
                                          : 0.0)
                                      : (routeProvider.selectedLaneIds
                                              .contains(shape.laneId)
                                          ? 1.0
                                          : 0.0));
                          final isSelected = selectionStrength > 0.001;
                          final isDimmed =
                              widget.laneSelectionStrengths != null ||
                                      widget.selectedLaneId != null
                                  ? !isSelected
                                  : hasActiveFilters &&
                                      !matchingLaneIds.contains(shape.laneId);
                          final dimStrength =
                              widget.laneSelectionStrengths != null
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
                        if (transition != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: LaneRailTransitionPainter(
                                  from: transition.from,
                                  to: transition.to,
                                  progress: transition.progress,
                                  scale: scale,
                                ),
                              ),
                            ),
                          ),
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
      },
    );
  }

  _LaneTransition? _laneTransition() {
    final strengths = widget.laneSelectionStrengths;
    if (strengths == null || _wallData == null) {
      return null;
    }

    final activeEntries =
        strengths.entries.where((entry) => entry.value > 0.001).toList();
    if (activeEntries.length != 2) {
      return null;
    }

    LaneShape? shapeFor(int laneId) {
      for (final shape in _wallData!.shapes) {
        if (shape.laneId == laneId) {
          return shape;
        }
      }
      return null;
    }

    final from = shapeFor(activeEntries.first.key);
    final to = shapeFor(activeEntries.last.key);
    if (from == null || to == null) {
      return null;
    }

    return _LaneTransition(
      from: from,
      to: to,
      progress: activeEntries.last.value.clamp(0.0, 1.0),
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

class _LaneTransition {
  final LaneShape from;
  final LaneShape to;
  final double progress;

  const _LaneTransition({
    required this.from,
    required this.to,
    required this.progress,
  });
}

class LaneRailTransitionPainter extends CustomPainter {
  final LaneShape from;
  final LaneShape to;
  final double progress;
  final double scale;

  LaneRailTransitionPainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final start = _shapeCenter(from);
    final end = _shapeCenter(to);
    final distance = (end - start).distance;
    final control = Offset(
      (start.dx + end.dx) / 2,
      (start.dy + end.dy) / 2 - (18 + distance * 0.08),
    );
    final rail = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas
      ..drawPath(
        rail,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawPath(
        rail,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );

    final metric = rail.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..color = const Color(0xFFFCB900)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final inverseProgress = 1 - progress;
    final marker = Offset(
      inverseProgress * inverseProgress * start.dx +
          2 * inverseProgress * progress * control.dx +
          progress * progress * end.dx,
      inverseProgress * inverseProgress * start.dy +
          2 * inverseProgress * progress * control.dy +
          progress * progress * end.dy,
    );
    canvas
      ..drawCircle(
        marker,
        12,
        Paint()
          ..color = const Color(0xFFFCB900).withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawCircle(marker, 7, Paint()..color = const Color(0xFFFCB900))
      ..drawCircle(
        marker,
        3,
        Paint()..color = Colors.white.withValues(alpha: 0.92),
      );
  }

  Offset _shapeCenter(LaneShape shape) {
    if (shape.points.isEmpty) {
      return Offset(
        (shape.x1 + shape.x2) * scale / 2,
        (shape.y1 + shape.y2) * scale / 2,
      );
    }
    final total = shape.points.fold<Offset>(
      Offset.zero,
      (sum, point) => sum + Offset(point[0] * scale, point[1] * scale),
    );
    return total / shape.points.length.toDouble();
  }

  @override
  bool shouldRepaint(covariant LaneRailTransitionPainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.progress != progress ||
        oldDelegate.scale != scale;
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
