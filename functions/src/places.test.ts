import {HttpsError} from "firebase-functions/v2/https";

import {
  AUTOCOMPLETE_FIELD_MASK,
  AUTOCOMPLETE_URL,
  DETAILS_FIELD_MASK,
  FirestoreCostGuard,
  autocompleteHandler,
  buildAutocompleteRequest,
  buildDetailsRequest,
  detailsHandler,
  normalizeAutocomplete,
  normalizeDetails,
  validateAutocompleteRequest,
  validateDetailsRequest,
  type CostGuard,
  type CostGuardRequest,
  type PlacesDependencies,
} from "./places";

const sessionToken = "b7eb2f58-4ac9-4f62-8c93-8ef5a7e8d0c1";
const installId = "36c62113-6c21-4e9a-964b-03ad7404942f";

describe("request validation", () => {
  test("trims a query and accepts the inclusive length boundaries", () => {
    expect(validateAutocompleteRequest({
      query: "  abc  ",
      sessionToken,
      installId,
      locale: "en-US",
    })).toEqual({query: "abc", sessionToken, installId, locale: "en-US"});

    expect(validateAutocompleteRequest({
      query: "x".repeat(160),
      sessionToken,
      installId,
      locale: "zh-Hant-TW",
    }).query).toHaveLength(160);
  });

  test.each(["", "  ", "ab", "x".repeat(161)])(
    "rejects a query outside 3-160 trimmed characters: %p",
    (query) => {
      expect(() => validateAutocompleteRequest({
        query,
        sessionToken,
        installId,
        locale: "en-US",
      })).toThrow(HttpsError);
    },
  );

  test.each([
    ["sessionToken", "not-a-uuid"],
    ["sessionToken", "b7eb2f58-4ac9-1f62-8c93-8ef5a7e8d0c1"],
    ["installId", "not-a-uuid"],
  ])("rejects a non-v4 UUID in %s", (field, value) => {
    expect(() => validateAutocompleteRequest({
      query: "Rutgers",
      sessionToken,
      installId,
      locale: "en-US",
      [field]: value,
    })).toThrow(HttpsError);
  });

  test.each(["en_US", "e", "en-US-", "en-ThisSubtagIsTooLong"])(
    "rejects an invalid locale: %p",
    (locale) => {
      expect(() => validateAutocompleteRequest({
        query: "Rutgers",
        sessionToken,
        installId,
        locale,
      })).toThrow(HttpsError);
    },
  );

  test("accepts an opaque safe place ID and rejects unsafe IDs", () => {
    expect(validateDetailsRequest({
      placeId: "ChIJy-abc_123",
      sessionToken,
      installId,
      locale: "en-US",
    })).toEqual({
      placeId: "ChIJy-abc_123",
      sessionToken,
      installId,
      locale: "en-US",
    });

    for (const placeId of ["", "places/ChIJabc", "abc?key=secret", "x".repeat(256)]) {
      expect(() => validateDetailsRequest({
        placeId,
        sessionToken,
        installId,
        locale: "en-US",
      })).toThrow(HttpsError);
    }
  });
});

describe("fixed upstream requests", () => {
  test("builds autocomplete with the fixed URL, exact mask, and narrow body", () => {
    const request = buildAutocompleteRequest({
      query: "Rutgers",
      sessionToken,
      installId,
      locale: "en-US",
    }, "server-key");

    expect(request.url).toBe(AUTOCOMPLETE_URL);
    expect(request.init.method).toBe("POST");
    expect(Object.fromEntries(new Headers(request.init.headers).entries())).toEqual({
      "content-type": "application/json",
      "x-goog-api-key": "server-key",
      "x-goog-fieldmask": AUTOCOMPLETE_FIELD_MASK,
    });
    expect(JSON.parse(String(request.init.body))).toEqual({
      input: "Rutgers",
      sessionToken,
      languageCode: "en-US",
    });
    expect(AUTOCOMPLETE_FIELD_MASK).toBe(
      "suggestions.placePrediction.placeId," +
      "suggestions.placePrediction.structuredFormat.mainText.text," +
      "suggestions.placePrediction.structuredFormat.secondaryText.text",
    );
  });

  test("builds details on the fixed encoded path with locale and the same session token", () => {
    const request = buildDetailsRequest({
      placeId: "place with spaces",
      sessionToken,
      installId,
      locale: "fr-CA",
    }, "server-key");
    const url = new URL(request.url);

    expect(`${url.origin}${url.pathname}`).toBe(
      "https://places.googleapis.com/v1/places/place%20with%20spaces",
    );
    expect(Object.fromEntries(url.searchParams)).toEqual({
      sessionToken,
      languageCode: "fr-CA",
    });
    expect(request.init.method).toBe("GET");
    expect(request.init.body).toBeUndefined();
    expect(Object.fromEntries(new Headers(request.init.headers).entries())).toEqual({
      "x-goog-api-key": "server-key",
      "x-goog-fieldmask": DETAILS_FIELD_MASK,
    });
    expect(DETAILS_FIELD_MASK).toBe("id,displayName,formattedAddress");
  });
});

