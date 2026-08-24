import {readFileSync} from "node:fs";

test("all discovery callables remain App Check protected", () => {
  const source = readFileSync("src/index.ts", "utf8");
  for (const callable of [
    "setDiscoveryPublicName",
    "reportDiscoverableSpace",
    "publishSpaceProfile",
    "setCircleRelationship",
    "setSpaceBlock",
  ]) {
    const start = source.indexOf(`export const ${callable} = onCall(`);
    expect(start).toBeGreaterThanOrEqual(0);
    const end = source.indexOf("\n);", start);
    const declaration = source.slice(start, end === -1 ? source.length : end);
    expect(declaration).toContain("enforceAppCheck: enforceDiscoveryAppCheck");
  }
});

test("relationship cleanup is wired to the irreversible Auth deletion boundary", () => {
  const source = readFileSync("src/index.ts", "utf8");
  const start = source.indexOf("export const cleanupDeletedServiceIdentityRelationships");
  expect(start).toBeGreaterThanOrEqual(0);
  const declaration = source.slice(start);
  expect(declaration).toContain("user().onDelete");
  expect(declaration).toContain("cleanupDeletedIdentityRelationshipsHandler");
  expect(declaration).toContain("firestoreIdentityRelationshipCleanupStore");
  expect(declaration).not.toContain("serviceIdentityDeletionTombstones");
  expect(declaration).not.toContain("rooms/{code}");
});
