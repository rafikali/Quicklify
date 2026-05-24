// Route guard. We can't call Firebase Admin SDK from middleware (edge runtime
// limitations), so we just check whether the session cookie exists. The real
// admin-membership check happens in each server component via `getCurrentAdminUid()`.

import { NextResponse, type NextRequest } from 'next/server';

const COOKIE = 'qlf_admin_id_token';
const PUBLIC = ['/login'];

export function middleware(req: NextRequest) {
  const { pathname } = req.nextUrl;
  if (PUBLIC.some((p) => pathname.startsWith(p))) return NextResponse.next();
  if (pathname.startsWith('/_next') || pathname.startsWith('/favicon')) {
    return NextResponse.next();
  }

  const hasCookie = req.cookies.get(COOKIE);
  if (!hasCookie) {
    const url = req.nextUrl.clone();
    url.pathname = '/login';
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)'],
};
