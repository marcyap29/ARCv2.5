# Firestore: Activity log index and rules (plain English)

The **Plugin Activity** screen reads from the Firestore collection `plugin_activity_log`. Two Firestore concepts matter here: **indexes** and **rules**.

---

## 1. Rules = “Who is allowed to read/write?”

**What they do:** Firestore rules decide, for each request, “can this user read or write this document?”

- **Without a rule for `plugin_activity_log`:** Firestore was denying all access (your default “deny everything else”).
- **With the rule we added:**  
  - **Read:** Allowed only if the user is signed in **and** the document’s `user_id` equals their UID (so each user only sees their own activity).  
  - **Write:** Denied from the app. Only the Cloud Function (`swarmspaceRouter`) writes, using the Admin SDK, which bypasses rules.

**Where it lives:** In your repo: `firestore.rules`. The block for `plugin_activity_log` is:

```text
match /plugin_activity_log/{id} {
  allow read: if isAuthenticated() && resource.data.user_id == request.auth.uid;
  allow write: if false;
}
```

**What you do:** Deploy the rules so they take effect:

```bash
cd /Users/mymac/Software/Development/ARCv2.5
firebase deploy --only firestore:rules
```

After that, the app can read only its own activity rows; no one can write from the client.

---

## 2. Index = “How Firestore can run your query”

**What it does:** For some queries (e.g. “where user_id = X, ordered by called_at newest first”), Firestore needs a **composite index**: an index on more than one field so it can answer the query efficiently.

- **If the index exists:** The Activity screen loads normally.
- **If the index is missing:** The first time the app runs that query, Firestore returns an error and, in the error message, gives a **link**. Opening that link in a browser takes you to the Firebase Console with the index pre-filled; you click “Create index” and wait a few minutes. No need to remember field names.

**What you do:**

1. Run the app and open **Agents → Plugin Activity** (after at least one plugin call has been logged).
2. If you see an error in the app or in the debug console that mentions **“index”** or **“Create index”**, copy the URL from the error and open it in your browser.
3. In the console, confirm and create the index. When it’s ready, the Activity screen will work.

If you never see that error, Firestore may already have a suitable index (e.g. from another collection) or the query is satisfied without a composite index; in that case you don’t need to do anything.

**Required composite index (if creating manually):** Collection `plugin_activity_log`, fields: `user_id` (Ascending), `called_at` (Descending).

---

## 3. Local usage (this device)

If the Firestore index is missing or you prefer not to use Cloudflare/Firestore for activity, the app still records **plugin activation counts** on the device (SharedPreferences). When you open **Plugin Activity** and Firestore fails (e.g. index error), the screen shows:

- The error and a link to create the index (if applicable).
- **Local usage (this device):** how many times each plugin was activated on this device. Counts persist across days until app data is cleared. No server or multi-user separation—each device has its own counts.

So you can either create the index to see full Firestore activity log entries, or use the local counts only.

---

## Summary

| Thing   | Meaning in plain English |
|--------|----------------------------|
| **Rules** | “Only the signed-in user can read their own rows in `plugin_activity_log`; no one can write from the app.” Deploy with `firebase deploy --only firestore:rules`. |
| **Index** | Lets Firestore run the “my activity, newest first” query. If Firestore asks for it, use the link in the error to create the index in the console. |
