import { redirect } from 'next/navigation';
import { getCurrentAdminUid } from '@/lib/admin-auth';

export default async function Home() {
  const uid = await getCurrentAdminUid();
  redirect(uid ? '/users' : '/login');
}
