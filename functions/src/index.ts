import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {defineBoolean, defineSecret} from "firebase-functions/params";
import {onDocumentDeleted} from "firebase-functions/v2/firestore";
import {onCall} from "firebase-functions/v2/https";
import {user} from "firebase-functions/v1/auth";
import {
  reportDiscoverableSpaceHandler,
  setDiscoveryPublicNameHandler,
  type DiscoveryStore,
} from "./discovery";
import {
  publishSpaceProfileHandler,
  setCircleRelationshipHandler,
  setSpaceBlockHandler,
  type SpaceProfileStore,
} from "./space_profile";
import {
  cleanupDeletedSpaceHandler,
  type SpaceCleanupStore,
} from "./space_cleanup";
import {
  cleanupDeletedIdentityRelationshipsHandler,
  firestoreIdentityRelationshipCleanupStore,
} from "./identity_relationship_cleanup";

import {
  FirestoreCostGuard,
  FirestoreIdentityDeletionGuard,
  autocompleteHandler,
  detailsHandler,
  type PlacesDependencies,
} from "./places";
import {
  beginServiceIdentityDeletionHandler,
  FirestoreServiceIdentityDeletionTombstoneStore,
} from "./service_identity_deletion";

if (getApps().length === 0) initializeApp();

const googlePlacesApiKey = defineSecret("GOOGLE_PLACES_API_KEY");
const enforcePlacesAppCheck = defineBoolean("PLACES_ENFORCE_APP_CHECK", {
  default: false,
});
const enforceDiscoveryAppCheck = defineBoolean("DISCOVERY_ENFORCE_APP_CHECK", {
  // Discovery callables are deny-by-default. A staging deployment may opt out
  // briefly while provider metrics are being established, but production must
  // never depend on somebody remembering to flip this after names are exposed.
  default: true,
});
const discoveryPublicNamesEnabled = defineBoolean(
  "DISCOVERY_PUBLIC_NAMES_ENABLED",
  {
    // This server gate is independent of the app's build flag. Generated-only
    // discovery remains generated-only even if somebody calls the endpoint
    // directly with a valid identity and App Check token.
    default: false,
  },
);
const firestore = getFirestore();
const productionDependencies: PlacesDependencies = {
  guard: new FirestoreCostGuard(firestore),
  identityDeletion: new FirestoreIdentityDeletionGuard(firestore),
  fetch: (input, init) => globalThis.fetch(input, init),
  apiKey: () => googlePlacesApiKey.value(),
};
const identityDeletionDependencies = {
  store: new FirestoreServiceIdentityDeletionTombstoneStore(firestore),
};

export const placesAutocomplete = onCall(
  {
    secrets: [googlePlacesApiKey],
    enforceAppCheck: enforcePlacesAppCheck,
    timeoutSeconds: 15,
  },
  async (request) => autocompleteHandler(request, productionDependencies),
);

export const placesDetails = onCall(
  {
    secrets: [googlePlacesApiKey],
    enforceAppCheck: enforcePlacesAppCheck,
    timeoutSeconds: 15,
  },
  async (request) => detailsHandler(request, productionDependencies),
);

export const beginServiceIdentityDeletion = onCall(
  {
    enforceAppCheck: enforcePlacesAppCheck,
    timeoutSeconds: 15,
  },
  async (request) => beginServiceIdentityDeletionHandler(
    request,
    identityDeletionDependencies,
  ),
);

export const setDiscoveryPublicName = onCall(
  {enforceAppCheck: enforceDiscoveryAppCheck, timeoutSeconds: 15},
  async (request) => setDiscoveryPublicNameHandler(request, {
    store: firestore as unknown as DiscoveryStore,
    publicNamesEnabled: () => discoveryPublicNamesEnabled.value(),
  }),
);

export const reportDiscoverableSpace = onCall(
  {enforceAppCheck: enforceDiscoveryAppCheck, timeoutSeconds: 15},
  async (request) => reportDiscoverableSpaceHandler(request, {store: firestore as unknown as DiscoveryStore}),
);

// Profile content remains outside the generated room document. These are the
// only client entry points for publishing audience projections and recording
// relationship state used by the mutual-audience rules.
export const publishSpaceProfile = onCall(
  {enforceAppCheck: enforceDiscoveryAppCheck, timeoutSeconds: 15},
  async (request) => publishSpaceProfileHandler(request, {store: firestore as unknown as SpaceProfileStore}),
);

export const setCircleRelationship = onCall(
  {enforceAppCheck: enforceDiscoveryAppCheck, timeoutSeconds: 15},
  async (request) => setCircleRelationshipHandler(request, {store: firestore as unknown as SpaceProfileStore}),
);

export const setSpaceBlock = onCall(
  {enforceAppCheck: enforceDiscoveryAppCheck, timeoutSeconds: 15},
  async (request) => setSpaceBlockHandler(request, {store: firestore as unknown as SpaceProfileStore}),
);

// A room code is the availability anchor for both authored projections. This
// trigger removes their stored bytes even when an offline client, account
// deletion, or older build deletes the room without first calling the profile
// publisher.
export const cleanupDeletedSpace = onDocumentDeleted(
  "rooms/{code}",
  async (event) => {
    await cleanupDeletedSpaceHandler(
      event.params.code,
      firestore as unknown as SpaceCleanupStore,
      event.data?.data() ?? {},
    );
  },
);

// Room deletion deliberately preserves the opaque relationship graph: a
// keeper may stop sharing or rotate a code without losing Circle/block state.
// Auth deletion is the separate irreversible account-deletion signal, so
// remove both outgoing and incoming edges only at that boundary. This covers
// anonymous resets and password-confirmed linked-account deletion alike.
export const cleanupDeletedServiceIdentityRelationships = user().onDelete(
  async (authUser) => {
    await cleanupDeletedIdentityRelationshipsHandler(
      authUser.uid,
      firestoreIdentityRelationshipCleanupStore(firestore),
    );
  },
);
