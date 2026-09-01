import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../room_photo.dart';

/// The clear chimney face above each authored mantel, in source coordinates.
/// These are room surfaces, never positions relative to the phone screen.
Rect roomPhotoArea(String? roomId) => switch (roomId) {
  'wall_walnut' => const Rect.fromLTWH(.770, .090, .142, .166),
  'wall_atelier' => const Rect.fromLTWH(.744, .100, .188, .154),
  'wall_rain' => const Rect.fromLTWH(.745, .100, .188, .144),
  _ => const Rect.fromLTWH(.744, .100, .188, .140),
};

/// Portraits keep a portrait frame; very wide/tall photos can be shown whole
/// against the mat instead of having their subjects silently cropped away.
double roomPhotoFrameAspect(RoomPhotoData photo) {
  final aspect = photo.pixelWidth / photo.pixelHeight;
  if (aspect >= .88 && aspect <= 1.12) return 1;
  return aspect < 1 ? .75 : 1.5;
}

/// The photograph's visible aperture, after the rails and mat. Crop controls
/// use this exact opening rather than the slightly wider outer frame ratio.
Rect roomPhotoImageWindow(Rect outer) =>
    outer.deflate(outer.shortestSide * .047 * 1.96);

double roomPhotoImageAspect(RoomPhotoData photo) {
  final aperture = roomPhotoImageWindow(
    Rect.fromLTWH(0, 0, roomPhotoFrameAspect(photo), 1),
  );
  return aperture.width / aperture.height;
}

Rect roomPhotoFrameRect(Size sceneSize, Rect area, RoomPhotoData photo) {
  final available = Rect.fromLTWH(
    area.left * sceneSize.width,
    area.top * sceneSize.height,
    area.width * sceneSize.width,
    area.height * sceneSize.height,
  );
  final aspect = roomPhotoFrameAspect(photo);
  final fitted = applyBoxFit(BoxFit.contain, Size(aspect, 1), available.size);
  return Alignment.center.inscribe(fitted.destination, available);
}

/// Shares the room's exact source crop, overscan, and camera transform. Public
/// callers never provide [photo] or its decoded image to the room renderer.
void paintRegisteredRoomPhoto(
  Canvas canvas, {
  required ui.Image image,
  required RoomPhotoData photo,
  required Size sceneSize,
  required Rect area,
  required Rect sourceCrop,
  required Rect destination,
  Offset shift = Offset.zero,
  bool softened = false,
  double sourceBlurSigma = 18,
}) {
  final frame = roomPhotoFrameRect(sceneSize, area, photo);
  canvas.save();
  canvas.translate(destination.left + shift.dx, destination.top + shift.dy);
  canvas.scale(
    destination.width / sourceCrop.width,
    destination.height / sourceCrop.height,
  );
  canvas.translate(-sourceCrop.left, -sourceCrop.top);
  if (softened) {
    // Only this small, user-owned surface needs dynamic softening. The room
    // itself still uses its precomputed layers, with the same camera geometry.
    canvas.saveLayer(
      frame.inflate(sourceBlurSigma * 3),
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sourceBlurSigma,
          sigmaY: sourceBlurSigma,
        ),
    );
  }
  _paintFrame(canvas, frame, image, photo);
  if (softened) canvas.restore();
  canvas.restore();
}

void _paintFrame(
  Canvas canvas,
  Rect outer,
  ui.Image image,
  RoomPhotoData photo,
) {
  final rail = outer.shortestSide * .047;
  final inner = outer.deflate(rail);
  final mat = inner.deflate(rail * .36);
  final imageWindow = roomPhotoImageWindow(outer);

  canvas.drawRect(
    outer.translate(rail * .24, rail * .46),
    Paint()
      ..color = const Color(0x77301C11)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, rail * .64),
  );
  canvas.drawRect(outer, Paint()..color = const Color(0xFF382418));

  // Four mitred rails, with one light direction shared by the room's wood.
  void railPlane(Offset a, Offset b, Offset c, Offset d, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(c.dx, c.dy)
        ..lineTo(d.dx, d.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  railPlane(
    outer.topLeft,
    outer.topRight,
    inner.topRight,
    inner.topLeft,
    const Color(0xFF846241),
  );
  railPlane(
    outer.topLeft,
    inner.topLeft,
    inner.bottomLeft,
    outer.bottomLeft,
    const Color(0xFF65482F),
  );
  railPlane(
    inner.topRight,
    outer.topRight,
    outer.bottomRight,
    inner.bottomRight,
    const Color(0xFF3C281C),
  );
  railPlane(
    inner.bottomLeft,
    inner.bottomRight,
    outer.bottomRight,
    outer.bottomLeft,
    const Color(0xFF503722),
  );
  canvas.drawRect(
    outer.deflate(rail * .19),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rail * .09
      ..color = const Color(0x7CB99565),
  );
  canvas.drawRect(inner, Paint()..color = const Color(0xFF261A13));
  canvas.drawRect(mat, Paint()..color = const Color(0xFFB7A78A));
  canvas.drawRect(
    imageWindow.inflate(rail * .13),
    Paint()..color = const Color(0xFF73654F),
  );

  final imageSize = Size(image.width.toDouble(), image.height.toDouble());
  final fitted = applyBoxFit(
    photo.fillFrame ? BoxFit.cover : BoxFit.contain,
    imageSize,
    imageWindow.size,
  );
  final source = photo.alignment.inscribe(
    fitted.source,
    Offset.zero & imageSize,
  );
  final target = Alignment.center.inscribe(fitted.destination, imageWindow);
  canvas.save();
  canvas.clipRect(imageWindow);
  canvas.drawRect(imageWindow, Paint()..color = const Color(0xFFB7A78A));
  canvas.drawImageRect(
    image,
    source,
    target,
    Paint()..filterQuality = FilterQuality.medium,
  );
  // A restrained room-light veil, not an artistic filter on the person's
  // photo. Faces and color remain recognizable behind the frame's glazing.
  canvas.drawRect(imageWindow, Paint()..color = const Color(0x18261910));
  canvas.drawPath(
    Path()
      ..moveTo(imageWindow.left, imageWindow.top)
      ..lineTo(imageWindow.right, imageWindow.top)
      ..lineTo(imageWindow.left, imageWindow.bottom)
      ..close(),
    Paint()..color = const Color(0x08FFE9C7),
  );
  canvas.restore();
}
