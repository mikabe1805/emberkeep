import {createHash} from "node:crypto";
import {hasValidPublicRoomPhoto, isSupportedGeneratedRoom} from "./generated_room";

const ownerKey = createHash("sha256").update("owner", "utf8").digest("hex");
const roomPhotoPath = `shared_rooms/${ownerKey}/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV`;

const v8Room = () => ({
  v: 8,
  ownerKey,
  roomKeepsakes: ["keepsake_books"],
  roomPhotoPath,
  roomPhotoFill: true,
  roomPhotoX: -0.5,
  roomPhotoY: 0.25,
  roomPhotoWidth: 1200,
  roomPhotoHeight: 800,
});

describe("generated room v8 public-photo contract", () => {
  test("accepts an opaque owner-key room slot and bounded framing", () => {
    expect(hasValidPublicRoomPhoto(v8Room())).toBe(true);
    expect(isSupportedGeneratedRoom(v8Room())).toBe(true);
  });

  test("accepts only the exact empty-photo defaults", () => {
    const room = {
      ...v8Room(),
      roomPhotoPath: "",
      roomPhotoFill: false,
      roomPhotoX: 0,
      roomPhotoY: 0,
      roomPhotoWidth: 1,
      roomPhotoHeight: 1,
    };
    expect(hasValidPublicRoomPhoto(room)).toBe(true);
    expect(isSupportedGeneratedRoom(room)).toBe(true);
    expect(hasValidPublicRoomPhoto({...room, roomPhotoWidth: 2})).toBe(false);
  });

  test("rejects uid-like paths, cross-owner paths, and invalid framing", () => {
    expect(hasValidPublicRoomPhoto({...v8Room(), roomPhotoPath: "shared_rooms/owner/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV"})).toBe(false);
    expect(hasValidPublicRoomPhoto({...v8Room(), roomPhotoPath: `shared_rooms/${"0".repeat(64)}/ABC234/room/ABCDEFGHIJKLMNOPQRSTUV`})).toBe(false);
    expect(hasValidPublicRoomPhoto({...v8Room(), roomPhotoX: 1.1})).toBe(false);
    expect(hasValidPublicRoomPhoto({...v8Room(), roomPhotoWidth: 1201})).toBe(false);
  });
});
