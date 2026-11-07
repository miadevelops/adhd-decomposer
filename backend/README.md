# Tiny Steps API

Backend API for the Tiny Steps ADHD task decomposition app.

## Setup

### 1. Install dependencies

```bash
npm install
```

### 2. Login to Cloudflare

```bash
npx wrangler login
```

### 3. Create KV namespaces

```bash
# Create the namespaces
npx wrangler kv:namespace create "RATE_LIMITS"
npx wrangler kv:namespace create "CACHE"
npx wrangler kv:namespace create "USERS"

# Copy the IDs and update wrangler.toml
```

### 4. Set secrets

```bash
# OpenAI API key
npx wrangler secret put OPENAI_API_KEY
# (paste your key when prompted)

# JWT secret (generate a random 64-char string)
npx wrangler secret put JWT_SECRET
# (paste a random secret like: openssl rand -hex 32)

# RevenueCat secret API key (Project settings > API keys > Secret key, starts with sk_)
# Used to verify premium entitlements server-side. Without it, nobody is premium.
npx wrangler secret put REVENUECAT_API_KEY

# Shared secret for the RevenueCat webhook (see "RevenueCat Webhook" below)
npx wrangler secret put REVENUECAT_WEBHOOK_SECRET
```

### 5. Update wrangler.toml

Replace the placeholder KV namespace IDs with the real ones from step 3.

### 6. Deploy

```bash
npm run deploy
```

## Local Development

```bash
npm run dev
```

This starts a local server at http://localhost:8787

## API Endpoints

### `POST /v1/register`

Register a new device and get an auth token.

**Response:**
```json
{
  "success": true,
  "token": "eyJ...",
  "deviceId": "abc123..."
}
```

### `POST /v1/decompose`

Break down a task into steps.

**Headers:**
- `Authorization: Bearer <token>`

**Body:**
```json
{
  "task": "Clean my room",
  "style": "standard|quick|gentle",
  "context": {
    "timeOfDay": "morning|afternoon|evening|night",
    "energy": "low|medium|high"
  }
}
```

**Response:**
```json
{
  "success": true,
  "task": {
    "title": "Clean my room",
    "steps": [
      { "action": "Grab a trash bag from under the sink", "estimatedMinutes": 2 },
      { "action": "Walk around the room and pick up obvious trash", "estimatedMinutes": 5 }
    ],
    "totalEstimatedMinutes": 7,
    "encouragement": "You've got this! One step at a time."
  },
  "cached": false,
  "usage": { "used": 1, "limit": 5, "remaining": 4 }
}
```

`usage.limit` / `usage.remaining` are `-1` for premium users. If the AI call fails
the response is `502` and the free breakdown is refunded.

**Limit reached (`429`):**
```json
{
  "success": false,
  "error": "Free breakdowns used up",
  "code": "FREE_LIMIT_REACHED",
  "usage": { "used": 5, "limit": 5, "remaining": 0 }
}
```

`code` is `RATE_LIMITED` (no `usage`) when the hourly abuse throttle trips.

### `POST /v1/substeps`

Break a step the user is stuck on into micro-steps. Counts toward the same free
allowance as `/v1/decompose`.

**Body:**
```json
{
  "step": "Write the intro paragraph",
  "taskContext": "Write blog post"
}
```

**Response:**
```json
{
  "success": true,
  "substeps": ["Open the doc", "Type one sentence"],
  "encouragement": "Tiny is fine.",
  "usage": { "used": 2, "limit": 5, "remaining": 3 }
}
```

### `GET /v1/usage`

Get current usage stats.

**Headers:**
- `Authorization: Bearer <token>`

**Response:**
```json
{
  "used": 2,
  "limit": 5,
  "remaining": 3,
  "isPremium": false
}
```

### `POST /v1/verify-subscription`

Verify premium subscription status (for RevenueCat integration).

**Headers:**
- `Authorization: Bearer <token>`

**Body:**
```json
{
  "revenueCatUserId": "rc_user_123"
}
```

Links this device to the RevenueCat app user id (the app sends `Purchases.appUserID`)
and checks the entitlement with RevenueCat's REST API.

**Response:**
```json
{ "success": true, "isPremium": true }
```

Premium status is never taken from the client or the JWT; it is always resolved
server-side from RevenueCat and cached for up to an hour.

### `POST /v1/feedback`

Submit in-app feedback. Requires the JWT.

**Body:**
```json
{
  "message": "Love it, but ...",
  "email": "optional@example.com",
  "appVersion": "1.0.0",
  "platform": "android"
}
```

`message` is required (1-4000 characters after trimming). Limited to 5 submissions
per device per day. Feedback is stored in the `USERS` KV namespace for 180 days:

```bash
wrangler kv key list --binding USERS --prefix feedback:
wrangler kv key get --binding USERS "feedback:<timestamp>:<deviceId>"
```

**Response:**
```json
{ "success": true }
```

## Limits

- **Free users:** 5 AI breakdowns total per device (lifetime). Task breakdowns and
  "I'm stuck" breakdowns both count. Cached results still count.
- **Premium users:** Unlimited
- **Everyone:** max 60 AI requests per device per hour, and max 10 registrations per IP per hour.

## Caching

Common task decompositions are cached for 24 hours to:
- Reduce API costs
- Improve response times
- Provide consistent results

Cache keys are normalized (lowercase, trimmed, punctuation removed; Unicode-aware) and
include the style and context, then hashed, so slight variations still hit the cache.

## Security

- All requests require a valid JWT (except `/v1/register`)
- Tokens are tied to device IDs
- Rate limiting prevents abuse
- Request validation prevents injection
- CORS headers configured for mobile app access

## RevenueCat Webhook

Set up a webhook in RevenueCat dashboard pointing to:
```
POST https://your-worker.workers.dev/v1/webhook/revenuecat
```

In the webhook settings, set the **Authorization header value** to the same string you
stored in `REVENUECAT_WEBHOOK_SECRET` (either the raw value or `Bearer <value>`).
Requests without a matching header are rejected, and the endpoint returns `503` until
the secret is configured.

Each event clears the cached entitlement for the affected app user ids, so the next
request re-checks RevenueCat (purchases, renewals, cancellations, expirations, transfers).

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | OpenAI API key (secret) |
| `JWT_SECRET` | Secret for signing JWTs (secret) |
| `REVENUECAT_API_KEY` | RevenueCat secret API key for entitlement checks (secret) |
| `REVENUECAT_WEBHOOK_SECRET` | Expected webhook Authorization header (secret) |
| `FREE_LIFETIME_LIMIT` | Total free AI breakdowns per device |
| `REVENUECAT_ENTITLEMENT_ID` | Entitlement that grants premium |
| `CACHE_TTL_SECONDS` | How long to cache responses |

## Cost Estimation

Using GPT-4o-mini:
- ~$0.15 per 1M input tokens
- ~$0.60 per 1M output tokens

Average request: ~500 input + 500 output tokens = ~$0.0004/request

| Users | Requests/day | Monthly cost (no cache) | With 50% cache |
|-------|--------------|-------------------------|----------------|
| 100 | 300 | $3.60 | $1.80 |
| 1,000 | 3,000 | $36 | $18 |
| 10,000 | 30,000 | $360 | $180 |

Cloudflare Workers free tier: 100,000 requests/day
