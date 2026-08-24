import {spawnSync} from 'node:child_process';

// Keep the hosted visitor experience on the same explicitly enabled social
// capability set as the iOS release. Firebase's Windows predeploy runner treats
// equals signs in a configured command as unsafe, so pass defines directly to
// Flutter from this cross-platform wrapper instead.
const flutterArgs = [
  'build',
  'web',
  '--release',
  '--wasm',
  '--dart-define=SPACE_DISCOVERY=true',
  '--dart-define=PUBLIC_DISCOVERY_NAMES=true',
  '--dart-define=VISITOR_PROFILE_SHARING=true',
  '--dart-define=PLACE_SEARCH_APP_CHECK_WEB_SITE_KEY=6L1SoM-jCpoiyD9A99Y41P6zHtY',
];

const result = spawnSync('flutter', flutterArgs, {
  stdio: 'inherit',
  shell: process.platform === 'win32',
});

if (result.error) {
  throw result.error;
}
if (result.status !== 0) {
  process.exitCode = result.status ?? 1;
}
