"use client";

import { useEffect, useRef, useState } from "react";

import type { ShowcaseAsset } from "@/content/showcase";

export function ShowcaseVideo({
  asset,
  priority = false,
  compact = false,
}: {
  asset: ShowcaseAsset;
  priority?: boolean;
  compact?: boolean;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [prefersReducedMotion, setPrefersReducedMotion] = useState(true);

  useEffect(() => {
    const mediaQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
    const applyPreference = () => {
      setPrefersReducedMotion(mediaQuery.matches);
      if (mediaQuery.matches) {
        videoRef.current?.pause();
        setIsPlaying(false);
      }
    };

    applyPreference();
    mediaQuery.addEventListener("change", applyPreference);
    return () => mediaQuery.removeEventListener("change", applyPreference);
  }, []);

  useEffect(() => {
    const video = videoRef.current;
    if (!video || prefersReducedMotion) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const entry = entries[0];
        if (!entry) return;

        if (entry.isIntersecting && entry.intersectionRatio >= 0.45) {
          void video.play().then(() => setIsPlaying(true)).catch(() => setIsPlaying(false));
        } else {
          video.pause();
          setIsPlaying(false);
        }
      },
      { threshold: [0, 0.45, 1] },
    );

    observer.observe(video);
    return () => observer.disconnect();
  }, [prefersReducedMotion]);

  function togglePlayback() {
    const video = videoRef.current;
    if (!video) return;

    if (video.paused) {
      void video.play().then(() => setIsPlaying(true)).catch(() => setIsPlaying(false));
    } else {
      video.pause();
      setIsPlaying(false);
    }
  }

  return (
    <figure className="group">
      <div className="relative overflow-hidden rounded-[28px] border border-white/10 bg-black/35 shadow-[0_28px_100px_rgba(0,0,0,0.42)]">
        <video
          ref={videoRef}
          className="aspect-[8/5] h-auto w-full bg-[#05070c] object-cover"
          poster={asset.poster}
          muted
          loop
          playsInline
          preload={priority ? "auto" : "metadata"}
          aria-describedby={`${asset.id}-video-description`}
          onPlay={() => setIsPlaying(true)}
          onPause={() => setIsPlaying(false)}
        >
          <source src={asset.video} type="video/mp4" />
          Your browser does not support embedded MP4 video. The same behavior is described in the transcript below.
        </video>

        <div className="pointer-events-none absolute inset-x-0 bottom-0 h-28 bg-gradient-to-t from-black/75 to-transparent" />
        <div className="absolute inset-x-0 bottom-0 flex items-end justify-between gap-4 p-4 sm:p-5">
          <div className="pointer-events-none min-w-0">
            <p className="text-xs font-semibold uppercase tracking-[0.16em] text-cyan">{asset.eyebrow}</p>
            <p className="mt-1 truncate text-sm font-medium text-white sm:text-base">{asset.title}</p>
          </div>
          <button
            type="button"
            onClick={togglePlayback}
            className="inline-flex min-h-11 shrink-0 items-center justify-center rounded-full border border-white/18 bg-black/65 px-4 text-sm font-medium text-white backdrop-blur-md transition-colors hover:bg-black/82 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/70"
            aria-label={`${isPlaying ? "Pause" : "Play"} ${asset.title}`}
          >
            {isPlaying ? "Pause" : "Play"}
          </button>
        </div>
      </div>

      <figcaption id={`${asset.id}-video-description`} className={compact ? "mt-3" : "mt-5"}>
        <p className={`leading-7 text-muted ${compact ? "text-sm" : "text-base"}`}>{asset.description}</p>
        {!compact ? (
          <details className="mt-4 rounded-[18px] border border-white/8 bg-white/[0.025] px-4 py-3">
            <summary className="cursor-pointer text-sm font-medium text-text focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-cyan/60">
              Read the clip transcript
            </summary>
            <p className="mt-3 text-sm leading-7 text-subdued">{asset.transcript}</p>
          </details>
        ) : null}
      </figcaption>
    </figure>
  );
}
