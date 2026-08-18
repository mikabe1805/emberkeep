import {createHash} from "node:crypto";

import type {Firestore} from "firebase-admin/firestore";
import {HttpsError} from "firebase-functions/v2/https";

export type AutocompleteInput = {
  query: string;
  sessionToken: string;
  installId: string;
  locale: string;
};

export type DetailsInput = {
  placeId: string;
  sessionToken: string;
  installId: string;
  locale: string;
};

export type PlacePrediction = {
  placeId: string;
  primaryText: string;
  secondaryText?: string;
};

export type PlaceDetails = {
  placeId: string;
  primaryText: string;
  secondaryText?: string;
};

export type PlaceOperation = "autocomplete" | "details";

export type CostGuardRequest = {
  operation: PlaceOperation;
  uid: string;
  installId: string;
};

export interface CostGuard {
  consume(request: CostGuardRequest): Promise<boolean>;
}

export type PlacesDependencies = {
  guard: CostGuard;
  fetch: typeof globalThis.fetch;
  apiKey: () => string;
};

type CallableRequest = {
  data: unknown;
  auth?: {uid: string} | null;
};

export type FixedUpstreamRequest = {
  url: string;
  init: RequestInit;
};

export const AUTOCOMPLETE_URL =
  "https://places.googleapis.com/v1/places:autocomplete";
export const AUTOCOMPLETE_FIELD_MASK =
  "suggestions.placePrediction.placeId," +
  "suggestions.placePrediction.structuredFormat.mainText.text," +
  "suggestions.placePrediction.structuredFormat.secondaryText.text";
export const DETAILS_FIELD_MASK = "id,displayName,formattedAddress";

const UUID_V4 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LOCALE = /^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$/;
const PLACE_ID = /^[A-Za-z0-9_-]{1,255}$/;

const invalidArgument = (message: string): never => {
  throw new HttpsError("invalid-argument", message);
};

const requireRecord = (value: unknown): Record<string, unknown> => {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return invalidArgument("The request payload must be an object.");
  }
  return value as Record<string, unknown>;
};

const requireString = (
  record: Record<string, unknown>,
  key: string,
): string => {
  const value = record[key];
  if (typeof value !== "string") {
    return invalidArgument(`${key} must be a string.`);
  }
  return value;
};

const requireExactKeys = (
  record: Record<string, unknown>,
  allowed: readonly string[],
): void => {
  const allowedKeys = new Set(allowed);
  if (Object.keys(record).some((key) => !allowedKeys.has(key))) {
    invalidArgument("The request contains an unsupported field.");
  }
};

const validateSharedFields = (
  record: Record<string, unknown>,
): Pick<AutocompleteInput, "sessionToken" | "installId" | "locale"> => {
  const sessionToken = requireString(record, "sessionToken");
  const installId = requireString(record, "installId");
  const locale = requireString(record, "locale");

  if (!UUID_V4.test(sessionToken)) {
    invalidArgument("sessionToken must be a UUID v4.");
  }
  if (!UUID_V4.test(installId)) {
    invalidArgument("installId must be a UUID v4.");
  }
  if (locale.length > 35 || !LOCALE.test(locale)) {
    invalidArgument("locale must be a valid language tag.");
  }

  return {sessionToken, installId, locale};
};

export const validateAutocompleteRequest = (
  value: unknown,
): AutocompleteInput => {
  const record = requireRecord(value);
  requireExactKeys(record, ["query", "sessionToken", "installId", "locale"]);
  const query = requireString(record, "query").trim();
  if (query.length < 3 || query.length > 160) {
    invalidArgument("query must contain 3 to 160 non-whitespace characters.");
  }
  return {query, ...validateSharedFields(record)};
};

export const validateDetailsRequest = (value: unknown): DetailsInput => {
  const record = requireRecord(value);
  requireExactKeys(record, ["placeId", "sessionToken", "installId", "locale"]);
  const placeId = requireString(record, "placeId");
  if (!PLACE_ID.test(placeId)) {
    invalidArgument("placeId is invalid.");
  }
  return {placeId, ...validateSharedFields(record)};
};

export const buildAutocompleteRequest = (
  input: AutocompleteInput,
  apiKey: string,
): FixedUpstreamRequest => ({
  url: AUTOCOMPLETE_URL,
  init: {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": apiKey,
      "X-Goog-FieldMask": AUTOCOMPLETE_FIELD_MASK,
    },
    body: JSON.stringify({
      input: input.query,
      sessionToken: input.sessionToken,
      languageCode: input.locale,
    }),
  },
});

