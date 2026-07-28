"use client";

import Link from "next/link";
import { Button } from "@/components/ui/button";

export default function BuyError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center p-6 text-center">
      <div className="surface-panel max-w-md space-y-4 p-8">
        <h2 className="text-lg font-medium text-text">Checkout Unavailable</h2>
        <p className="text-sm text-muted">
          {error.message || "Unable to load checkout details right now."}
        </p>
        <div className="flex justify-center gap-3 pt-2">
          <Button onClick={() => reset()}>Try Again</Button>
          <Link href="/help">
            <Button variant="ghost">Contact Support</Button>
          </Link>
        </div>
      </div>
    </div>
  );
}
