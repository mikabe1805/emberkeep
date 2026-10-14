/// What the player is doing, in the fight's own terms. A touch layer or a
/// keyboard sets these; the fight reads them every step.
///
/// The `p...` flags are one-shot presses: the fight clears each one the step
/// it reads it. [attackHeld], [moveX] and [jumpHeld] are levels.
final class BrawlInput {
  /// -1 left, 0 still, 1 right (or anything between, from a pad).
  double moveX = 0;

  /// ATTACK is down right now (holding it charges Power Slam).
  bool attackHeld = false;

  /// The jump button is down right now. Letting go early trims the jump.
  bool jumpHeld = true;

  bool pAtk = false;
  bool pJump = false;
  bool pSpell = false;
  bool pFriend = false;
  bool pSuper = false;
  bool pFinish = false;

  /// Lets go of everything.
  void reset() {
    moveX = 0;
    attackHeld = false;
    jumpHeld = true;
    pAtk = pJump = pSpell = pFriend = pSuper = pFinish = false;
  }
}
