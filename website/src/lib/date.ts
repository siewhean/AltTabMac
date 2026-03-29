const singaporeDateTimeFormatter = new Intl.DateTimeFormat("en-SG", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
  hour12: true,
  timeZone: "Asia/Singapore",
});

export function formatSingaporeDateTime(value: string | Date) {
  const date = value instanceof Date ? value : new Date(value);
  return `${singaporeDateTimeFormatter.format(date)}`;
}
