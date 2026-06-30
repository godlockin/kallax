/**
 * KALLAX Secret Redaction Utility
 *
 * v3.5.0 hotfix: 跟 B 组 Attack Review S-003 治根 联合, 跟 V310-B S-001 fail-closed 1:1 联合.
 * 用途: 在 logger.error / logger.warn 输出前 mask 凭据 (password / token / api_key / Bearer / redis://:pwd@host).
 *
 * 跟 Rule 5 DRY 联合: 单一入口, 全 codebase 复用 (跟 audit-middleware 已有 redaction pattern 1:1).
 * 跟 Hard Rule #4 0 magic numbers 联合: 全部 named constants.
 */

export const REDACTED = '***';

const REDIS_AUTH_REGEX = /(\bredis:\/\/[^:]*:)([^@]+)(@)/g;
const AUTH_BEARER_REGEX = /(Bearer\s+)[a-zA-Z0-9._\-]+/g;
const PASSWORD_FIELD_REGEX = /((?:password|passwd|pwd|api_?key|api_?token|secret|token)\s*[=:]\s*)(\S+)/gi;
const IOREDIS_AUTH_LINE_REGEX = /(AUTH failed[^,\n]*)/gi;

export function redactRedisUrl(url: string | undefined | null): string {
  if (url === undefined || url === null || url === '') return '';
  return url.replace(REDIS_AUTH_REGEX, `$1${REDACTED}$3`);
}

export function redactErrorMessage(msg: string | undefined | null): string {
  if (msg === undefined || msg === null || msg === '') return '';
  let out = String(msg);
  out = out.replace(REDIS_AUTH_REGEX, `$1${REDACTED}$3`);
  out = out.replace(AUTH_BEARER_REGEX, `$1${REDACTED}`);
  out = out.replace(PASSWORD_FIELD_REGEX, `$1${REDACTED}`);
  out = out.replace(IOREDIS_AUTH_LINE_REGEX, `AUTH failed (redacted)`);
  return out;
}

export function hasPasswordLeak(text: string | undefined | null): boolean {
  if (text === undefined || text === null || text === '') return false;
  const sanitized = redactErrorMessage(text);
  return sanitized !== text;
}