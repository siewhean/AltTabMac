"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center p-6 text-center">
      <div className="surface-panel max-w-md space-y-6 p-8">
        <h2 className="text-xl font-medium text-text">Something went wrong</h2>
        <p className="text-sm text-muted">
          {error.message || "An unexpected error occurred while loading this page."}
        </p>
        <div className="flex justify-center gap-3 pt-2">
          <Button onClick={() => reset()}>Try again</Button>
          <Link href="/">
            <Button variant="ghost">Return Home</Button>
          </Link>
        </div>
      </div>
    </div>
  );
}
