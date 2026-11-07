import { Env, DeviceRecord, PremiumRecord } from './types';

const DEVICE_PREFIX = 'device:';
const PREMIUM_PREFIX = 'rc:';
const PREMIUM_CACHE_MS = 60 * 60 * 1000;
const REVENUECAT_TIMEOUT_MS = 10_000;

interface RevenueCatEntitlement {
  expires_date: string | null;
  grace_period_expires_date?: string | null;
}

interface RevenueCatSubscriberResponse {
  subscriber?: {
    entitlements?: Record<string, RevenueCatEntitlement>;
  };
}

function isEntitlementActive(entitlement: RevenueCatEntitlement | undefined, now: number): {
  active: boolean;
  expiresAt: string | null;
} {
  if (!entitlement) return { active: false, expiresAt: null };
  const expiry = entitlement.grace_period_expires_date ?? entitlement.expires_date;
  if (expiry === null || expiry === undefined) return { active: true, expiresAt: null };
  return { active: Date.parse(expiry) > now, expiresAt: expiry };
}

function isRecordFresh(record: PremiumRecord, now: number): boolean {
  if (now - record.checkedAt > PREMIUM_CACHE_MS) return false;
  if (record.isPremium && record.expiresAt && Date.parse(record.expiresAt) <= now) return false;
  return true;
}

async function fetchFromRevenueCat(env: Env, revenueCatId: string): Promise<PremiumRecord | null> {
  if (!env.REVENUECAT_API_KEY) return null;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REVENUECAT_TIMEOUT_MS);
  try {
    const response = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(revenueCatId)}`,
      {
        headers: { Authorization: `Bearer ${env.REVENUECAT_API_KEY}` },
        signal: controller.signal,
      }
    );
    if (!response.ok) {
      console.error('RevenueCat lookup failed:', response.status);
      return null;
    }
    const data = (await response.json()) as RevenueCatSubscriberResponse;
    const now = Date.now();
    const { active, expiresAt } = isEntitlementActive(
      data.subscriber?.entitlements?.[env.REVENUECAT_ENTITLEMENT_ID],
      now
    );
    return { isPremium: active, expiresAt, checkedAt: now };
  } catch (error) {
    console.error('RevenueCat lookup error:', error);
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

/**
 * Resolves premium status for a RevenueCat app user id, using a short-lived KV
 * cache. Fails closed (not premium) when RevenueCat can't be reached and nothing
 * is cached.
 */
export async function getPremiumStatus(
  env: Env,
  revenueCatId: string,
  forceRefresh = false
): Promise<PremiumRecord> {
  const key = `${PREMIUM_PREFIX}${revenueCatId}`;
  const cached = await env.USERS.get<PremiumRecord>(key, 'json');
  const now = Date.now();

  if (cached && !forceRefresh && isRecordFresh(cached, now)) {
    return cached;
  }

  const fresh = await fetchFromRevenueCat(env, revenueCatId);
  if (!fresh) {
    // Keep honoring a still-valid cached entitlement during RevenueCat outages.
    if (cached?.isPremium && (!cached.expiresAt || Date.parse(cached.expiresAt) > now)) {
      return cached;
    }
    return { isPremium: false, expiresAt: null, checkedAt: now };
  }

  await env.USERS.put(key, JSON.stringify(fresh), { expirationTtl: 60 * 60 * 24 * 30 });
  return fresh;
}

export async function isDevicePremium(env: Env, deviceId: string): Promise<boolean> {
  const device = await env.USERS.get<DeviceRecord>(`${DEVICE_PREFIX}${deviceId}`, 'json');
  if (!device?.revenueCatId) return false;
  return (await getPremiumStatus(env, device.revenueCatId)).isPremium;
}

export async function linkRevenueCatUser(
  env: Env,
  deviceId: string,
  revenueCatId: string
): Promise<PremiumRecord> {
  const record: DeviceRecord = { revenueCatId, linkedAt: new Date().toISOString() };
  await env.USERS.put(`${DEVICE_PREFIX}${deviceId}`, JSON.stringify(record));
  return getPremiumStatus(env, revenueCatId, true);
}

/** Drops cached entitlement state so the next request re-checks RevenueCat. */
export async function invalidatePremium(env: Env, revenueCatIds: string[]): Promise<void> {
  const unique = [...new Set(revenueCatIds.filter((id) => typeof id === 'string' && id.length > 0))];
  await Promise.all(unique.map((id) => env.USERS.delete(`${PREMIUM_PREFIX}${id}`)));
}
