"use client";

import { useEffect, useRef, useState } from "react";

import type { ShowcaseAsset } from "@/content/showcase";

export function ShowcaseVideo({
  asset,
  priority = false,
  compact = false,
  showCaption = true,
}: {
  asset: ShowcaseAsset;
  priority?: boolean;
  compact?: boolean;
  showCaption?: boolean;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(false);

  useEffect(() => {
    if (!asset.video) return;

    const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const applyPreference = () => {
      setPrefersReducedMotion(mediaQuery.matches);
      if (mediaQuery.matches) videoRef.current?.pause();
    };

    applyPreference();
    mediaQuery.addEventListener("change", applyPreference);
    return () => mediaQuery.removeEventListener("change", applyPreference);
  }, [asset.video]);

  useEffect(() => {
    const video = videoRef.current;
    if (!asset.video || !video) return;

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry?.isIntersecting && entry.intersectionRatio >= 0.35 && !prefersReducedMotion) {
          void video.play().catch(() => undefined);
        } else {
          video.pause();
        }
      },
      { threshold: [0, 0.35, 1] },
    );

    observer.observe(video);
    return () => observer.disconnect();
  }, [asset.video, prefersReducedMotion]);

  const descriptionId = showCaption ? `${asset.id}-media-description` : undefined;

  return (
    <figure className="group">
      <div className="relative overflow-hidden rounded-[24px] border border-white/10 bg-black/35 shadow-[0_24px_80px_rgba(0,0,0,0.38)] sm:rounded-[28px]">
        {asset.video ? (
          <video
            ref={videoRef}
            className="aspect-[8/5] h-auto w-full bg-[#05070c] object-cover"
            poster={asset.poster}
            width={asset.videoWidth}
            height={asset.videoHeight}
            autoPlay={priority && !prefersReducedMotion}
            muted
            loop
            playsInline
            preload={priority ? "auto" : "metadata"}
            aria-label={showCaption ? undefined : asset.title}
            aria-describedby={descriptionId}
          >
            <source src={asset.video} type="video/mp4" />
            Your browser does not support embedded MP4 video.
          </video>
        ) : (
          <img
            src={asset.poster}
            alt={showCaption ? "" : asset.title}
            width={asset.posterWidth}
            height={asset.posterHeight}
            loading={priority ? "eager" : "lazy"}
            className="aspect-[8/5] h-auto w-full bg-[#05070c] object-cover"
            aria-describedby={descriptionId}
          />
        )}

        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-24 bg-gradient-to-t from-black/78 to-transparent" />
        <div className="pointer-events-none absolute inset-x-0 bottom-0 p-4 sm:p-5">
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan">{asset.eyebrow}</p>
          <p className="mt-1 truncate text-sm font-medium text-white sm:text-base">{asset.title}</p>
        </div>
      </div>

      {showCaption ? (
        <figcaption id={descriptionId} className={compact ? "mt-3" : "mt-4"}>
          <p className={`text-muted ${compact ? "text-sm leading-6" : "text-base leading-7"}`}>
            {asset.description}
          </p>
        </figcaption>
      ) : null}
    </figure>
  );
}
