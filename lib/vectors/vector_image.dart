// A compact, null-safe SVG path renderer for the public-domain style chess
// vectors (original artwork from Wikimedia Commons, "Cburnett" piece set).
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Drawing parameters for each element of the vector.
class DrawingParameters {
  Color? fillColor;
  Color? strokeColor;
  double? strokeWidth;
  StrokeCap? strokeLineCap;
  StrokeJoin? strokeLineJoin;
  double? strokeLineMiterLimit;
  Offset? translate;
  Float64List? transformMatrix;

  DrawingParameters({
    this.fillColor,
    this.strokeColor,
    this.strokeWidth,
    this.strokeLineCap,
    this.strokeLineJoin,
    this.strokeLineMiterLimit,
    this.translate,
    List<double>? transformMatrixValues,
  }) : transformMatrix = _matrix(transformMatrixValues);

  static Float64List? _matrix(List<double>? v) {
    if (v == null) return null;
    return Float64List.fromList(<double>[
      v[0], v[1], 0, 0,
      v[2], v[3], 0, 0,
      0, 0, 1, 0,
      v[4], v[5], 0, 1,
    ]);
  }
}

DrawingParameters mergeDrawingParameters(
    DrawingParameters? child, DrawingParameters? parent) {
  return DrawingParameters(
    fillColor: child?.fillColor ?? parent?.fillColor,
    strokeColor: child?.strokeColor ?? parent?.strokeColor,
    strokeWidth: child?.strokeWidth ?? parent?.strokeWidth,
    strokeLineCap: child?.strokeLineCap ?? parent?.strokeLineCap,
    strokeLineJoin: child?.strokeLineJoin ?? parent?.strokeLineJoin,
    strokeLineMiterLimit:
        child?.strokeLineMiterLimit ?? parent?.strokeLineMiterLimit,
    translate: child?.translate ?? parent?.translate,
    transformMatrixValues: null,
  )..transformMatrix = child?.transformMatrix ?? parent?.transformMatrix;
}

/// Base class for a painted piece.
abstract class VectorBase extends CustomPaint {
  VectorBase({
    super.key,
    required VectorImagePainter painter,
    required double baseImageSize,
    required double requestSize,
  }) : super(
          painter: VectorImagePainter(
            vectorDefinition: painter.vectorDefinition,
            baseImageSize: baseImageSize,
          ),
          size: Size.square(requestSize),
        );
}

/// Paints a list of vector elements inside the given size.
class VectorImagePainter extends CustomPainter {
  final List<VectorDrawableElement> vectorDefinition;
  final double baseImageSize;
  final bool shadow;

  VectorImagePainter({
    required this.vectorDefinition,
    this.baseImageSize = 45.0,
    this.shadow = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / baseImageSize, size.height / baseImageSize);
    for (final element in vectorDefinition) {
      element.paintIntoCanvas(canvas, null, shadow);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant VectorImagePainter oldDelegate) =>
      oldDelegate.vectorDefinition != vectorDefinition ||
      oldDelegate.baseImageSize != baseImageSize;
}

/// A drawable element of the vector.
abstract class VectorDrawableElement {
  final DrawingParameters? drawingParameters;
  VectorDrawableElement(this.drawingParameters);

  void paintIntoCanvas(
      Canvas targetCanvas, DrawingParameters? parent, bool shadow);
}

class VectorImageGroup extends VectorDrawableElement {
  final List<VectorDrawableElement> children;

  VectorImageGroup({required this.children, DrawingParameters? drawingParameters})
      : super(drawingParameters);

  @override
  void paintIntoCanvas(
      Canvas targetCanvas, DrawingParameters? parent, bool shadow) {
    final used = mergeDrawingParameters(drawingParameters, parent);
    for (final child in children) {
      child.paintIntoCanvas(targetCanvas, used, shadow);
    }
  }
}

/// A simple circle element.
class VectorCircle extends VectorDrawableElement {
  final Offset position;
  final double radius;

