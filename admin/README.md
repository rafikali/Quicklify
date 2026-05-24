# Quicklify Admin Panel

Internal Next.js 15 admin panel for managing Quicklify users and premium grants.
Talks to the same Firebase project as the mobile app via the Firebase Web SDK
(reads) and Firebase Admin SDK (privileged server-side mutations).

## Pages

| Route               | Purpose                                                       |
|---------------------|---------------------------------------------------------------|
| `/login`            | Google Sign-In, gated by `admins/{uid}` membership.           |
| `/users`            | Search/list users; shows tier and last-seen.                  |
| `/users/[uid]`      | Grant/revoke premium, list devices, view audit, ban user.     |
| `/audit`            | Global filterable audit log viewer.                           |

## Setup

1. Copy `.env.example` to `.env.local` and fill in:
   - `NEXT_PUBLIC_FIREBASE_*` — from Firebase Console → Project Settings → General → Your apps → Web SDK config.
   - `FIREBASE_SERVICE_ACCOUNT_JSON` — Project Settings → Service Accounts → Generate new private key. Paste the entire single-line JSON.

2. Install + run:
   ```bash
   npm install
   npm run dev
   ```

3. Visit http://localhost:3000 — you'll be redirected to `/login`. Sign in
   with a Google account that has a matching doc at `admins/{uid}` in
   Firestore (see `functions/README.md` step 7 for how to seed it).

## Deploy to Vercel

```bash
npx vercel
```

Set the same env vars in **Project Settings → Environment Variables**. For
the service-account JSON, paste the full one-line string; Vercel handles
multiline values via the `\\n` escape — our `firebase-admin.ts` re-normalizes.

Once deployed, point a subdomain like `admin.quicklify.app` at it and
restrict access by:
- (Recommended) Enforcing TOTP MFA in Firebase Auth for all admin accounts
- (Optional) Vercel Edge Middleware IP allowlist for known operator IPs

## Hardening checklist before going live

- [ ] All admin Google accounts have TOTP MFA enrolled
- [ ] `admins` collection has at most the operators who need access
- [ ] Service-account JSON is in Vercel env vars, NOT in git
- [ ] Session cookie expiry is acceptable (`maxAge` in `lib/admin-auth.ts`)
- [ ] First end-to-end run: grant premium to a test account, verify ads disappear in the mobile app, then revoke and verify ads return

## What this panel does NOT do (yet)

- License-key generation (later phase)
- Stripe management (later phase)
- Bulk operations / CSV export
- Push notifications to users

These are intentionally out of v1 scope.
