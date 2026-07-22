import { screenshotAssets } from "@/content/media";

export function ScreenshotFrame({
  assetId,
  className = "",
  caption,
  priority = false,
  showCaption = true,
}: {
  assetId: keyof typeof screenshotAssets;
  className?: string;
  caption?: string;
  priority?: boolean;
  showCaption?: boolean;
}) {
  const asset = screenshotAssets[assetId];

  return (
    <figure className={`group ${className}`}>
      <div className="surface-panel relative overflow-hidden bg-panel/70 transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:-translate-y-0.5">
        <div className="absolute inset-x-0 top-0 h-24 bg-gradient-to-b from-white/8 to-transparent" />
        <img
          src={asset.src}
          alt={asset.alt}
          width={asset.width}
          height={asset.height}
          loading={priority || asset.priority ? "eager" : "lazy"}
          className="h-auto w-full transition-transform duration-300 ease-[cubic-bezier(0.22,1,0.36,1)] group-hover:scale-[1.005]"
        />
      </div>
      {showCaption && (caption || asset.caption) ? (
        <figcaption className="mt-3 max-w-2xl text-sm leading-6 text-subdued">
          {caption ?? asset.caption}
        </figcaption>
      ) : null}
    </figure>
  );
}
