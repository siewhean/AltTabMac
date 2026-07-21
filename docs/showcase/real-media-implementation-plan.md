# CmdTab showcase media release contract

**Reviewed:** 2026-07-22  
**Branch:** `agent/real-app-showcase-media`  
**PR:** `#20`

## Release objective

Publish a fast, privacy-safe product showcase with stable media URLs, honest provenance, accessible playback, and build-breaking media checks.

## Shipped media set

| Item | Poster | Motion | Provenance |
|---|---|---|---|
| Overview | WebP | Silent H.264 MP4 | Deterministic product composite |
| Classic Grid | WebP | Poster only | Deterministic product composite |
| Command Palette | WebP | Poster only | Deterministic product composite |
| Radial Menu | WebP | Silent H.264 MP4 | Authentic production SwiftUI/AppKit render |
| Quick Actions | WebP | Silent H.264 MP4 | Deterministic product composite |

All items use controlled fixture windows. They are not AI-generated and do not record a private desktop.

## Truth boundary

The showcase demonstrates presentation and controlled interaction concepts. It does not prove signed-app Accessibility, Screen Recording, exact focused `CGWindowID`, Spaces, displays, fullscreen, Stage Manager, signing, notarization, latency, memory use, processor support, or architecture coverage.

## Website behavior

- `/showcase` is the canonical watch page.
- Every media item has a stable poster URL and visible source label.
- Items with a reviewed MP4 use a native muted inline video with Play/Pause, a poster, and reduced-motion support.
- Poster-only items render a real `<img>` fallback; they never create an unexplained black video panel.
- VideoObject structured data is emitted only for entries that actually have an MP4.
- Raw media is excluded from the canonical HTML sitemap.

## Release gates

The production build must fail when:

- a configured poster or video is missing;
- a WebP or MP4 has the wrong signature;
- manifest paths, dimensions, duration, source type, or audio state diverge;
- a poster-only item advertises a nonexistent MP4;
- the showcase loses its provenance or controlled-fixture disclosure;
- unsupported performance, processor, memory, Universal Binary, or ScreenCaptureKit claims enter the showcase.

After build, compiled-server verification checks `/showcase`, every media response, content types, response bytes, range requests, structured data, poster fallbacks, desktop/mobile layout, console errors, and failed network requests.

## Deployment sequence

1. Pass the protected Vercel prebuild gate.
2. Verify the exact preview deployment.
3. Merge the reviewed PR into `main`.
4. Confirm the exact merged commit is the production deployment.
5. Re-run public-domain route and media checks.
6. Submit the changed canonical HTML URLs through IndexNow only after production is live.
