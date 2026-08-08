# Room of Days account-deletion runbook

This is the owner procedure for requests submitted through
https://roomofdays.com/delete-account. Complete a verified request within
seven days. Never ask for a password, journal export, room code, or other
journal content.

## 1. Verify the request

1. Confirm the message was sent from the email address attached to the Room of
   Days account.
2. Reply once to confirm that the sender requested permanent deletion of the
   account and associated cloud data.
3. If the address does not match an account, say only that no matching active
   Room of Days account was found. Do not disclose whether another address has
   an account.

## 2. Remove Firebase data

Use the production Firebase project emberkeep-5b33b.

1. In Firebase Authentication, find the exact email and record its UID only for
   the duration of this deletion.
2. In Firestore, delete saves/{uid}.
3. Query the rooms collection for documents whose uid field equals the account
   UID. For every result:
   - delete every document in its sparks subcollection;
   - delete every document in its circleAdds subcollection; and
   - delete the room document itself.
4. Check Cloud Storage for shared_rooms/{uid}/ and remove that prefix if it
   exists. The first store release does not upload visitor photos, but this
   check prevents dormant or test data from surviving.
5. Delete the Firebase Authentication user last.

Deleting a Firestore parent document does not delete its subcollections. Do not
skip the Spark and Circle receipt cleanup.

## 3. Verify and close

1. Confirm the Authentication user no longer exists.
2. Confirm saves/{uid}, owned room documents, receipt subcollections, and the
   Storage prefix are absent.
3. Reply that deletion is complete. Do not include the UID or any recovered app
   content in the reply.
4. Remove temporary notes containing the UID.

If any deletion cannot be confirmed, keep the request open, retry, and tell the
requester that completion is delayed. Never claim completion from a partial
cleanup.
