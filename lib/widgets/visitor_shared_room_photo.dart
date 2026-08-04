import 'package:flutter/material.dart';

import '../shared_room_media.dart';
import '../tokens.dart';

typedef VisitorPhotoUrlLoader = Future<String> Function(String objectPath);

/// Renders one validated remote visitor photo without putting its URL in app
/// state. The Storage URL is resolved only for the lifetime of this widget.
class VisitorSharedRoomPhoto extends StatefulWidget {
  const VisitorSharedRoomPhoto({
    super.key,
    required this.objectPath,
    this.semanticLabel = 'Shared room photo',
    this.height = 220,
    this.borderRadius = 18,
    this.fit = BoxFit.cover,
    this.urlLoader,
  });

  final String objectPath;
  final String semanticLabel;
  final double height;
  final double borderRadius;
  final BoxFit fit;
  final VisitorPhotoUrlLoader? urlLoader;

  @override
  State<VisitorSharedRoomPhoto> createState() => _VisitorSharedRoomPhotoState();
}

class _VisitorSharedRoomPhotoState extends State<VisitorSharedRoomPhoto> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = _load();
  }

  @override
  void didUpdateWidget(covariant VisitorSharedRoomPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.objectPath != oldWidget.objectPath ||
        widget.urlLoader != oldWidget.urlLoader) {
      _url = _load();
    }
  }

  Future<String> _load() =>
      (widget.urlLoader ?? SharedRoomMediaService.instance.downloadUrl)(
        widget.objectPath,
      );

  Widget _frame(Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(widget.borderRadius),
    child: SizedBox(
      width: double.infinity,
      height: widget.height,
      child: child,
    ),
  );

  Widget _placeholder({required bool failed}) => _frame(
    DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.card,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Palette.glassTop, Palette.cardGlass],
        ),
        border: Border.all(color: Palette.glassEdge),
      ),
      child: Center(
        child: failed
            ? widget.height < 104
                  ? const Icon(
                      Icons.photo_outlined,
                      color: Palette.textLo,
                      size: 24,
                    )
                  : const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.photo_outlined,
                          color: Palette.textLo,
                          size: 24,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Photo unavailable',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Palette.textLo,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    )
            : const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Palette.xp,
                ),
              ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel,
    image: true,
    child: FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _placeholder(failed: true);
        final url = snapshot.data;
        if (url == null) return _placeholder(failed: false);
        return _frame(
          Image.network(
            url,
            fit: widget.fit,
            excludeFromSemantics: true,
            errorBuilder: (context, error, stackTrace) =>
                _placeholder(failed: true),
          ),
        );
      },
    ),
  );
}
