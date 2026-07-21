export function LastReviewed({
  date = "2026-07-20",
  label = "Last reviewed",
}: {
  date?: string;
  label?: string;
}) {
  const formatted = new Intl.DateTimeFormat("en", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${date}T00:00:00Z`));

  return (
    <p className="text-sm text-subdued">
      {label}: <time dateTime={date}>{formatted}</time>
    </p>
  );
}
