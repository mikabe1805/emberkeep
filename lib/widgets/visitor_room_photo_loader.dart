import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../room_photo.dart';
import '../shared_room_media.dart';

typedef VisitorRoomPhotoBytesLoader =
    Future<Uint8List> Function(String objectPath, int maxBytes);

/// The bounded, transient remote half of a photo rendered in a visitor room.
/// It keeps downloaded bytes out of the shared room map and drops late work
/// after a room/path change or disposal.
class VisitorRoomPhotoLoader extends StatefulWidget {
  const VisitorRoomPhotoLoader({
    super.key,
    required this.objectPath,
    required this.fillFrame,
    required this.alignment,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.builder,
    this.bytesLoader,
  });

  final String objectPath;
  final bool fillFrame;
  final Alignment alignment;
  final int pixelWidth;
  final int pixelHeight;
  final Widget Function(BuildContext context, RoomPhotoData? photo) builder;
  final VisitorRoomPhotoBytesLoader? bytesLoader;

  @override
  State<VisitorRoomPhotoLoader> createState() => _VisitorRoomPhotoLoaderState();
}

class _VisitorRoomPhotoLoaderState extends State<VisitorRoomPhotoLoader> {
  RoomPhotoData? _photo;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VisitorRoomPhotoLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objectPath != widget.objectPath ||
        oldWidget.fillFrame != widget.fillFrame ||
        oldWidget.alignment != widget.alignment ||
        oldWidget.pixelWidth != widget.pixelWidth ||
        oldWidget.pixelHeight != widget.pixelHeight ||
        oldWidget.bytesLoader != widget.bytesLoader) {
      _photo = null;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    try {
      final loader = widget.bytesLoader;
      final bytes = loader != null
          ? await loader(widget.objectPath, maxPublicRoomPhotoBytes)
          : await SharedRoomMediaService.instance.downloadData(
              widget.objectPath,
              maxBytes: maxPublicRoomPhotoBytes,
            );
      if (!mounted || generation != _generation) return;
      final canonical = await canonicalizeRoomPhoto(bytes);
      if (!mounted || generation != _generation) return;
      if (canonical.pixelWidth != widget.pixelWidth ||
          canonical.pixelHeight != widget.pixelHeight) {
        return;
      }
      setState(
        () => _photo = canonical.copyWith(
          fillFrame: widget.fillFrame,
          alignment: widget.alignment,
        ),
      );
    } catch (_) {
      // A visitor never sees a failure card for a private-looking room frame;
      // an unavailable shared object simply leaves that frame empty.
      if (mounted && generation == _generation) setState(() => _photo = null);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _photo);
}
