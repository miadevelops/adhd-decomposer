import { Env, DecomposeRequest, DecomposeResponse, StepDetail } from './types';

const CACHE_PREFIX = 'decompose:v2:';
const OPENAI_URL = 'https://api.openai.com/v1/chat/completions';
const OPENAI_TIMEOUT_MS = 25_000;
const MAX_STEPS = 15;
const MAX_SUBSTEPS = 8;

// Normalize task for cache key. Unicode-aware so non-Latin tasks don't collapse
// to the same (empty) key.
export function normalizeTask(task: string): string {
  return task
    .normalize('NFKC')
    .toLowerCase()
    .trim()
    .replace(/[^\p{L}\p{N}\s]/gu, '')
    .replace(/\s+/g, ' ');
}

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

export async function getCacheKey(request: DecomposeRequest): Promise<string> {
  const style = request.style || 'standard';
  const ctx = request.context ?? {};
  const material = [style, ctx.timeOfDay ?? '', ctx.energy ?? '', normalizeTask(request.task)].join('|');
  return `${CACHE_PREFIX}${await sha256Hex(material)}`;
}

export async function getCachedResponse(
  env: Env,
  request: DecomposeRequest
): Promise<DecomposeResponse | null> {
  const cached = await env.CACHE.get<DecomposeResponse>(await getCacheKey(request), 'json');
  if (cached?.success && cached.task) {
    return { ...cached, cached: true };
  }
  return null;
}

export async function cacheResponse(
  env: Env,
  request: DecomposeRequest,
  response: DecomposeResponse
): Promise<void> {
  const ttl = parseInt(env.CACHE_TTL_SECONDS) || 86400;
  await env.CACHE.put(await getCacheKey(request), JSON.stringify(response), { expirationTtl: ttl });
}

async function callOpenAI(env: Env, body: Record<string, unknown>): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), OPENAI_TIMEOUT_MS);
  try {
    return await fetch(OPENAI_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeout);
  }
}

function clampMinutes(value: unknown, fallback: number): number {
  const n = typeof value === 'number' ? value : parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(120, Math.max(1, Math.round(n)));
}

export function normalizeSteps(rawSteps: unknown): StepDetail[] {
  if (!Array.isArray(rawSteps)) return [];
  return rawSteps
    .map((s): StepDetail | null => {
      if (typeof s === 'string') {
        return { action: s.trim(), estimatedMinutes: 5 };
      }
      if (s && typeof s === 'object' && typeof (s as { action?: unknown }).action === 'string') {
        const step = s as { action: string; estimatedMinutes?: unknown };
        return { action: step.action.trim(), estimatedMinutes: clampMinutes(step.estimatedMinutes, 5) };
      }
      return null;
    })
    .filter((s): s is StepDetail => s !== null && s.action.length > 0)
    .slice(0, MAX_STEPS);
}

// System prompts for different styles
const JSON_FORMAT = `
Respond with JSON only:
{
  "title": "<short descriptive title for the task>",
  "steps": [
    { "action": "<clear action description>", "estimatedMinutes": <minutes for this step> }
  ],
  "encouragement": "<brief motivating message>"
}`;

const STYLE_PROMPTS = {
  standard: `You are an ADHD task coach. Break down the given task into small, actionable steps.

Rules:
- Each step should take 2-10 minutes max
- Use clear, specific action verbs (grab, open, write, move)
- Include micro-steps that might seem obvious (ADHD brains need explicit steps)
- Add brief context/location when helpful
- 5-8 steps is ideal
- End with a small reward or acknowledgment step
- Each step must include a realistic time estimate in minutes
${JSON_FORMAT}`,

  quick: `You are an ADHD task coach. Break down the given task into exactly 5 quick steps.

Rules:
- Maximum 5 steps, no more
- Each step ultra-concise (under 10 words)
- Action verbs only
- No fluff, just essentials
- Each step must include a realistic time estimate in minutes
${JSON_FORMAT}`,

  gentle: `You are a supportive ADHD coach. Break down the given task with extra care and gentleness.

Rules:
- Smaller steps than usual (1-5 minutes each)
- Include permission to pause between steps
- Add sensory grounding cues (take a breath, notice your feet)
- Acknowledge difficulty without judgment
- Include self-compassion reminders
- 6-10 steps is fine
- Each step must include a realistic time estimate in minutes
${JSON_FORMAT}`,
};

