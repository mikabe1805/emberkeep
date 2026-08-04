import 'dart:typed_data';

/// The bytes and original local filename needed to publish a device-local
/// journal photo. This value is intentionally transient: callers upload it,
/// then keep only the remote object path.
final class JournalMediaUploadData {
  const JournalMediaUploadData({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;
}

enum JournalMediaReadFailure { unavailable, invalidName, missing, unreadable }

/// A clear, platform-neutral failure from reading a stored journal photo.
final class JournalMediaReadException implements Exception {
  const JournalMediaReadException(this.failure, this.message, {this.cause});

  final JournalMediaReadFailure failure;
  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
