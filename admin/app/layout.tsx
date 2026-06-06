import type { Metadata } from 'next';
import Link from 'next/link';
import { getCurrentAdminUid } from '@/lib/admin-auth';
import { signOutAction } from './actions';
import './globals.css';

export const metadata: Metadata = {
  title: 'Quicklify Admin',
  description: 'Internal admin panel for Quicklify',
  robots: { index: false, follow: false },
};

export default async function RootLayout({ children }: { children: React.ReactNode }) {
  const adminUid = await getCurrentAdminUid();
  return (
    <html lang="en">
      <body>
        {adminUid && <Nav />}
        <main className="max-w-6xl mx-auto p-6">{children}</main>
      </body>
    </html>
  );
}

function Nav() {
  return (
    <nav className="bg-surface border-b border-border">
      <div className="max-w-6xl mx-auto px-6 py-3 flex items-center gap-6">
        <Link href="/users" className="font-semibold text-text">
          Quicklify Admin
        </Link>
        <Link href="/users" className="text-muted hover:text-text text-sm">Users</Link>
        <Link href="/devices" className="text-muted hover:text-text text-sm">Devices</Link>
        <Link href="/plans" className="text-muted hover:text-text text-sm">Plans</Link>
        <Link href="/app-control" className="text-muted hover:text-text text-sm">App control</Link>
        <Link href="/audit" className="text-muted hover:text-text text-sm">Audit log</Link>
        <form action={signOutAction} className="ml-auto">
          <button
            type="submit"
            className="text-muted hover:text-danger text-sm"
          >
            Sign out
          </button>
        </form>
      </div>
    </nav>
  );
}
