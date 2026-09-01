type RoomData = Record<string, unknown> | undefined;

const ROOM_KEEPSAKE_IDS = new Set([
  "keepsake_books",
  "keepsake_sprout",
  "keepsake_camera",
  "keepsake_teapot",
  "keepsake_cat",
  "keepsake_record",
]);

/// Version 6 rooms predate keepsakes. Version 7 is deliberately accepted only
/// when its visual-only keepsake payload has the same bounded shape as the
/// client and Firestore rules contracts. Version 8 adds one explicit public
/// room-photo pointer and framing metadata. Unknown future room schemas must
/// opt in here rather than silently becoming callable targets.
export const hasValidRoomKeepsakes = (value: unknown): value is string[] =>
  Array.isArray(value) &&
  value.length <= 2 &&
  value.every((id) => typeof id === "string" && ROOM_KEEPSAKE_IDS.has(id)) &&
  new Set(value).size === value.length;

const OWNER_KEY = /^[a-f0-9]{64}$/;
const ROOM_PHOTO_PATH = /^shared_rooms\/[a-f0-9]{64}\/[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}\/room\/[A-Za-z0-9_-]{22}$/;

const isFiniteNumberInRange = (value: unknown, minimum: number, maximum: number): boolean =>
  typeof value === "number" && Number.isFinite(value) && value >= minimum && value <= maximum;

export const hasValidPublicRoomPhoto = (room: Record<string, unknown>): boolean => {
  const path = room.roomPhotoPath;
  const fill = room.roomPhotoFill;
  const x = room.roomPhotoX;
  const y = room.roomPhotoY;
  const width = room.roomPhotoWidth;
  const height = room.roomPhotoHeight;
  if (path === "") {
    return fill === false && x === 0 && y === 0 && width === 1 && height === 1;
  }
  const pathOwnerKey = typeof path === "string" ? path.split("/")[1] : undefined;
  return typeof path === "string" && path.length <= 192 && ROOM_PHOTO_PATH.test(path) &&
    OWNER_KEY.test(pathOwnerKey ?? "") && pathOwnerKey === room.ownerKey && typeof fill === "boolean" &&
    isFiniteNumberInRange(x, -1, 1) && isFiniteNumberInRange(y, -1, 1) &&
    Number.isInteger(width) && (width as number) >= 1 && (width as number) <= 1200 &&
    Number.isInteger(height) && (height as number) >= 1 && (height as number) <= 1200;
};

export const isSupportedGeneratedRoom = (room: RoomData): boolean =>
  room?.v === 6 ||
  (room?.v === 7 && hasValidRoomKeepsakes(room.roomKeepsakes)) ||
  (room?.v === 8 && hasValidRoomKeepsakes(room.roomKeepsakes) && hasValidPublicRoomPhoto(room));
