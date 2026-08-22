import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {defineBoolean, defineSecret} from "firebase-functions/params";
import {onCall} from "firebase-functions/v2/https";
import {
  reportDiscoverableSpaceHandler,
  setDiscoveryPublicNameHandler,
  type DiscoveryStore,
} from "./discovery";

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
