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

  return (
    <figure className={`group ${className}`}>
      <div className="relative overflow-hidden rounded-[28px] border border-white/10 bg-panel/70 shadow-panel">
        <div className="absolute inset-x-0 top-0 h-24 bg-gradient-to-b from-white/8 to-transparent" />
        <img
          src={asset.src}
          alt={asset.alt}
          width={asset.width}
          height={asset.height}
          loading={priority || asset.priority ? "eager" : "lazy"}
          className="h-auto w-full transition-transform duration-300 ease-[cubic-bezier(0.23,1,0.32,1)] group-hover:scale-[1.01]"
        />
      </div>
      {(caption || asset.caption) && (
        <figcaption className="mt-3 max-w-2xl text-sm leading-6 text-subdued">
          {caption ?? asset.caption}
        </figcaption>
      )}
    </figure>
  );
}

