# Quicklify Premium — Operator Runbook (Option C — Free Tier)

This is the **Firestore-only, free-tier-forever** variant of the premium
feature. No Cloud Functions, no Blaze plan, no Ed25519 signing. Firebase
Spark plan handles 100k+ users at $0/month.

## Architecture

```
[ Flutter app ]  ─sign in with Google→  [ Firebase Auth ]
       │                                       │
       │                              (admins/{uid} doc gates admin)
       │                                       │
       │                                       ↓
       │                                [ Firestore ]   ←─  [ Next.js admin panel ]
       │  ↑ ↓                                  │              writes premium grants
       │  listens to subscriptions             │              via Firebase Admin SDK
       │  collection (real-time)               │
       │                            profiles, devices,
       │                            subscriptions, audit_log
       │
   reads cached isPremium
   from listener on every ad render
```

The Flutter client opens a Firestore snapshot listener on
`profiles/{uid}/subscriptions where active == true`. When the admin panel
writes a new active subscription, the listener fires on the user's device
within seconds and ads disappear.

## Security model — what you're trusting

Honest description of what defends premium against bypass:

| Defense | Strong against | Doesn't help against |
|---|---|---|
| Firestore Security Rules | Users writing their own subscription docs (client SDK rejects) | Patched APK that overrides the local cached value |
| TLS to Google + cert pinning | Network-level MITM swapping read responses | Rooted device patching the OS-level TLS stack |
| Code obfuscation (`--obfuscate`) | Casual static reverse-engineering | Skilled dynamic patching (frida etc.) |
| Multi-site inline check in `ads_service.dart` | Single `return true` patch | Skilled attacker patching all sites |
| Admin can see + revoke devices | Detecting abuse retroactively | Real-time prevention |

**Important honesty:** A determined user with a rooted phone and reverse-
engineering tools **can** make this app think they're premium. They cannot:
- Trick the admin panel into believing they're premium
- Cost any other user anything
- Affect server-side state in any way

So pirated premium is local-only and one-device-at-a-time. For an ad-funded
app with $X/mo premium pricing, this is industry-standard and adequate.

If you ever need stronger crypto guarantees, you can upgrade to the
PET-signing model (Option A in the plan) — keeps all current code, just adds
back the Cloud Functions layer and a server-signed JWT.

## One-time setup checklist

### Firebase project (Spark plan — free)
- [ ] Create project at https://console.firebase.google.com
- [ ] Enable **Authentication → Sign-in method → Google**
- [ ] Enable **Firestore Database** (production mode, `us-central` region)
- [ ] Stay on **Spark plan** (default) — do not upgrade to Blaze
- [ ] Add an **Android app** in Project Settings; download `google-services.json` → place at `android/app/google-services.json` (gitignored)

### Deploy Firestore rules + indexes
```bash
firebase login
firebase use --add   # pick your project
firebase deploy --only firestore:rules,firestore:indexes
```

### Seed yourself as admin
1. Sign in with Google through the admin panel once (it'll redirect to "Not authorized" — that's expected; the sign-in creates your Firebase auth user).
2. Copy your UID from Firebase Console → Authentication → Users.
3. In Firestore Console, create document at `admins/<your_uid>`:
   ```json
   {
     "email": "you@example.com",
     "role": "superadmin",
     "createdAt": <server timestamp>,
     "disabled": false
   }
   ```
4. Refresh the admin panel — you're now in.

### Admin panel deploy
```bash
cd admin
cp .env.example .env.local      # fill in NEXT_PUBLIC_FIREBASE_* + FIREBASE_SERVICE_ACCOUNT_JSON
npm install && npm run dev      # local
npx vercel --prod                # deploy
```

Set the same env vars in Vercel Project Settings. Enforce TOTP MFA on your
Firebase Auth admin account before going live.

### Mobile app release
```bash
./scripts/build_release.sh
cp build/app/outputs/flutter-apk/app-release.apk website/downloads/quicklify-latest.apk
# Push to gh-pages branch — see existing project flow.
```

Save `build/symbols/<version>/` — you cannot deobfuscate crash reports
without it.

---

## Common operations

### Grant premium to a user
1. User signs in with Google on the app (creates their `profiles/{uid}` doc).
2. Open admin panel → Users → search their email → click "Manage".
3. Pick duration (30d / 90d / 1y / lifetime) → Grant.
4. **Ads disappear within seconds** — Firestore listener picks up the new
   subscription doc in real time. No refresh needed.

### Revoke premium
1. Admin panel → user detail → enter reason → Revoke.
2. Active subscription set to `active: false` + `endsAt: now`.
3. Within seconds the user's Firestore listener fires and ads return.

### User reports "I'm at the 3-device limit"
Tell them: Settings → Premium → Devices → tap delete icon next to an old
device. They can sign back in on a fresh device immediately.

If they can't access any old device, use the admin panel to revoke one for them.

### Suspected account sharing
1. Admin panel → user detail → check device list. Many devices in disparate
   locations / timestamps is a flag.
2. Ban user with reason → active subscription revoked + `banned: true`.
3. Optionally: revoke just the suspicious device first, see if the legitimate
   user complains.

---

## Incident response

### User complains "I paid but no premium"
1. Admin panel → user detail.
2. Subscription section shows nothing or expired? → Grant premium with the
   correct duration.
3. If subscription is active in admin panel but the user still sees ads → have
   them sign out + back in on the app to force a fresh Firestore listener.

### Suspected modded APK in the wild
The Option C model is vulnerable to client-side patching. If you see
anomalous patterns (single account with many devices, or no signups but
mysteriously growing usage), the realistic answers are:
- Manually ban affected accounts.
- Consider upgrading to Option A (Blaze + Cloud Functions + Ed25519 PET) —
  the code is in git history at the pre-Option-C commits.

### Firestore quota approaching free limits
Spark plan limits (per **day**):
- 50,000 document reads
- 20,000 document writes
- 20,000 document deletes

At 100k users with the snapshot listener model:
- Each app foreground opens 1 listener → 1 read for active subscription doc
- Most users open the app a few times/day → 200k-500k reads/day → **above free**

If you hit this:
1. First, check the audit_log — somebody might be hammering with a script.
2. Apply caching: have the app store last-known-premium-state with a TTL of
   1h to reduce listener reconnect cost. (Code change in `premium_service.dart`.)
3. If still over, accept upgrade to Blaze (~$1-5/mo at this scale).

### Firestore Rules misconfigured
- Test in Firebase Console → Firestore → Rules tab → Playground.
- Redeploy with `firebase deploy --only firestore:rules`.

---

## What to check periodically

- **Monthly**: Firebase Usage tab — confirm you're under Spark limits. If
  approaching limits, see "Firestore quota" above.
- **Monthly**: scroll the audit log; look for unexpected actions.
- **Quarterly**: prune the `admins` collection — remove anyone who shouldn't
  have access anymore.

---

## File index

| Where | What |
|---|---|
| `firebase.json`, `firestore.rules`, `firestore.indexes.json` | Project config |
| `admin/` | Next.js admin panel — writes Firestore directly via Admin SDK |
| `lib/core/services/premium_service.dart` | Firestore subscription listener |
| `lib/core/services/auth_service.dart` | Google Sign-In via Firebase Auth |
| `lib/core/services/device_fingerprint_service.dart` | Device identification |
| `lib/core/services/ads_service.dart` | Premium-gated ads (multi-site inline check) |
| `lib/features/premium/` | UI |
| `android/app/src/main/res/xml/network_security_config.xml` | TLS cert pinning |
| `scripts/build_release.sh` | Release build with obfuscation |
