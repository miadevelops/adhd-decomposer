import { Env, UsageEntry } from './types';

const USAGE_PREFIX = 'usage:';
const THROTTLE_PREFIX = 'throttle:';
const DEFAULT_FREE_LIMIT = 5;

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
