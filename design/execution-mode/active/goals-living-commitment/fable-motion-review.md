# Claude Fable 5 focused motion review

Reviewed: 2026-08-26

Mode: read-only, focused Product Council seat; ten-file inspection cap.

## Thesis

The journey is now structurally real, not faked: one continuous room master
genuinely retreats, pauses, and pushes through the arch, and the gold action
element forms a legible landmark chain from desk to arch to kitchen. The one
remaining screen-transition tell is the arrival, where the kitchen detail
document briefly resolves as a translucent sheet over the plate handoff.

Fable's verdict was that the current implementation is **strong enough to send
to an owner-feel check now**. If that check comes back cold, the highest-value
follow-up is to stage the arrival so the tracked gold quest card resolves first
and supporting rows follow roughly 80 to 120 milliseconds later.

## Strongest evidence

- The desk, window, curtain, rug, armchair, arch, and pendant retain their
  relative positions through the retreat and crossing. The implementation uses
  one camera pose over one continuous plate rather than independently moving
  scene cutouts.
- The motion has three readable beats: an easing retreat, a true wide-room
  hold, and an eased forward crossing to the kitchen handoff pose.
- Source UI leaves with hierarchy: secondary folio details recede while the
  goal identity and gold current action remain as the durable landmarks.
- The arch invitation shares the room plate's camera-pose math, keeping it
  registered to the lit doorway while still carrying the real current Quest.

## Main risk and counterargument

The final document currently shares one opacity ramp, so a sampled arrival
frame can read as a flat sheet over the kitchen. That risk is concentrated in a
short real-time interval, however; at playback speed it may register as a soft
exposure settle. Staging every element without evidence that the owner feels a
problem could replace one clean beat with unnecessary choreography.

## Recommendation

Run the current journey at real time on the physical phone before adding more
arrival choreography. Ask one direct question: did the final beat feel like
settling into the kitchen, or like a page fading in?

Confidence: moderately high, approximately 75%, that the current journey
passes an honest owner-feel check for moving through one room. Physical frame
pacing, OLED value, haptic weight, and the owner's felt response remain outside
the captured evidence.

## Durable evidence binding

After the read-only review, the unchanged reviewed frame sequence was packaged
as the final 430 x 932, 60 fps MP4 and animated WebP, with a contact sheet for
frame-level inspection. The final implementation revision differs from the
reviewed UI only by the deterministic screenshot harness viewport correction;
the room choreography and rendered sequence are unchanged.
