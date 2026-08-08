import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'journal_media_upload.dart';

const _dir = 'journal_images';
String? _docs; // cached app documents dir
Future<String?>? _docsLookup;

Future<String?> _docsPath() {
  if (_docs != null) return Future.value(_docs);
  return _docsLookup ??= _resolveDocsPath();
}

Future<String?> _resolveDocsPath() async {
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

Future<String?> _storePicked(XFile x, {int suffix = 0}) async {
  final base = await _docsPath();
  if (base == null) return null;
  final dir = Directory('$base/$_dir');
  if (!await dir.exists()) await dir.create(recursive: true);
  final dot = x.name.lastIndexOf('.');
  final ext = dot >= 0 ? x.name.substring(dot) : '.jpg';
  final name = 'jimg_${DateTime.now().microsecondsSinceEpoch}_$suffix$ext';
  await File(x.path).copy('${dir.path}/$name');
  return name;
}

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
    final stored = await _storePicked(x);
    if (stored == null) {
      lastPickFailed = true;
      return null;
    }
    return stored;
  } catch (_) {
    lastPickFailed = true;
    return null;
  }
}

/// Pick several library photos in one trip and copy them into the journal in
/// the order the picker returned them. Camera capture remains single-photo.
Future<List<String>> pickMany() async {
  lastPickFailed = false;
  try {
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (picked.isEmpty) return const [];
    final stored = <String>[];
    for (var i = 0; i < picked.length && i < 12; i++) {
      final name = await _storePicked(picked[i], suffix: i);
      if (name == null) {
        lastPickFailed = true;
        continue;
      }
      stored.add(name);
    }
    return stored;
  } catch (_) {
    lastPickFailed = true;
    return const [];
  }
}

/// Android may reclaim the app while its photo picker is open in a separate
/// process; the pick then completes into the void and the person's photo
/// silently never lands ("photos sometimes don't save"). The platform hands
/// those files back on the next launch through retrieveLostData — store them
/// like any pick so the editor can put them where they were headed.
Future<List<String>> recoverLost() async {
  try {
    final lost = await ImagePicker().retrieveLostData();
    if (lost.isEmpty) return const [];
    final files = lost.files ?? [if (lost.file != null) lost.file!];
    final stored = <String>[];
    for (var i = 0; i < files.length && i < 12; i++) {
      final name = await _storePicked(files[i], suffix: i);
      if (name != null) stored.add(name);
    }
    return stored;
  } catch (_) {
    return const [];
  }
}

bool _isSafeStoredName(String name) =>
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,254}$').hasMatch(name) &&
    name != '.' &&
    name != '..';

/// Reads one app-owned journal image for an explicit remote upload.
///
/// Only filenames produced by this module are accepted; path fragments are
/// rejected before touching disk so a shared-room action cannot read an
/// arbitrary file from the device.
Future<JournalMediaUploadData> readForUpload(String name) async {
  if (!_isSafeStoredName(name)) {
    throw const JournalMediaReadException(
      JournalMediaReadFailure.invalidName,
      'That local photo name is not valid.',
    );
  }

  final base = await _docsPath();
  if (base == null) {
    throw const JournalMediaReadException(
      JournalMediaReadFailure.unavailable,
      'Local photo storage is unavailable on this device.',
    );
  }

  final file = File('$base/$_dir/$name');
  try {
    if (!await file.exists()) {
      throw JournalMediaReadException(
        JournalMediaReadFailure.missing,
        'The selected photo is no longer on this device.',
      );
    }
    return JournalMediaUploadData(
      filename: name,
      bytes: await file.readAsBytes(),
    );
  } on JournalMediaReadException {
    rethrow;
  } catch (error) {
    throw JournalMediaReadException(
      JournalMediaReadFailure.unreadable,
      'The selected photo could not be read.',
      cause: error,
    );
  }
}

/// Best-effort delete of a stored photo (when its block is removed).
Future<void> delete(String name) async {
  try {
    final base = await _docsPath();
    if (base == null) return;
    final f = File('$base/$_dir/$name');
    if (await f.exists()) await f.delete();
  } catch (_) {
    /* best effort */
  }
}

/// Wipe EVERY journal photo — called from "Start over" so a reset really
/// erases the person's images too (they'd otherwise sit orphaned on disk
/// forever, a storage leak and a quiet privacy breach of "reset means erase
/// me"). Best-effort; a missing dir is already the goal.
Future<void> clearAll() async {
  try {
    final base = await _docsPath();
    if (base == null) return;
    final dir = Directory('$base/$_dir');
    if (await dir.exists()) await dir.delete(recursive: true);
  } catch (_) {
    /* best effort */
  }
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
        errorBuilder: (_, _, _) => _missing(),
      ),
    ),
  );

  // A missing photo (most often after a cloud restore on a NEW device — photos
  // are device-local, they don't ride the save blob) shouldn't read as a
  // broken app. A warm parchment card that says so plainly, in the app's own
  // voice, keeps a restored journal feeling whole rather than damaged.
  Widget _missing() {
    final compact = maxHeight < 104;
    return Container(
      height: compact ? maxHeight : 128,
      alignment: Alignment.center,
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF34281F), Color(0xFF281E17)],
        ),
        borderRadius: BorderRadius.circular(compact ? 8 : 14),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: compact
          ? Semantics(
              label: 'This photo stayed on your old device',
              child: Icon(
                Icons.photo_outlined,
                size: maxHeight < 60 ? 18 : 22,
                color: const Color(0xFFB9A488),
              ),
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_outlined, size: 22, color: Color(0xFFB9A488)),
                SizedBox(height: 8),
                Text(
                  'This photo stayed on your old device',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: Color(0xFFB9A488),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _loading() => Container(
    height: maxHeight < 104 ? maxHeight : 128,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF34281F), Color(0xFF281E17)],
      ),
      borderRadius: BorderRadius.circular(maxHeight < 104 ? 8 : 14),
      border: Border.all(color: const Color(0x22FFFFFF)),
    ),
    child: const Icon(Icons.photo_outlined, size: 22, color: Color(0xFFB9A488)),
  );

  @override
  Widget build(BuildContext context) {
    if (_docs != null) return _framed('$_docs/$_dir/$name');
    return FutureBuilder<String?>(
      future: _docsPath(),
      builder: (_, snap) => snap.connectionState != ConnectionState.done
          ? _loading()
          : snap.data == null
          ? _missing()
          : _framed('${snap.data}/$_dir/$name'),
    );
  }
}
