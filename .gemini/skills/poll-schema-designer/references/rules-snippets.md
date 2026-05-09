# Common Firestore rule fragments — anonymous-auth friendly

```js
function isSignedIn() { return request.auth != null; }
function isOwner(uid)  { return request.auth.uid == uid; }
function isWorkshopOwner(workshopId) {
  return isSignedIn()
      && get(/databases/$(database)/documents/workshops/$(workshopId))
           .data.createdBy == request.auth.uid;
}
```

```js
match /workshops/{workshopId} {
  allow read:           if isSignedIn();
  allow create:         if isSignedIn() && request.resource.data.createdBy == request.auth.uid;
  allow update, delete: if isOwner(resource.data.createdBy);

  match /polls/{pollId} {
    allow read:                  if isSignedIn();
    allow create, update, delete: if isWorkshopOwner(workshopId);

    match /votes/{voteId} {
      // Admin (workshop owner) can read all votes; the voter can read their own.
      allow read: if isWorkshopOwner(workshopId) || isOwner(resource.data.userId);

      // One vote per (poll, user). Vote id MUST equal the voter's uid for uniqueness.
      allow create:
        if isSignedIn()
        && voteId == request.auth.uid
        && request.resource.data.userId == request.auth.uid;

      allow update, delete: if false;
    }
  }
}
```

Notes:
- No `users/` collection lookup. Anonymous uids never need a profile doc.
- Admin = `createdBy == request.auth.uid` on the workshop. No custom claims.
- Vote uniqueness: enforce by using `voteId == request.auth.uid`. Avoids
  the expensive `exists()` call.
- `request.auth != null` matches both anonymous and Google-signed users,
  so the optional Google SSO upgrade does not require a rules change.