export const buildDetailsRequest = (
  input: DetailsInput,
  apiKey: string,
): FixedUpstreamRequest => {
  const url = new URL(
    `https://places.googleapis.com/v1/places/${encodeURIComponent(input.placeId)}`,
  );
  url.searchParams.set("sessionToken", input.sessionToken);
  url.searchParams.set("languageCode", input.locale);
  return {
    url: url.toString(),
    init: {
      method: "GET",
      headers: {
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": DETAILS_FIELD_MASK,
      },
    },
  };
};

const asRecord = (value: unknown): Record<string, unknown> | undefined =>
  typeof value === "object" && value !== null && !Array.isArray(value) ?
    value as Record<string, unknown> : undefined;

const nestedText = (
  record: Record<string, unknown> | undefined,
  key: string,
): string | undefined => {
  const value = asRecord(record?.[key])?.text;
  return typeof value === "string" && value.length > 0 ? value : undefined;
};

export const normalizeAutocomplete = (value: unknown): PlacePrediction[] => {
  const suggestions = asRecord(value)?.suggestions;
  if (!Array.isArray(suggestions)) return [];

  const normalized: PlacePrediction[] = [];
  for (const suggestion of suggestions) {
    const prediction = asRecord(asRecord(suggestion)?.placePrediction);
    const placeId = prediction?.placeId;
    const structured = asRecord(prediction?.structuredFormat);
    const primaryText = nestedText(structured, "mainText");
    const secondaryText = nestedText(structured, "secondaryText");
    if (typeof placeId !== "string" || !PLACE_ID.test(placeId) || !primaryText) {
      continue;
    }
    normalized.push({
      placeId,
      primaryText,
      ...(secondaryText ? {secondaryText} : {}),
    });
    if (normalized.length === 5) break;
  }
  return normalized;
};

export const normalizeDetails = (value: unknown): PlaceDetails => {
  const record = asRecord(value);
  const placeId = record?.id;
  const primaryText = nestedText(record, "displayName");
  const secondaryText = record?.formattedAddress;
  if (typeof placeId !== "string" || !PLACE_ID.test(placeId) || !primaryText) {
    throw new HttpsError("unavailable", "The Places response was malformed.");
  }
  return {
    placeId,
    primaryText,
    ...(typeof secondaryText === "string" && secondaryText.length > 0 ?
      {secondaryText} : {}),
  };
};

type LimitPolicy = {
  perMinute: number;
  perDay: number;
  globalPerDay: number;
};

const GLOBAL_SHARD_COUNT = 20;
const UPSTREAM_TIMEOUT_MS = 8_000;
const COUNTER_TTL_MS = 35 * 24 * 60 * 60 * 1_000;

// These limits deliberately close well below a public search product's normal
// volume until billing alerts, provider quotas, and App Check are proven.
const LIMITS: Record<PlaceOperation, LimitPolicy> = {
  autocomplete: {perMinute: 30, perDay: 300, globalPerDay: 5_000},
  details: {perMinute: 10, perDay: 100, globalPerDay: 1_000},
};

type CounterState = {
  dayBucket: string;
  dayCount: number;
  minuteBucket: string;
  minuteCount: number;
};

const malformedCounter = (): never => {
  throw new Error("Malformed Places cost counter.");
};

const readCount = (value: unknown): number => {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    return malformedCounter();
  }
  return value;
};

const readCounter = (
  exists: boolean,
  value: Record<string, unknown> | undefined,
  dayBucket: string,
  minuteBucket: string,
): CounterState => {
  if (!exists) {
    return {dayBucket, dayCount: 0, minuteBucket, minuteCount: 0};
  }
  if (!value || value.dayBucket !== dayBucket) return malformedCounter();
  const storedMinuteBucket = value.minuteBucket;
  if (
    typeof storedMinuteBucket !== "string" ||
    !/^\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d$/.test(storedMinuteBucket) ||
    !storedMinuteBucket.startsWith(`${dayBucket}T`) ||
    storedMinuteBucket > minuteBucket
  ) {
    return malformedCounter();
  }
  const storedMinuteCount = readCount(value.minuteCount);
  return {
    dayBucket,
    dayCount: readCount(value.dayCount),
    minuteBucket,
    minuteCount: storedMinuteBucket === minuteBucket ?
      storedMinuteCount : 0,
  };
};

const globalShard = (request: CostGuardRequest): number => {
  const digest = createHash("sha256")
    .update(request.operation)
    .update("\0")
    .update(request.uid)
    .update("\0")
    .update(request.installId)
    .digest();
  return digest.readUInt32BE(0) % GLOBAL_SHARD_COUNT;
};

