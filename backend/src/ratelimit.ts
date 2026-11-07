import { Env, UsageEntry, LegacyDailyEntry } from './types';

const USAGE_PREFIX = 'usage:';
const THROTTLE_PREFIX = 'throttle:';
// Same key format the pre-1.2 backend used, so today's counts carry over.
const LEGACY_DAILY_PREFIX = 'rate:';
const DEFAULT_FREE_LIMIT = 5;
const DEFAULT_LEGACY_DAILY_LIMIT = 3;

export interface QuotaStatus {
  allowed: boolean;
  used: number;
  /** -1 means unlimited */
  limit: number;
  /** -1 means unlimited */
  remaining: number;
}

export function getFreeLimit(env: Env): number {
  const parsed = parseInt(env.FREE_LIFETIME_LIMIT ?? '', 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : DEFAULT_FREE_LIMIT;
}

async function getUsedCount(env: Env, deviceId: string): Promise<number> {
  const entry = await env.RATE_LIMITS.get<UsageEntry>(`${USAGE_PREFIX}${deviceId}`, 'json');
  return entry?.count ?? 0;
}

async function setUsedCount(env: Env, deviceId: string, count: number): Promise<void> {
  // Lifetime allowance: no expiration.
  await env.RATE_LIMITS.put(`${USAGE_PREFIX}${deviceId}`, JSON.stringify({ count } satisfies UsageEntry));
}

function status(used: number, limit: number): QuotaStatus {
  return {
    allowed: used < limit,
    used,
    limit,
    remaining: Math.max(0, limit - used),
  };
}

const UNLIMITED: QuotaStatus = { allowed: true, used: 0, limit: -1, remaining: -1 };

export async function getQuota(env: Env, deviceId: string, isPremium: boolean): Promise<QuotaStatus> {
  if (isPremium) return UNLIMITED;
  return status(await getUsedCount(env, deviceId), getFreeLimit(env));
}

/**
 * Reserves one free AI use before the (slow) OpenAI call so concurrent requests
 * can't all pass the check. KV has no atomic increment, so a tiny race window
 * remains; call refundUsage if the request ultimately fails.
 */
export async function reserveUsage(env: Env, deviceId: string): Promise<QuotaStatus> {
  const limit = getFreeLimit(env);
  const used = await getUsedCount(env, deviceId);
  if (used >= limit) {
    return status(used, limit);
  }
  await setUsedCount(env, deviceId, used + 1);
  return { ...status(used + 1, limit), allowed: true };
}

export async function refundUsage(env: Env, deviceId: string): Promise<void> {
  const used = await getUsedCount(env, deviceId);
  if (used > 0) {
    await setUsedCount(env, deviceId, used - 1);
  }
}

// ---------------------------------------------------------------------------
// Legacy daily limit for app versions released before the lifetime quota.
// Those clients never link their RevenueCat id, so they keep the original
// "N decompositions per UTC day, sub-steps unlimited" behaviour.
// ---------------------------------------------------------------------------

export interface LegacyQuotaStatus extends QuotaStatus {
  /** ISO timestamp of the next UTC midnight */
  resetsAt: string;
}

export function getLegacyDailyLimit(env: Env): number {
  const parsed = parseInt(env.LEGACY_DAILY_LIMIT ?? '', 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : DEFAULT_LEGACY_DAILY_LIMIT;
}

function utcToday(): string {
  return new Date().toISOString().split('T')[0];
}

function legacyKey(deviceId: string, day: string): string {
  return `${LEGACY_DAILY_PREFIX}${deviceId}:${day}`;
}

function nextUtcMidnight(): string {
  const tomorrow = new Date();
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  tomorrow.setUTCHours(0, 0, 0, 0);
  return tomorrow.toISOString();
}

async function getLegacyUsed(env: Env, deviceId: string, day: string): Promise<number> {
  const entry = await env.RATE_LIMITS.get<LegacyDailyEntry>(legacyKey(deviceId, day), 'json');
  return entry?.count ?? 0;
}

async function setLegacyUsed(env: Env, deviceId: string, day: string, count: number): Promise<void> {
  await env.RATE_LIMITS.put(
    legacyKey(deviceId, day),
    JSON.stringify({ count, date: day } satisfies LegacyDailyEntry),
    { expirationTtl: 86400 + 3600 }
  );
}

function legacyStatus(used: number, limit: number): LegacyQuotaStatus {
  return { ...status(used, limit), resetsAt: nextUtcMidnight() };
}

export async function getLegacyQuota(
  env: Env,
  deviceId: string,
  isPremium: boolean
): Promise<LegacyQuotaStatus> {
  if (isPremium) return { ...UNLIMITED, resetsAt: '' };
  return legacyStatus(await getLegacyUsed(env, deviceId, utcToday()), getLegacyDailyLimit(env));
}

export async function reserveLegacyUsage(env: Env, deviceId: string): Promise<LegacyQuotaStatus> {
  const day = utcToday();
  const limit = getLegacyDailyLimit(env);
  const used = await getLegacyUsed(env, deviceId, day);
  if (used >= limit) {
    return legacyStatus(used, limit);
  }
  await setLegacyUsed(env, deviceId, day, used + 1);
  return { ...legacyStatus(used + 1, limit), allowed: true };
}

export async function refundLegacyUsage(env: Env, deviceId: string): Promise<void> {
  const day = utcToday();
  const used = await getLegacyUsed(env, deviceId, day);
  if (used > 0) {
    await setLegacyUsed(env, deviceId, day, used - 1);
  }
}

/**
 * Fixed-window throttle. Returns true if the request is allowed.
 */
export async function throttle(
  env: Env,
  key: string,
  maxRequests: number,
  windowSeconds: number
): Promise<boolean> {
  const window = Math.floor(Date.now() / 1000 / windowSeconds);
  const kvKey = `${THROTTLE_PREFIX}${key}:${window}`;
  const count = parseInt((await env.RATE_LIMITS.get(kvKey)) ?? '0', 10) || 0;
  if (count >= maxRequests) return false;
  // KV minimum TTL is 60 seconds.
  await env.RATE_LIMITS.put(kvKey, String(count + 1), {
    expirationTtl: Math.max(60, windowSeconds * 2),
  });
  return true;
}
