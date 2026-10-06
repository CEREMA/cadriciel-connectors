// Connecteur OpenAI : un appel à l'API « chat completions », sans dépendance.
import { mkdir, writeFile } from 'node:fs/promises';

const env = process.env;
const fail = (message: string, code = 1): never => {
  console.error(message);
  process.exit(code);
};

const apiKey = env.OPENAI_API_KEY || fail("Clé d'API manquante : choisissez un identifiant OpenAI", 2);
const baseUrl = (env.OPENAI_BASE_URL || 'https://api.openai.com/v1').replace(/\/+$/, '');
const model = env.CAD_MODEL || fail('Modèle manquant', 2);
const prompt = env.CAD_PROMPT || fail('Message manquant', 2);
const out = env.CAD_OUTPUT_DIR || '/data/output';

const numberOf = (value: string | undefined, name: string): number | undefined => {
  if (value === undefined || value === '') return undefined;
  const n = Number(value);
  return Number.isFinite(n) ? n : fail(`« ${name} » doit être un nombre`, 2);
};

const body: Record<string, unknown> = {
  model,
  messages: [
    ...(env.CAD_SYSTEM ? [{ role: 'system', content: env.CAD_SYSTEM }] : []),
    { role: 'user', content: prompt },
  ],
};
const temperature = numberOf(env.CAD_TEMPERATURE, 'Température');
const maxTokens = numberOf(env.CAD_MAX_TOKENS, 'Longueur maximale');
if (temperature !== undefined) body.temperature = temperature;
if (maxTokens !== undefined) body.max_tokens = maxTokens;
if (env.CAD_JSON === 'true') body.response_format = { type: 'json_object' };

let response: Response;
try {
  response = await fetch(`${baseUrl}/chat/completions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(150_000),
  });
} catch (err: any) {
  fail(`Service injoignable : ${err?.message || err}`);
}

const payload: any = await response!.json().catch(() => null);
if (!response!.ok) fail(`Le service a répondu ${response!.status} : ${payload?.error?.message || 'erreur inconnue'}`);

const text = payload?.choices?.[0]?.message?.content;
if (typeof text !== 'string') fail('Réponse inattendue du service : pas de message dans la réponse');

await mkdir(out, { recursive: true });
await writeFile(`${out}/text`, text);
await writeFile(`${out}/usage.json`, JSON.stringify(payload?.usage ?? {}));