  VectorCircle({
    required this.position,
    required this.radius,
    DrawingParameters? drawingParameters,
  }) : super(drawingParameters);

  @override
  void paintIntoCanvas(
      Canvas targetCanvas, DrawingParameters? parent, bool shadow) {
    final used = mergeDrawingParameters(drawingParameters, parent);
    final path = Path()
      ..addOval(Rect.fromCircle(center: position, radius: radius));

    if (used.fillColor != null) {
      if (shadow) {
        targetCanvas.drawPath(
          path.shift(const Offset(0.5, 1.0)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
        );
      }
      targetCanvas.drawPath(path, Paint()..color = used.fillColor!);
    }
    if (used.strokeColor != null && (used.strokeWidth ?? 0) > 0) {
      targetCanvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = used.strokeColor!
          ..strokeWidth = used.strokeWidth!,
      );
    }
  }
}

/// A path element (`<path d="...">`).
class VectorImagePathDefinition extends VectorDrawableElement {
  final List<PathElement> pathElements;

  VectorImagePathDefinition({
    required String path,
    DrawingParameters? drawingParameters,
  })  : pathElements = parsePath(path),
        super(drawingParameters);

  @override
  void paintIntoCanvas(
      Canvas targetCanvas, DrawingParameters? parent, bool shadow) {
    final used = mergeDrawingParameters(drawingParameters, parent);

    targetCanvas.save();
    final matrix = drawingParameters?.transformMatrix;
    if (matrix != null) targetCanvas.transform(matrix);
    final translate = drawingParameters?.translate;
    if (translate != null) {
      targetCanvas.translate(translate.dx, translate.dy);
    }

    final path = Path();
    for (final element in pathElements) {
      element.addToPath(path);
    }

    if (used.fillColor != null) {
      if (shadow) {
        targetCanvas.drawPath(
          path.shift(const Offset(0.5, 1.0)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.14)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.1),
        );
      }
      targetCanvas.drawPath(path, Paint()..color = used.fillColor!);
    }

    if (used.strokeColor != null) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..color = used.strokeColor!
        ..strokeWidth = used.strokeWidth ?? 1.0;
      if (used.strokeLineCap != null) paint.strokeCap = used.strokeLineCap!;
      if (used.strokeLineJoin != null) paint.strokeJoin = used.strokeLineJoin!;
      if (used.strokeLineMiterLimit != null) {
        paint.strokeMiterLimit = used.strokeLineMiterLimit!;
      }
      targetCanvas.drawPath(path, paint);
    }

    targetCanvas.restore();
  }
}

abstract class PathElement {
  void addToPath(Path path);
}

class MoveElement extends PathElement {
  final bool relative;
  final Offset moveParams;
  MoveElement({required this.relative, required this.moveParams});

  @override
  void addToPath(Path path) {
    if (relative) {
      path.relativeMoveTo(moveParams.dx, moveParams.dy);
    } else {
      path.moveTo(moveParams.dx, moveParams.dy);
    }
  }
}

class CloseElement extends PathElement {
  @override
  void addToPath(Path path) => path.close();
}

class LineElement extends PathElement {
  final bool relative;
  final Offset lineParams;
  LineElement({required this.relative, required this.lineParams});

  @override
  void addToPath(Path path) {
    if (relative) {
      path.relativeLineTo(lineParams.dx, lineParams.dy);
    } else {
      path.lineTo(lineParams.dx, lineParams.dy);
    }
  }
}

class CubicCurveElement extends PathElement {
  final bool relative;
  final Offset firstControlPoint;
  final Offset secondControlPoint;
  final Offset endPoint;

  CubicCurveElement({
    required this.relative,
    required this.firstControlPoint,
    required this.secondControlPoint,
    required this.endPoint,
  });

