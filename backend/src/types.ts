// Cloudflare Worker Types
export interface Env {
  // KV Namespaces
  RATE_LIMITS: KVNamespace;
  CACHE: KVNamespace;
  USERS: KVNamespace;
  
  // Secrets
  OPENAI_API_KEY: string;
  JWT_SECRET: string;
  // RevenueCat secret API key (v1 REST), used to verify entitlements server-side
  REVENUECAT_API_KEY?: string;
  // Value RevenueCat sends in the webhook Authorization header
  REVENUECAT_WEBHOOK_SECRET?: string;
  
  // Config
  ENVIRONMENT: string;
  FREE_LIFETIME_LIMIT: string;
  // Daily decompose limit for app versions that predate the lifetime quota
  // (requests without the X-TinySteps-Client header). "0" disables legacy mode.
  LEGACY_DAILY_LIMIT?: string;
  REVENUECAT_ENTITLEMENT_ID: string;
  CACHE_TTL_SECONDS: string;
}

// API Types
export interface DecomposeRequest {
  task: string;
  style?: 'standard' | 'quick' | 'gentle';
  context?: {
    timeOfDay?: 'morning' | 'afternoon' | 'evening' | 'night';
    energy?: 'low' | 'medium' | 'high';
  };
}

export interface StepDetail {
  action: string;
  estimatedMinutes: number;
}

export interface DecomposeResponse {
  success: boolean;
  task?: {
    title: string;
    steps: StepDetail[];
    totalEstimatedMinutes: number;
    encouragement: string;
  };
  cached?: boolean;
  error?: string;
}

export interface UsageResponse {
  used: number;
  /** -1 means unlimited (premium) */
  limit: number;
  /** -1 means unlimited (premium) */
  remaining: number;
  isPremium: boolean;
}

export interface TokenPayload {
  deviceId: string;
  /** Legacy claim from older tokens. Ignored: premium is always verified server-side. */
  isPremium?: boolean;
  iat: number;
  exp: number;
}

export interface UsageEntry {
  count: number;
}

/** Per-day counter used by legacy (pre-lifetime-quota) app versions. */
export interface LegacyDailyEntry {
  count: number;
  date: string;
}

export interface DeviceRecord {
  revenueCatId?: string;
  linkedAt?: string;
}

export interface PremiumRecord {
  isPremium: boolean;
  /** ISO date of entitlement expiry, null for lifetime / non-expiring */
  expiresAt: string | null;
  /** epoch millis of last RevenueCat check */
  checkedAt: number;
}
