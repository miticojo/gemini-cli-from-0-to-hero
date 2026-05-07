# Common Firestore rule fragments

```js
function isSignedIn() { return request.auth != null; }
function isAdmin() { return request.auth.token.role == "admin"; }
function isOwner(uid) { return request.auth.uid == uid; }
function isWorkshopAttendee(workshopId) {
  return get(/databases/$(database)/documents/users/$(request.auth.uid))
           .data.workshops.hasAny([workshopId]);
}
```

```js
match /workshops/{workshopId} {
  allow read: if isSignedIn() && (isAdmin() || isWorkshopAttendee(workshopId));
  allow create: if isSignedIn();
  allow update, delete: if isAdmin() || isOwner(resource.data.createdBy);
}
```

```js
match /workshops/{w}/polls/{p}/votes/{v} {
  allow read: if isAdmin() || isOwner(resource.data.userId);
  allow create:
    if isSignedIn()
    && request.resource.data.userId == request.auth.uid
    && !exists(/databases/$(database)/documents/workshops/$(w)/polls/$(p)/votes/$(request.auth.uid));
  allow update, delete: if false;
}
```