export class FirestoreCostGuard implements CostGuard {
  constructor(
    private readonly db: Firestore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async consume(request: CostGuardRequest): Promise<boolean> {
    const instant = this.now();
    const iso = instant.toISOString();
    const dayBucket = iso.slice(0, 10);
    const minuteBucket = iso.slice(0, 16);
    const uidHash = createHash("sha256").update(request.uid).digest("hex");
    const shard = globalShard(request);
    const counters = this.db.collection("_placesCostGuards");
    const refs = [
      counters.doc(`global_${request.operation}_${shard}_${dayBucket}`),
      counters.doc(`uid_${request.operation}_${uidHash}_${dayBucket}`),
      counters.doc(`install_${request.operation}_${request.installId}_${dayBucket}`),
    ];
    const policy = LIMITS[request.operation];

    return this.db.runTransaction(async (transaction) => {
      const snapshots = await Promise.all(refs.map((ref) => transaction.get(ref)));
      const states = snapshots.map((snapshot) =>
        readCounter(snapshot.exists, snapshot.data(), dayBucket, minuteBucket));
      const globalState = states[0]!;
      const uidState = states[1]!;
      const installState = states[2]!;
      const globalPerShard = policy.globalPerDay / GLOBAL_SHARD_COUNT;
      const globalClosed = globalState.dayCount >= globalPerShard;
      const uidClosed = uidState.dayCount >= policy.perDay ||
        uidState.minuteCount >= policy.perMinute;
      const installClosed = installState.dayCount >= policy.perDay ||
        installState.minuteCount >= policy.perMinute;
      if (globalClosed || uidClosed || installClosed) return false;

      // Owner setup gate: enable a Firestore TTL policy on
      // _placesCostGuards.expiresAt before public Places enablement.
      const expiresAt = new Date(instant.getTime() + COUNTER_TTL_MS);
      states.forEach((state, index) => {
        transaction.set(refs[index]!, {
          dayBucket,
          dayCount: state.dayCount + 1,
          minuteBucket,
          minuteCount: state.minuteCount + 1,
          updatedAt: iso,
          expiresAt,
        });
      });
      return true;
    });
  }
}

const requireAuth = (request: CallableRequest): string => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
};

const consumeGuard = async (
  guard: CostGuard,
  request: CostGuardRequest,
): Promise<void> => {
  let allowed = false;
  try {
    allowed = await guard.consume(request);
  } catch {
    allowed = false;
  }
  if (!allowed) {
    throw new HttpsError(
      "resource-exhausted",
      "Place search is temporarily unavailable.",
    );
  }
};

const fetchJson = async (
  request: FixedUpstreamRequest,
  fetchImpl: typeof globalThis.fetch,
): Promise<unknown> => {
  const controller = new AbortController();
  let timeout: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<never>((_resolve, reject) => {
    timeout = setTimeout(() => {
      controller.abort();
      reject(new Error("Places upstream deadline exceeded."));
    }, UPSTREAM_TIMEOUT_MS);
  });
  try {
    return await Promise.race([
      (async () => {
        const response = await fetchImpl(request.url, {
          ...request.init,
          signal: controller.signal,
        });
        if (!response.ok) {
          const code = response.status === 429 ?
            "resource-exhausted" : "unavailable";
          throw new HttpsError(code, "Place search is temporarily unavailable.");
        }
        try {
          return await response.json() as unknown;
        } catch {
          throw new HttpsError("unavailable", "The Places response was malformed.");
        }
      })(),
      deadline,
    ]);
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("unavailable", "Place search is temporarily unavailable.");
  } finally {
    if (timeout !== undefined) clearTimeout(timeout);
  }
};

const requireApiKey = (dependencies: PlacesDependencies): string => {
  const apiKey = dependencies.apiKey();
  if (!apiKey) {
    throw new HttpsError("failed-precondition", "Place search is not configured.");
  }
  return apiKey;
};

export const autocompleteHandler = async (
  request: CallableRequest,
  dependencies: PlacesDependencies,
): Promise<PlacePrediction[]> => {
  const uid = requireAuth(request);
  const input = validateAutocompleteRequest(request.data);
  await consumeGuard(dependencies.guard, {
    operation: "autocomplete",
    uid,
    installId: input.installId,
  });
  const upstream = buildAutocompleteRequest(input, requireApiKey(dependencies));
  return normalizeAutocomplete(await fetchJson(upstream, dependencies.fetch));
};

export const detailsHandler = async (
  request: CallableRequest,
  dependencies: PlacesDependencies,
): Promise<PlaceDetails> => {
  const uid = requireAuth(request);
  const input = validateDetailsRequest(request.data);
  await consumeGuard(dependencies.guard, {
    operation: "details",
    uid,
    installId: input.installId,
  });
  const upstream = buildDetailsRequest(input, requireApiKey(dependencies));
  return normalizeDetails(await fetchJson(upstream, dependencies.fetch));
};
