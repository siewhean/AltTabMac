const singaporeDateTimeFormatter = new Intl.DateTimeFormat("en-SG", {
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "numeric",
  minute: "2-digit",
  hour12: true,
  timeZone: "Asia/Singapore",
});

const singaporeDayLabelFormatter = new Intl.DateTimeFormat("en-SG", {
  day: "2-digit",
  month: "short",
  timeZone: "Asia/Singapore",
});

export function formatSingaporeDateTime(value: string | Date) {
  const date = value instanceof Date ? value : new Date(value);
  return `${singaporeDateTimeFormatter.format(date)}`;
}

export function formatSingaporeDayLabel(value: string | Date) {
  const date = value instanceof Date ? value : new Date(value);
  return singaporeDayLabelFormatter.format(date);
}
