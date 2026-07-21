"use client";

import { useEffect, useRef, useState } from "react";

import { screenshotAssets } from "@/content/media";

export function ScreenshotFrame({
  assetId,
  className = "",
  caption,
  priority = false,
}: {
  assetId: keyof typeof screenshotAssets;
  className?: string;
  caption?: string;
  priority?: boolean;
}) {
  const asset = screenshotAssets[assetId];
  const videoRef = useRef<HTMLVideoElement>(null);
  const [reduceMotion, setReduceMotion] = useState(true);

  useEffect(() => {
    if (asset.kind !== "video") return;

    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    const applyPreference = () => setReduceMotion(query.matches);
    applyPreference();
    query.addEventListener("change", applyPreference);
    return () => query.removeEventListener("change", applyPreference);
  }, [asset.kind]);

  useEffect(() => {
    if (asset.kind !== "video" || !videoRef.current) return;
    if (reduceMotion) {
      videoRef.current.pause();
      return;
    }
    void videoRef.current.play().catch(() => {
      // The poster remains visible when browser autoplay policy blocks playback.
    });
  }, [asset.kind, reduceMotion]);

  return (
    <figure className={`group ${className}`}>
      <div className="surface-panel relative overflow-hidden bg-panel/70 transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:-translate-y-0.5">
        <div className="absolute inset-x-0 top-0 h-24 bg-gradient-to-b from-white/8 to-transparent" />
        {asset.kind === "video" ? (
          <video
            ref={videoRef}
            src={asset.src}
            poster={asset.posterSrc}
            width={asset.width}
            height={asset.height}
            muted
            loop
            playsInline
            preload={priority || asset.priority ? "auto" : "metadata"}
            aria-label={asset.alt}
            className="h-auto w-full transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:scale-[1.005]"
          />
        ) : (
          <img
            src={asset.src}
            alt={asset.alt}
            width={asset.width}
            height={asset.height}
            loading={priority || asset.priority ? "eager" : "lazy"}
            className="h-auto w-full transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:scale-[1.005]"
          />
        )}
      </div>
      {(caption || asset.caption) && (
        <figcaption className="mt-3 max-w-2xl text-sm leading-6 text-subdued">
          {caption ?? asset.caption}
        </figcaption>
      )}
    </figure>
  );
}
