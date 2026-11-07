import { Env, TokenPayload, DecomposeRequest, DecomposeResponse, UsageResponse } from './types';
import { createToken, verifyToken, generateDeviceId } from './auth';
import { getQuota, reserveUsage, refundUsage, throttle, QuotaStatus } from './ratelimit';
import { getCachedResponse, cacheResponse, decomposeTask, getSubSteps } from './openai';
import { isDevicePremium, linkRevenueCatUser, invalidatePremium } from './premium';

// Abuse throttles (apply to everyone, including premium).
const AI_REQUESTS_PER_HOUR = 60;
const REGISTRATIONS_PER_IP_PER_HOUR = 10;
const MAX_TASK_CONTEXT_CHARS = 500;
const FEEDBACK_PER_DEVICE_PER_DAY = 5;
const MAX_FEEDBACK_CHARS = 4000;
const FEEDBACK_TTL_SECONDS = 180 * 24 * 3600;

const VALID_STYLES = ['standard', 'quick', 'gentle'] as const;
const VALID_TIMES = ['morning', 'afternoon', 'evening', 'night'] as const;
const VALID_ENERGY = ['low', 'medium', 'high'] as const;

// CORS headers
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
};

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...corsHeaders,
    },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ success: false, error: message }, status);
}

function usageBody(quota: QuotaStatus) {
  return { used: quota.used, limit: quota.limit, remaining: quota.remaining };
}

function freeLimitResponse(quota: QuotaStatus): Response {
  return jsonResponse(
    {
      success: false,
      error: 'Free breakdowns used up',
      code: 'FREE_LIMIT_REACHED',
      usage: usageBody(quota),
    },
    429
  );
}

function throttledResponse(): Response {
  return jsonResponse(
    {
      success: false,
      error: 'Too many requests. Please slow down and try again later.',
      code: 'RATE_LIMITED',
    },
    429
  );
}

// Extract and verify auth token
async function authenticate(request: Request, env: Env): Promise<TokenPayload | null> {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.slice(7);
  return verifyToken(token, env.JWT_SECRET);
}

function isOneOf<T extends string>(value: unknown, allowed: readonly T[]): value is T {
  return typeof value === 'string' && (allowed as readonly string[]).includes(value);
}

// Validate decompose request
export function validateDecomposeRequest(body: unknown): DecomposeRequest | null {
  if (!body || typeof body !== 'object') return null;

  const req = body as Record<string, unknown>;

  if (typeof req.task !== 'string' || req.task.trim().length === 0) {
    return null;
  }

  if (req.task.length > 500) {
    return null;
  }

  if (req.style !== undefined && req.style !== null && !isOneOf(req.style, VALID_STYLES)) {
    return null;
  }

  let context: DecomposeRequest['context'];
  if (req.context && typeof req.context === 'object') {
    const ctx = req.context as Record<string, unknown>;
    context = {
      timeOfDay: isOneOf(ctx.timeOfDay, VALID_TIMES) ? ctx.timeOfDay : undefined,
      energy: isOneOf(ctx.energy, VALID_ENERGY) ? ctx.energy : undefined,
    };
  }

  return {
    task: req.task.trim(),
    style: isOneOf(req.style, VALID_STYLES) ? req.style : 'standard',
    context,
  };
}

/**
 * Shared gate for AI endpoints: abuse throttle, then (for free users) reserve
 * one of the lifetime free breakdowns. Returns an error Response to send, or the
 * state needed to refund on failure.
 */
async function gateAiRequest(
  env: Env,
  deviceId: string
): Promise<{ error: Response } | { isPremium: boolean; quota: QuotaStatus }> {
  if (!(await throttle(env, `ai:${deviceId}`, AI_REQUESTS_PER_HOUR, 3600))) {
    return { error: throttledResponse() };
  }

  const isPremium = await isDevicePremium(env, deviceId);
  if (isPremium) {
    return { isPremium, quota: await getQuota(env, deviceId, true) };
  }

  const quota = await reserveUsage(env, deviceId);
  if (!quota.allowed) {
    return { error: freeLimitResponse(quota) };
  }
  return { isPremium, quota };
}

