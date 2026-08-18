import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {defineBoolean, defineSecret} from "firebase-functions/params";
import {onCall} from "firebase-functions/v2/https";

import {
  FirestoreCostGuard,
  autocompleteHandler,
  detailsHandler,
  type PlacesDependencies,
} from "./places";

if (getApps().length === 0) initializeApp();

const googlePlacesApiKey = defineSecret("GOOGLE_PLACES_API_KEY");
const enforcePlacesAppCheck = defineBoolean("PLACES_ENFORCE_APP_CHECK", {
  default: false,
});
const productionDependencies: PlacesDependencies = {
  guard: new FirestoreCostGuard(getFirestore()),
  fetch: (input, init) => globalThis.fetch(input, init),
  apiKey: () => googlePlacesApiKey.value(),
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
