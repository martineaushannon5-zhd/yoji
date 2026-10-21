export function formatDate(value: string | null | undefined): string {
  if (!value) {
    return "—";
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  const y = date.getFullYear();
  const m = `${date.getMonth() + 1}`.padStart(2, "0");
  const d = `${date.getDate()}`.padStart(2, "0");
  return `${y}/${m}/${d}`;
}

export function formatNumber(value: number | null | undefined): string {
  return new Intl.NumberFormat("zh-CN").format(Number(value) || 0);
}

export function initials(name: string): string {
  const value = (name || "A").trim();
  return value.slice(0, 1).toUpperCase();
}
