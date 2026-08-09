import 'dart:convert';
import 'dart:io';

const _osvBatchEndpoint = 'https://api.osv.dev/v1/querybatch';

Future<void> main(List<String> args) async {
  if (args.isNotEmpty) {
    stderr.writeln('Usage: dart run tool/audit_pub_dependencies.dart');
    exitCode = 64;
    return;
  }

  try {
    final packages = await _lockedHostedPackages();
    final findings = await _queryOsv(packages);

    stdout.writeln('Locked Pub dependency audit');
    if (findings.isEmpty) {
      stdout.writeln(
        '  PASS  ${packages.length} hosted packages; '
        '0 known affecting OSV advisories',
      );
      stdout.writeln(
        '  NOTE  This checks published advisories, not the absence of '
        'undiscovered vulnerabilities.',
      );
      return;
    }

    for (final finding in findings) {
      stderr.writeln(
        '  FAIL  ${finding.package.name} ${finding.package.version}: '
        '${finding.id}',
      );
    }
    stderr.writeln(
      'FAIL: ${findings.length} known affecting OSV '
      '${findings.length == 1 ? 'advisory' : 'advisories'}.',
    );
    exitCode = 1;
  } on Object catch (error) {
    stderr.writeln('FAIL: dependency audit could not complete: $error');
    exitCode = 1;
  }
}

Future<List<_LockedPackage>> _lockedHostedPackages() async {
  final result = await Process.run(Platform.resolvedExecutable, const [
    'pub',
    'deps',
    '--json',
  ]);
  if (result.exitCode != 0) {
    throw ProcessException(
      Platform.resolvedExecutable,
      const ['pub', 'deps', '--json'],
      '${result.stderr}',
      result.exitCode,
    );
  }

  final graph = jsonDecode('${result.stdout}') as Map<String, dynamic>;
  final rawPackages = graph['packages'];
  if (rawPackages is! List<dynamic>) {
    throw const FormatException('dart pub deps returned no package list.');
  }

  final packages = <_LockedPackage>[];
  for (final raw in rawPackages) {
    if (raw is! Map<String, dynamic> || raw['source'] != 'hosted') continue;
    final name = raw['name'];
    final version = raw['version'];
    if (name is String &&
        name.isNotEmpty &&
        version is String &&
        version.isNotEmpty) {
      packages.add(_LockedPackage(name, version));
    }
  }
  packages.sort((a, b) => a.name.compareTo(b.name));
  if (packages.isEmpty) {
    throw const FormatException('No locked hosted Pub packages were found.');
  }
  return packages;
}

Future<List<_Finding>> _queryOsv(List<_LockedPackage> packages) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final request = await client
        .postUrl(Uri.parse(_osvBatchEndpoint))
        .timeout(const Duration(seconds: 20));
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode({
        'queries': [
          for (final package in packages)
            {
              'version': package.version,
              'package': {'ecosystem': 'Pub', 'name': package.name},
            },
        ],
      }),
    );

    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'OSV returned HTTP ${response.statusCode}: $body',
        uri: Uri.parse(_osvBatchEndpoint),
      );
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final rawResults = decoded['results'];
    if (rawResults is! List<dynamic> || rawResults.length != packages.length) {
      throw const FormatException(
        'OSV result count does not match the dependency query.',
      );
    }

    final findings = <_Finding>[];
    for (var index = 0; index < rawResults.length; index++) {
      final rawResult = rawResults[index];
      if (rawResult is! Map<String, dynamic>) continue;
      if (rawResult['next_page_token'] case final String token
          when token.isNotEmpty) {
        throw StateError(
          'OSV paginated ${packages[index].name}; refusing a partial audit.',
        );
      }
      final rawVulnerabilities = rawResult['vulns'];
      if (rawVulnerabilities is! List<dynamic>) continue;
      for (final rawVulnerability in rawVulnerabilities) {
        if (rawVulnerability is! Map<String, dynamic>) continue;
        final id = rawVulnerability['id'];
        if (id is String && id.isNotEmpty) {
          findings.add(_Finding(packages[index], id));
        }
      }
    }
    return findings;
  } finally {
    client.close(force: true);
  }
}

final class _LockedPackage {
  const _LockedPackage(this.name, this.version);

  final String name;
  final String version;
}

final class _Finding {
  const _Finding(this.package, this.id);

  final _LockedPackage package;
  final String id;
}
