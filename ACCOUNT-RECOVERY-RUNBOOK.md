# Room of Days account-recovery runbook

Room of Days works without an account. This procedure is only for someone who
chose the optional email-and-password cloud backup and can no longer sign in.
The first mobile release does not expose a self-service reset button, so support
uses Firebase Authentication's password-reset email. Never ask for or accept a
current password, proposed password, journal export, room code, or journal
content.

## Before store submission

Use the production Firebase project `emberkeep-5b33b`.

1. In Firebase Authentication's Templates tab, edit the Password reset email so
   its sender name, subject, body, and support address all say Room of Days.
2. Configure and apply a verified custom Auth email domain under
   `roomofdays.com` (a dedicated subdomain is fine). Check the received message,
   action link, and reset page. None may expose Emberkeep, `emberkeep-5b33b`, or
   a generic Firebase product identity to the recipient.
3. Confirm the exact domain used by the reset flow is listed in Authentication's
   authorized domains.
4. Send a reset email to the dedicated review account from the Firebase console.
   Open the link, choose a new password, and finish the complete cycle: the old
   password fails, the new password signs in, and the account's cloud save is
   preserved.
5. Record the test date and result without recording either password or the
   one-time reset link. Do not mark the release gate complete after merely
   receiving the email.

Firebase documents both console-sent reset emails and custom Auth email domains:

- https://firebase.google.com/docs/auth/web/manage-users
- https://firebase.google.com/docs/auth/email-custom-domain

## Handle a recovery request

1. Accept the request only through the monitored `support@roomofdays.com`
   inbox. Prefer a message sent from the address attached to the account.
2. In the production Firebase project's Authentication user list, search for
   the exact address. If it is present, use the console's password-reset action
   so Firebase delivers a fresh one-time link directly to that address.
3. Reply only that a reset message was sent and may be in spam. Never copy a
   reset link into a support reply, set a password on the user's behalf, or ask
   the user to send a password back.
4. If the address is absent, or the requester is writing from a different
   address, use neutral language: support could not verify an account for the
   supplied address. Do not reveal whether any other address has an account.
5. After the user confirms access, remove any temporary support note that could
   identify the account. No Firebase UID or app content belongs in the reply.

If reset delivery or the action page fails, keep the request open and fix the
template, domain, or authorized-domain configuration. Do not work around it by
changing credentials manually.
