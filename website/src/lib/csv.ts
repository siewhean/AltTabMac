export type CsvCellValue = string | number | null | undefined | Date;

const SPREADSHEET_FORMULA_PREFIX = /^[=+\-@\t\r]/;

export function escapeCsvCell(value: CsvCellValue) {
  const text = String(value ?? "");
  const neutralized = SPREADSHEET_FORMULA_PREFIX.test(text) ? `'${text}` : text;
  return `"${neutralized.replace(/"/g, '""')}"`;
}
