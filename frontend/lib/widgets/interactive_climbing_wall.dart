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
                          final paintedSelectionStrength =
                              transition == null ? selectionStrength : 0.0;
                          final isDimmed =
                              widget.laneSelectionStrengths != null ||
                                      widget.selectedLaneId != null
                                  ? !isSelected
                                  : hasActiveFilters &&
                                      !matchingLaneIds.contains(shape.laneId);
                          return _buildLaneOverlay(
                            shape,
                            scale,
                            paintedSelectionStrength,
                            isDimmed,
                            () => _onLaneSelected(routeProvider, shape.laneId),
                          );
                        }),
                        if (transition != null)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: MorphingLanePainter(
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
    bool isDimmed,
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
            isDimmed: isDimmed,
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

class MorphingLanePainter extends CustomPainter {
  static const _sampleCount = 48;

  final LaneShape from;
  final LaneShape to;
  final double progress;
  final double scale;

  MorphingLanePainter({
    required this.from,
    required this.to,
    required this.progress,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fromPoints = _samplePolygon(from);
    final toPoints = _samplePolygon(to);
    final points = List<Offset>.generate(
      _sampleCount,
      (index) => Offset.lerp(
        fromPoints[index],
        toPoints[index],
        progress,
      )!,
    );
    if (points.isEmpty) {
      return;
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();

    final glowPaint = Paint()
      ..color = const Color(0xFFFCB900).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final fillPaint = Paint()
      ..color = const Color(0xFFFCB900).withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = const Color(0xFFFCB900)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas
      ..drawPath(path, glowPaint)
      ..drawPath(path, fillPaint)
      ..drawPath(path, borderPaint);

    final center = points.fold<Offset>(
          Offset.zero,
          (sum, point) => sum + point,
        ) /
        points.length.toDouble();
    final laneId = progress < 0.5 ? from.laneId : to.laneId;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$laneId',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(color: Colors.black, offset: Offset(1, 1), blurRadius: 2),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  List<Offset> _samplePolygon(LaneShape shape) {
    var points = shape.points
        .map((point) => Offset(point[0] * scale, point[1] * scale))
        .toList();
    if (points.length < 2) {
      return List.filled(
        _sampleCount,
        points.isEmpty ? Offset.zero : points.first,
      );
    }

    if (_signedArea(points) < 0) {
      points = points.reversed.toList();
    }
    points = _rotateToTop(points);

    final lengths = <double>[0];
    var perimeter = 0.0;
    for (var index = 0; index < points.length; index++) {
      perimeter +=
          (points[(index + 1) % points.length] - points[index]).distance;
      lengths.add(perimeter);
    }
    if (perimeter == 0) {
      return List.filled(_sampleCount, points.first);
    }

    return List.generate(_sampleCount, (sampleIndex) {
      final target = perimeter * sampleIndex / _sampleCount;
      var segment = 0;
      while (segment < points.length - 1 && lengths[segment + 1] < target) {
        segment++;
      }
      final segmentLength = lengths[segment + 1] - lengths[segment];
      final segmentProgress = segmentLength == 0
          ? 0.0
          : (target - lengths[segment]) / segmentLength;
      return Offset.lerp(
        points[segment],
        points[(segment + 1) % points.length],
        segmentProgress,
      )!;
    });
  }

  List<Offset> _rotateToTop(List<Offset> points) {
    var anchorIndex = 0;
    for (var index = 1; index < points.length; index++) {
      final candidate = points[index];
      final anchor = points[anchorIndex];
      if (candidate.dy < anchor.dy ||
          (candidate.dy == anchor.dy && candidate.dx < anchor.dx)) {
        anchorIndex = index;
      }
    }
    return [
      ...points.skip(anchorIndex),
      ...points.take(anchorIndex),
    ];
  }

  double _signedArea(List<Offset> points) {
    var area = 0.0;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      area += current.dx * next.dy - next.dx * current.dy;
    }
    return area / 2;
  }

  @override
  bool shouldRepaint(covariant MorphingLanePainter oldDelegate) {
    return oldDelegate.from != from ||
        oldDelegate.to != to ||
        oldDelegate.progress != progress ||
        oldDelegate.scale != scale;
  }
}

class LanePainter extends CustomPainter {
  final List<Offset> points;
  final double selectionStrength;
  final bool isDimmed;
  final int laneId;
  final Offset offset;

  LanePainter({
    required this.points,
    required this.selectionStrength,
    required this.isDimmed,
    required this.laneId,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isSelected = selectionStrength > 0.001;
    final dimmedOpacity = isSelected ? 0.0 : 0.42;

    final paint = Paint()
      ..color = isSelected
          ? const Color(0xFFFCB900).withValues(
              alpha: 0.42 * selectionStrength,
            )
          : isDimmed
              ? Colors.black.withValues(alpha: dimmedOpacity)
              : Colors.transparent
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isSelected
          ? const Color(0xFFFCB900).withValues(
              alpha: selectionStrength.clamp(0.2, 1.0),
            )
          : isDimmed
              ? Colors.grey.shade500.withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1 + selectionStrength : 1;

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

      // Fill the polygon
      canvas.drawPath(path, paint);

      // Draw the border
      canvas.drawPath(path, borderPaint);

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
        oldDelegate.isDimmed != isDimmed ||
        oldDelegate.points != points;
  }
}