  @override
  void addToPath(Path path) {
    if (relative) {
      path.relativeCubicTo(
        firstControlPoint.dx,
        firstControlPoint.dy,
        secondControlPoint.dx,
        secondControlPoint.dy,
        endPoint.dx,
        endPoint.dy,
      );
    } else {
      path.cubicTo(
        firstControlPoint.dx,
        firstControlPoint.dy,
        secondControlPoint.dx,
        secondControlPoint.dy,
        endPoint.dx,
        endPoint.dy,
      );
    }
  }
}

class ArcElement extends PathElement {
  final bool relative;
  final Offset radius;
  final double xAxisRotation;
  final Offset center;

  ArcElement({
    required this.relative,
    required this.radius,
    required this.xAxisRotation,
    required this.center,
  });

  @override
  void addToPath(Path path) {
    if (relative) {
      path.relativeArcToPoint(
        center,
        rotation: xAxisRotation,
        radius: Radius.elliptical(radius.dx, radius.dy),
      );
    } else {
      path.arcToPoint(
        center,
        rotation: xAxisRotation,
        radius: Radius.elliptical(radius.dx, radius.dy),
      );
    }
  }
}

/// Parses a subset of SVG path syntax (M/L/C/A/Z, absolute and relative).
List<PathElement> parsePath(String pathStr) {
  const value = r'(-?\d+(?:\.\d+)?)';
  const sep = r'(?:\s+|,)';
  final moveRe = RegExp('^(M|m)$sep$value$sep$value');
  final lineRe = RegExp('^(L|l)$sep$value$sep$value');
  final cubicRe = RegExp('^(C|c)$sep$value$sep$value$sep$value$sep$value'
      '$sep$value$sep$value');
  final arcRe = RegExp('^(A|a)$sep$value$sep$value$sep$value$sep$value'
      '$sep$value$sep$value$sep$value');
  final closeRe = RegExp('^(z|Z)');

  final result = <PathElement>[];
  var remaining = pathStr.trim();

  while (remaining.isNotEmpty) {
    var match = moveRe.firstMatch(remaining);
    if (match != null) {
      final rel = match.group(1) == match.group(1)!.toLowerCase();
      result.add(MoveElement(
        relative: rel,
        moveParams: Offset(
            double.parse(match.group(2)!), double.parse(match.group(3)!)),
      ));
      remaining = remaining.substring(match.end).trim();
      continue;
    }
    match = lineRe.firstMatch(remaining);
    if (match != null) {
      final rel = match.group(1) == match.group(1)!.toLowerCase();
      result.add(LineElement(
        relative: rel,
        lineParams: Offset(
            double.parse(match.group(2)!), double.parse(match.group(3)!)),
      ));
      remaining = remaining.substring(match.end).trim();
      continue;
    }
    match = cubicRe.firstMatch(remaining);
    if (match != null) {
      final rel = match.group(1) == match.group(1)!.toLowerCase();
      result.add(CubicCurveElement(
        relative: rel,
        firstControlPoint: Offset(
            double.parse(match.group(2)!), double.parse(match.group(3)!)),
        secondControlPoint: Offset(
            double.parse(match.group(4)!), double.parse(match.group(5)!)),
        endPoint: Offset(
            double.parse(match.group(6)!), double.parse(match.group(7)!)),
      ));
      remaining = remaining.substring(match.end).trim();
      continue;
    }
    match = arcRe.firstMatch(remaining);
    if (match != null) {
      final rel = match.group(1) == match.group(1)!.toLowerCase();
      result.add(ArcElement(
        relative: rel,
        radius: Offset(
            double.parse(match.group(2)!), double.parse(match.group(3)!)),
        xAxisRotation: double.parse(match.group(4)!),
        center: Offset(
            double.parse(match.group(7)!), double.parse(match.group(8)!)),
      ));
      remaining = remaining.substring(match.end).trim();
      continue;
    }
    match = closeRe.firstMatch(remaining);
    if (match != null) {
      result.add(CloseElement());
      remaining = remaining.substring(match.end).trim();
      continue;
    }
    throw FormatException('Unrecognized SVG path segment', remaining);
  }
  return result;
}