describe("response normalization", () => {
  test("returns at most five autocomplete predictions and discards every extra field", () => {
    const suggestions = Array.from({length: 6}, (_, index) => ({
      placePrediction: {
        placeId: `place_${index}`,
        text: {text: `unrequested ${index}`},
        structuredFormat: {
          mainText: {text: `Primary ${index}`, matches: [{startOffset: 0}]},
          secondaryText: {text: `Secondary ${index}`},
        },
        types: ["school"],
        distanceMeters: 42,
      },
      extraSuggestionField: true,
    }));

    expect(normalizeAutocomplete({suggestions, nextPageToken: "discard-me"}))
      .toEqual(Array.from({length: 5}, (_, index) => ({
        placeId: `place_${index}`,
        primaryText: `Primary ${index}`,
        secondaryText: `Secondary ${index}`,
      })));
  });

  test("returns only normalized details and drops coordinates and other provider fields", () => {
    expect(normalizeDetails({
      id: "ChIJabc",
      displayName: {text: "Rutgers University", languageCode: "en"},
      formattedAddress: "New Brunswick, NJ",
      location: {latitude: 40.5, longitude: -74.4},
      googleMapsUri: "https://maps.google.com/example",
      photos: [{name: "secret-extra"}],
    })).toEqual({
      placeId: "ChIJabc",
      primaryText: "Rutgers University",
      secondaryText: "New Brunswick, NJ",
    });
  });
});

class StubGuard implements CostGuard {
  readonly requests: CostGuardRequest[] = [];

  constructor(
    private readonly allowed: boolean,
    private readonly failure?: Error,
  ) {}

  async consume(request: CostGuardRequest): Promise<boolean> {
    this.requests.push(request);
    if (this.failure) throw this.failure;
    return this.allowed;
  }
}

const callable = (data: unknown, uid?: string) => ({
  data,
  auth: uid ? {uid, token: {}} : undefined,
});

const jsonResponse = (body: unknown, status = 200): Response => new Response(
  JSON.stringify(body),
  {status, headers: {"Content-Type": "application/json"}},
);

const dependencies = (
  guard: CostGuard,
  fetchImpl: typeof fetch,
): PlacesDependencies => ({
  guard,
  fetch: fetchImpl,
  apiKey: () => "server-key",
});

