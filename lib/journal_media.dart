// Journal photo storage — a thin platform facade so the web build never
// compiles dart:io / path_provider (native-only). Mirrors the repo's
// persist_web/persist_stub conditional-import pattern.
//
// The native impl copies a picked photo into the app documents dir and returns
// a RELATIVE filename (the iOS container UUID changes on reinstall, so absolute
// paths would break). Photos are device-local: text syncs in the save blob;
// photos do not follow a cloud restore — surfaced honestly in the editor.
//
// Exposes: pick(bool fromCamera) -> relative filename, delete(name),
// image(name, {maxHeight}) -> a Widget rendering the stored photo.
export 'journal_media_stub.dart'
    if (dart.library.io) 'journal_media_io.dart';