// Context additions
function getContextAddition(context?: DecomposeRequest['context']): string {
  if (!context) return '';
  
  const additions: string[] = [];
  
  if (context.timeOfDay) {
    const timeHints: Record<string, string> = {
      morning: 'Consider morning energy levels and routines.',
      afternoon: 'Account for post-lunch energy dip.',
      evening: 'Keep steps simple, energy may be low.',
      night: 'Ultra-simple steps only, minimal cognitive load.',
    };
    additions.push(timeHints[context.timeOfDay]);
  }
  
  if (context.energy) {
    const energyHints: Record<string, string> = {
      low: 'User has low energy - make steps extra small and gentle.',
      medium: 'Normal energy level.',
      high: 'User has good energy - can handle slightly bigger steps.',
    };
    additions.push(energyHints[context.energy]);
  }
  
  return additions.length > 0 ? `\n\nContext: ${additions.join(' ')}` : '';
}

export async function decomposeTask(
  env: Env,
  request: DecomposeRequest
): Promise<DecomposeResponse> {
  const style = request.style || 'standard';
  const systemPrompt = STYLE_PROMPTS[style] + getContextAddition(request.context);

  try {
    const response = await callOpenAI(env, {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: `Break down this task: ${request.task}` },
      ],
      temperature: 0.7,
      max_tokens: 1000,
      response_format: { type: 'json_object' },
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('OpenAI API error:', error);
      return {
        success: false,
        error: 'AI service temporarily unavailable',
      };
    }

    const data = await response.json() as {
      choices: Array<{ message: { content: string } }>;
    };

    const content = data.choices[0]?.message?.content;
    if (!content) {
      return {
        success: false,
        error: 'Empty response from AI',
      };
    }

    const parsed = JSON.parse(content);

    // Supports both string[] (legacy) and {action, estimatedMinutes}[] formats.
    const steps = normalizeSteps(parsed?.steps);
    if (steps.length === 0) {
      console.error('OpenAI returned no usable steps');
      return {
        success: false,
        error: 'AI returned an empty breakdown',
      };
    }

    const totalEstimatedMinutes = steps.reduce((sum: number, s: StepDetail) => sum + s.estimatedMinutes, 0);

    return {
      success: true,
      task: {
        title: typeof parsed.title === 'string' && parsed.title.trim() ? parsed.title.trim() : request.task,
        steps,
        totalEstimatedMinutes,
        encouragement:
          typeof parsed.encouragement === 'string' && parsed.encouragement.trim()
            ? parsed.encouragement.trim()
            : 'You\'ve got this!',
      },
      cached: false,
    };
  } catch (error) {
    console.error('Decompose error:', error);
    return {
      success: false,
      error: 'Failed to process task',
    };
  }
}

// Sub-steps prompt for when users are stuck
const SUBSTEPS_PROMPT = `You are an ADHD task coach helping someone who is stuck on a step.

Break this step into 3-5 MICRO-steps that are:
- Extremely small (1-3 minutes each)
- Physical and concrete (stand up, open app, move hand)
- Include the very first tiny action to start
- No thinking or decision-making required

The goal is to make starting feel effortless.

Respond with JSON only:
{
  "substeps": ["micro-step 1", "micro-step 2", ...],
  "encouragement": "<brief, warm encouragement>"
}`;

export async function getSubSteps(
  env: Env,
  step: string,
  taskContext?: string
): Promise<{ success: boolean; substeps?: string[]; encouragement?: string; error?: string }> {
  const userMessage = taskContext 
    ? `Task context: ${taskContext}\n\nStep I'm stuck on: ${step}`
    : `Step I'm stuck on: ${step}`;

  try {
    const response = await callOpenAI(env, {
      model: 'gpt-4o-mini',
      messages: [
        { role: 'system', content: SUBSTEPS_PROMPT },
        { role: 'user', content: userMessage },
      ],
      temperature: 0.7,
      max_tokens: 500,
      response_format: { type: 'json_object' },
    });

    if (!response.ok) {
      const error = await response.text();
      console.error('OpenAI API error:', error);
      return {
        success: false,
        error: 'AI service temporarily unavailable',
      };
    }

    const data = await response.json() as {
      choices: Array<{ message: { content: string } }>;
    };

    const content = data.choices[0]?.message?.content;
    if (!content) {
      return {
        success: false,
        error: 'Empty response from AI',
      };
    }

    const parsed = JSON.parse(content);
    const substeps = Array.isArray(parsed?.substeps)
      ? (parsed.substeps as unknown[])
          .filter((s): s is string => typeof s === 'string')
          .map((s) => s.trim())
          .filter((s) => s.length > 0)
          .slice(0, MAX_SUBSTEPS)
      : [];
    if (substeps.length === 0) {
      console.error('OpenAI returned no usable substeps');
      return {
        success: false,
        error: 'AI returned an empty breakdown',
      };
    }
    return {
      success: true,
      substeps,
      encouragement: typeof parsed.encouragement === 'string' ? parsed.encouragement : undefined,
    };
  } catch (error) {
    console.error('SubSteps error:', error);
    return {
      success: false,
      error: 'Failed to break down step',
    };
  }
}
