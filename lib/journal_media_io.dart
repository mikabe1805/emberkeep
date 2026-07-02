import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const _dir = 'journal_images';
String? _docs; // cached app documents dir

Future<String?> _docsPath() async {
  if (_docs != null) return _docs;
  try {
    final d = await getApplicationDocumentsDirectory();
    return _docs = d.path;
  } catch (_) {
    return null;
  }
}

/// True when the last [pick] returned null because something went WRONG
/// (denied permission, camera error) rather than the user cancelling — lets
/// the editor say "allow access in Settings" instead of failing silently.
bool lastPickFailed = false;

/// Pick a photo, copy it into the journal-images dir, return its relative name.
Future<String?> pick(bool fromCamera) async {
  lastPickFailed = false;
  try {
    final x = await ImagePicker().pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82, // keep files small — they live on-device
    );
    if (x == null) return null; // user cancelled — not a failure
    final base = await _docsPath();
    if (base == null) {
      lastPickFailed = true;
      return null;
    }
    final dir = Directory('$base/$_dir');
    if (!await dir.exists()) await dir.create(recursive: true);
    final dot = x.name.lastIndexOf('.');
    final ext = dot >= 0 ? x.name.substring(dot) : '.jpg';
    final name = 'jimg_${DateTime.now().microsecondsSinceEpoch}$ext';
    await File(x.path).copy('${dir.path}/$name');
    return name;
  } catch (_) {
    lastPickFailed = true;
    return null;
  }
}

/// Best-effort delete of a stored photo (when its block is removed).
Future<void> delete(String name) async {
  try {
    final base = await _docsPath();
    if (base == null) return;
    final f = File('$base/$_dir/$name');
    if (await f.exists()) await f.delete();
  } catch (_) {/* best effort */}
}

/// A widget that renders the stored photo [name] (rounded, capped height).
Widget image(String name, {double maxHeight = 340}) =>
    _JournalImage(name: name, maxHeight: maxHeight);

class _JournalImage extends StatelessWidget {
  const _JournalImage({required this.name, required this.maxHeight});
  final String name;
  final double maxHeight;

  Widget _framed(String path) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Image.file(
            File(path),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              height: 110,
              alignment: Alignment.center,
              color: const Color(0x22000000),
              child: const Icon(Icons.image_not_supported_outlined,
                  color: Color(0xFF94887A)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_docs != null) return _framed('$_docs/$_dir/$name');
    return FutureBuilder<String?>(
      future: _docsPath(),
      builder: (_, snap) => snap.data == null
          ? const SizedBox(
              height: 110,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _framed('${snap.data}/$_dir/$name'),
    );
  }
}
