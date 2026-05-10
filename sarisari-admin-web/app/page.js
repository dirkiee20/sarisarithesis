'use client';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';

export default function Home() {
  const { admin, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading) {
      router.replace(admin ? '/dashboard' : '/login');
    }
  }, [admin, loading, router]);

  return (
    <div className="loading-spinner" style={{ minHeight: '100vh' }}>
      <div className="spinner" />
    </div>
  );
}