// Route handlers
async function handleRegister(request: Request, env: Env): Promise<Response> {
  const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
  if (!(await throttle(env, `register:${ip}`, REGISTRATIONS_PER_IP_PER_HOUR, 3600))) {
    return throttledResponse();
  }

  const deviceId = generateDeviceId();
  const token = await createToken({ deviceId }, env.JWT_SECRET);

  return jsonResponse({
    success: true,
    token,
    deviceId,
  });
}

async function handleDecompose(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!auth) {
    return errorResponse('Unauthorized', 401);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return errorResponse('Invalid JSON body');
  }

  const decomposeReq = validateDecomposeRequest(body);
  if (!decomposeReq) {
    return errorResponse('Invalid request: task is required (max 500 chars)');
  }

  const gate = await gateAiRequest(env, auth.deviceId);
  if ('error' in gate) return gate.error;

  let result: DecomposeResponse;
  try {
    // Cache hits still consume a free breakdown (prevents cache farming).
    const cached = await getCachedResponse(env, decomposeReq);
    if (cached) {
      result = cached;
    } else {
      result = await decomposeTask(env, decomposeReq);
      if (result.success) {
        await cacheResponse(env, decomposeReq, result);
      }
    }
  } catch (error) {
    if (!gate.isPremium) await refundUsage(env, auth.deviceId);
    throw error;
  }

  if (!result.success) {
    if (!gate.isPremium) await refundUsage(env, auth.deviceId);
    return jsonResponse(result, 502);
  }

  return jsonResponse({ ...result, usage: usageBody(gate.quota) });
}

async function handleSubSteps(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!auth) {
    return errorResponse('Unauthorized', 401);
  }

  let body: { step?: unknown; taskContext?: unknown };
  try {
    body = await request.json();
  } catch {
    return errorResponse('Invalid JSON body');
  }

  if (!body || typeof body.step !== 'string' || body.step.trim().length === 0) {
    return errorResponse('Invalid request: step is required');
  }

  if (body.step.length > 300) {
    return errorResponse('Step text too long (max 300 chars)');
  }

  const taskContext =
    typeof body.taskContext === 'string' && body.taskContext.trim().length > 0
      ? body.taskContext.trim().slice(0, MAX_TASK_CONTEXT_CHARS)
      : undefined;

  const gate = await gateAiRequest(env, auth.deviceId);
  if ('error' in gate) return gate.error;

  let result: Awaited<ReturnType<typeof getSubSteps>>;
  try {
    result = await getSubSteps(env, body.step.trim(), taskContext);
  } catch (error) {
    if (!gate.isPremium) await refundUsage(env, auth.deviceId);
    throw error;
  }

  if (!result.success) {
    if (!gate.isPremium) await refundUsage(env, auth.deviceId);
    return jsonResponse(result, 502);
  }

  return jsonResponse({ ...result, usage: usageBody(gate.quota) });
}

async function handleUsage(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!auth) {
    return errorResponse('Unauthorized', 401);
  }

  const isPremium = await isDevicePremium(env, auth.deviceId);
  const quota = await getQuota(env, auth.deviceId, isPremium);
  const body: UsageResponse = { ...usageBody(quota), isPremium };
  return jsonResponse(body);
}

async function handleVerifySubscription(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!auth) {
    return errorResponse('Unauthorized', 401);
  }

  let body: { revenueCatUserId?: unknown; userId?: unknown };
  try {
    body = await request.json();
  } catch {
    return errorResponse('Invalid JSON body');
  }

  const revenueCatId = body?.revenueCatUserId ?? body?.userId;
  if (typeof revenueCatId !== 'string' || revenueCatId.length === 0 || revenueCatId.length > 200) {
    return errorResponse('Invalid request: revenueCatUserId is required');
  }

  const status = await linkRevenueCatUser(env, auth.deviceId, revenueCatId);
  return jsonResponse({ success: true, isPremium: status.isPremium });
}

function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const aBytes = enc.encode(a);
  const bBytes = enc.encode(b);
  let diff = aBytes.length ^ bBytes.length;
  for (let i = 0; i < Math.max(aBytes.length, bBytes.length); i++) {
    diff |= (aBytes[i] ?? 0) ^ (bBytes[i] ?? 0);
  }
  return diff === 0;
}

