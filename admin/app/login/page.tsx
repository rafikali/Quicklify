'use client';

import { GoogleAuthProvider, signInWithPopup, signOut } from 'firebase/auth';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { signInAction } from '../actions';
import { firebaseClient } from '@/lib/firebase-client';

export default function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function handleSignIn() {
    setBusy(true);
    setError(null);
    try {
      const { auth } = firebaseClient();
      const provider = new GoogleAuthProvider();
      const result = await signInWithPopup(auth, provider);
      const idToken = await result.user.getIdToken();
      // Server verifies admin membership before issuing a session cookie.
      await signInAction(idToken);
      router.push('/users');
    } catch (e: unknown) {
      // Sign out of Firebase so the user can retry with a different account.
      try {
        await signOut(firebaseClient().auth);
      } catch {}
      const msg = e instanceof Error ? e.message : String(e);
      setError(msg);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="min-h-[80vh] flex items-center justify-center">
      <div className="bg-card border border-border rounded-2xl p-8 max-w-md w-full">
        <h1 className="text-2xl font-bold mb-2">Quicklify Admin</h1>
        <p className="text-muted mb-6 text-sm">
          Only Google accounts present in the <code className="text-primary">admins</code>{' '}
          collection can sign in.
        </p>
        <button
          onClick={handleSignIn}
          disabled={busy}
          className="w-full bg-white text-black py-2.5 rounded-lg font-medium disabled:opacity-50 hover:bg-gray-100"
        >
          {busy ? 'Signing in…' : 'Continue with Google'}
        </button>
        {error && (
          <p className="mt-4 text-danger text-sm">{error}</p>
        )}
      </div>
    </div>
  );
}
