
export function maskEmail(
  email: string | null | undefined,
  keepStart: number = 1,
  keepEnd: number = 0
): string {
  if (!email) return '';
  const atIndex = email.indexOf('@');
  if (atIndex <= 0) return email;

  const local = email.slice(0, atIndex);
  const domain = email.slice(atIndex);

  // 本地部分太短，就不脱敏
  if (local.length <= keepStart + keepEnd) {
    return email;
  }

  const start = local.slice(0, keepStart);
  const end = local.slice(local.length - keepEnd);
  const stars = '*'.repeat(local.length - keepStart - keepEnd);

  return `${start}${stars}${end}${domain}`;
}