async function handleRevenueCatWebhook(request: Request, env: Env): Promise<Response> {
  const secret = env.REVENUECAT_WEBHOOK_SECRET;
  if (!secret) {
    console.error('RevenueCat webhook received but REVENUECAT_WEBHOOK_SECRET is not set');
    return errorResponse('Webhook not configured', 503);
  }

  const header = request.headers.get('Authorization') ?? '';
  if (!timingSafeEqual(header, secret) && !timingSafeEqual(header, `Bearer ${secret}`)) {
    return errorResponse('Unauthorized', 401);
  }

  let body: { event?: Record<string, unknown> };
  try {
    body = await request.json();
  } catch {
    return errorResponse('Invalid JSON body');
  }

  const event = body?.event ?? {};
  const ids: string[] = [];
  for (const field of ['app_user_id', 'original_app_user_id']) {
    if (typeof event[field] === 'string') ids.push(event[field] as string);
  }
  for (const field of ['aliases', 'transferred_from', 'transferred_to']) {
    const value = event[field];
    if (Array.isArray(value)) ids.push(...value.filter((v): v is string => typeof v === 'string'));
  }

  // Entitlement state is re-fetched from RevenueCat on next use.
  await invalidatePremium(env, ids);
  return jsonResponse({ success: true });
}

/**
 * Stores user feedback in KV under `feedback:{timestamp}:{deviceId}`.
 * Read with: wrangler kv key list --binding USERS --prefix feedback:
 */
async function handleFeedback(request: Request, env: Env): Promise<Response> {
  const auth = await authenticate(request, env);
  if (!auth) {
    return errorResponse('Unauthorized', 401);
  }

  let body: { message?: unknown; email?: unknown; appVersion?: unknown; platform?: unknown };
  try {
    body = await request.json();
  } catch {
    return errorResponse('Invalid JSON body');
  }

  const message = typeof body?.message === 'string' ? body.message.trim() : '';
  if (message.length === 0 || message.length > MAX_FEEDBACK_CHARS) {
    return errorResponse('Invalid request: message is required');
  }
  const email =
    typeof body.email === 'string' && body.email.length <= 254 ? body.email.trim() : undefined;
  const short = (v: unknown) => (typeof v === 'string' ? v.slice(0, 50) : undefined);

  if (!(await throttle(env, `feedback:${auth.deviceId}`, FEEDBACK_PER_DEVICE_PER_DAY, 86400))) {
    return throttledResponse();
  }

  const receivedAt = new Date().toISOString();
  await env.USERS.put(
    `feedback:${receivedAt}:${auth.deviceId}`,
    JSON.stringify({
      message,
      email: email || undefined,
      appVersion: short(body.appVersion),
      platform: short(body.platform),
      deviceId: auth.deviceId,
      receivedAt,
    }),
    { expirationTtl: FEEDBACK_TTL_SECONDS }
  );
  return jsonResponse({ success: true });
}

async function handleHealth(): Promise<Response> {
  return jsonResponse({
    status: 'healthy',
    timestamp: new Date().toISOString(),
  });
}

// Main router
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      if (path === '/health' && request.method === 'GET') {
        return await handleHealth();
      }

      if (path === '/v1/register' && request.method === 'POST') {
        return await handleRegister(request, env);
      }

      if (path === '/v1/decompose' && request.method === 'POST') {
        return await handleDecompose(request, env);
      }

      if (path === '/v1/usage' && request.method === 'GET') {
        return await handleUsage(request, env);
      }

      if (path === '/v1/verify-subscription' && request.method === 'POST') {
        return await handleVerifySubscription(request, env);
      }

      if (path === '/v1/substeps' && request.method === 'POST') {
        return await handleSubSteps(request, env);
      }

      if (path === '/v1/feedback' && request.method === 'POST') {
        return await handleFeedback(request, env);
      }

      if (path === '/v1/webhook/revenuecat' && request.method === 'POST') {
        return await handleRevenueCatWebhook(request, env);
      }

      return errorResponse('Not found', 404);
    } catch (error) {
      console.error('Unhandled error:', error);
      return errorResponse('Internal server error', 500);
    }
  },
};