describe("callable handlers", () => {
  let forbiddenNetwork: jest.MockedFunction<typeof fetch>;

  beforeEach(() => {
    forbiddenNetwork = jest.fn<ReturnType<typeof fetch>, Parameters<typeof fetch>>(
      async (_input, _init) => {
      void _input;
      void _init;
      throw new Error("A test attempted an unmocked network request");
      },
    );
    global.fetch = forbiddenNetwork;
  });

  afterEach(() => {
    expect(forbiddenNetwork).not.toHaveBeenCalled();
  });

  test("rejects an unauthenticated request before cost guard or fetch", async () => {
    const guard = new StubGuard(true);
    const fetchMock = jest.fn<ReturnType<typeof fetch>, Parameters<typeof fetch>>();

    await expect(autocompleteHandler(callable({
      query: "Rutgers",
      sessionToken,
      installId,
      locale: "en-US",
    }), dependencies(guard, fetchMock))).rejects.toMatchObject({
      code: "unauthenticated",
    });
    expect(guard.requests).toEqual([]);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("rejects a rate-limited request before upstream fetch", async () => {
    const guard = new StubGuard(false);
    const fetchMock = jest.fn<ReturnType<typeof fetch>, Parameters<typeof fetch>>();

    await expect(autocompleteHandler(callable({
      query: "Rutgers",
      sessionToken,
      installId,
      locale: "en-US",
    }, "uid-1"), dependencies(guard, fetchMock))).rejects.toMatchObject({
      code: "resource-exhausted",
    });
    expect(guard.requests).toEqual([{
      operation: "autocomplete",
      uid: "uid-1",
      installId,
    }]);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("fails closed when cost storage errors", async () => {
    const guard = new StubGuard(true, new Error("Firestore unavailable"));
    const fetchMock = jest.fn<ReturnType<typeof fetch>, Parameters<typeof fetch>>();

    await expect(detailsHandler(callable({
      placeId: "ChIJabc",
      sessionToken,
      installId,
      locale: "en-US",
    }, "uid-1"), dependencies(guard, fetchMock))).rejects.toMatchObject({
      code: "resource-exhausted",
    });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  test("uses mocked fetch and exposes only normalized autocomplete fields", async () => {
    const guard = new StubGuard(true);
    const fetchMock = jest.fn<ReturnType<typeof fetch>, Parameters<typeof fetch>>()
      .mockResolvedValue(jsonResponse({
      suggestions: [{
        placePrediction: {
          placeId: "ChIJabc",
          structuredFormat: {
            mainText: {text: "Rutgers"},
            secondaryText: {text: "New Brunswick"},
          },
          types: ["university"],
        },
      }],
      providerInternal: "discard",
      }));

    await expect(autocompleteHandler(callable({
      query: "  Rutgers  ",
      sessionToken,
      installId,
      locale: "en-US",
    }, "uid-1"), dependencies(guard, fetchMock))).resolves.toEqual([{
      placeId: "ChIJabc",
      primaryText: "Rutgers",
      secondaryText: "New Brunswick",
    }]);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe(AUTOCOMPLETE_URL);
    expect(JSON.parse(String(init?.body))).toEqual({
      input: "Rutgers",
      sessionToken,
      languageCode: "en-US",
    });
  });

  test("includes the autocomplete session token in Details and filters its response", async () => {
    const guard = new StubGuard(true);
    const fetchMock = jest.fn<ReturnType<typeof fetch>, Parameters<typeof fetch>>()
      .mockResolvedValue(jsonResponse({
      id: "ChIJabc",
      displayName: {text: "Rutgers"},
      formattedAddress: "New Brunswick, NJ",
      location: {latitude: 40.5, longitude: -74.4},
      }));

    await expect(detailsHandler(callable({
      placeId: "ChIJabc",
      sessionToken,
      installId,
      locale: "en-US",
    }, "uid-1"), dependencies(guard, fetchMock))).resolves.toEqual({
      placeId: "ChIJabc",
      primaryText: "Rutgers",
      secondaryText: "New Brunswick, NJ",
    });
    const [rawUrl] = fetchMock.mock.calls[0];
    const url = new URL(String(rawUrl));
    expect(url.searchParams.get("sessionToken")).toBe(sessionToken);
    expect(url.searchParams.get("languageCode")).toBe("en-US");
  });
});

type FakeDocument = {path: string};

class FakeFirestore {
  readonly writes: Array<{path: string; data: unknown}> = [];

  constructor(
    private readonly dataForPath: (path: string) => Record<string, unknown> | undefined,
  ) {}

  collection(name: string): {doc: (id: string) => FakeDocument} {
    return {doc: (id) => ({path: `${name}/${id}`})};
  }

  async runTransaction<T>(
    update: (transaction: {
      get: (ref: FakeDocument) => Promise<{data: () => Record<string, unknown> | undefined}>;
      set: (ref: FakeDocument, data: unknown) => void;
    }) => Promise<T>,
  ): Promise<T> {
    return update({
      get: async (ref) => ({data: () => this.dataForPath(ref.path)}),
      set: (ref, data) => this.writes.push({path: ref.path, data}),
    });
  }
}

describe("production cost guard policy", () => {
  const now = () => new Date("2026-08-18T15:42:10.000Z");

  test("closes autocomplete when the global daily budget is exhausted", async () => {
    const db = new FakeFirestore((path) => path.includes("global_autocomplete") ? {
      dayBucket: "2026-08-18",
      dayCount: 5_000,
      minuteBucket: "2026-08-18T15:42",
      minuteCount: 0,
    } : undefined);
    const guard = new FirestoreCostGuard(db as never, now);

    await expect(guard.consume({
      operation: "autocomplete",
      uid: "uid-1",
      installId,
    })).resolves.toBe(false);
    expect(db.writes).toEqual([]);
  });

  test("closes details at the per-UID minute limit", async () => {
    const db = new FakeFirestore((path) => path.includes("uid_details") ? {
      dayBucket: "2026-08-18",
      dayCount: 9,
      minuteBucket: "2026-08-18T15:42",
      minuteCount: 10,
    } : undefined);
    const guard = new FirestoreCostGuard(db as never, now);

    await expect(guard.consume({
      operation: "details",
      uid: "uid-1",
      installId,
    })).resolves.toBe(false);
    expect(db.writes).toEqual([]);
  });

  test("atomically increments global, UID, and install counters when open", async () => {
    const db = new FakeFirestore(() => undefined);
    const guard = new FirestoreCostGuard(db as never, now);

    await expect(guard.consume({
      operation: "details",
      uid: "uid-1",
      installId,
    })).resolves.toBe(true);
    expect(db.writes).toHaveLength(3);
    expect(db.writes.map((write) => write.data)).toEqual([
      {
        dayBucket: "2026-08-18",
        dayCount: 1,
        minuteBucket: "2026-08-18T15:42",
        minuteCount: 1,
        updatedAt: "2026-08-18T15:42:10.000Z",
      },
      {
        dayBucket: "2026-08-18",
        dayCount: 1,
        minuteBucket: "2026-08-18T15:42",
        minuteCount: 1,
        updatedAt: "2026-08-18T15:42:10.000Z",
      },
      {
        dayBucket: "2026-08-18",
        dayCount: 1,
        minuteBucket: "2026-08-18T15:42",
        minuteCount: 1,
        updatedAt: "2026-08-18T15:42:10.000Z",
      },
    ]);
  });
});
