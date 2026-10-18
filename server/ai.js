'use strict';

const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'qwen2.5:32b';
const AI_TIMEOUT_MS = Number(process.env.AI_TIMEOUT_MS || 90000);

function json(res, status, payload) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'content-type',
    'access-control-allow-methods': 'POST, GET, OPTIONS',
  });
  res.end(JSON.stringify(payload));
}

function readBody(req, limit = 512 * 1024) {
  return new Promise((resolve, reject) => {
    let size = 0;
    const chunks = [];
    req.on('data', (chunk) => {
      size += chunk.length;
      if (size > limit) {
        reject(new Error('body too large'));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks).toString('utf8')));
    req.on('error', reject);
  });
}

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[`"'“”‘’。，、：:;；!！?？\s]/g, '')
    .trim();
}

function buildPrompt({ game, state, legalMoves, player, level, retry }) {
  const moves = legalMoves
    .map((move, index) => `${index + 1}. ${move.id} (${move.label || move.id})`)
    .join('\n');
  const style =
    level >= 3
      ? '棋风严谨，优先选择安全且积极的着法。'
      : level >= 2
        ? '棋风均衡，兼顾进攻与防守。'
        : '棋风轻松，可以尝试自然的着法。';
  return [
    `你是「弈境」棋牌应用中的对弈 AI，正在下${gameName(game)}。${style}`,
    '',
    '当前局面：',
    state,
    '',
    `轮到：${player === 1 ? '黑方 / 后手' : '白方 / 先手'}`,
    '合法着法（必须从中选择）：',
    moves,
    '',
    retry
      ? '上一次回复无效。请只回复一个数字编号，不要解释。'
      : '请只回复一个数字编号（例如 3），不要输出其他内容。',
  ].join('\n');
}

function gameName(game) {
  const names = {
    chess: '国际象棋',
    xiangqi: '中国象棋',
    junqi: '军棋',
    jungle: '斗兽棋',
    draughts: '国际跳棋',
    snakes: '蛇棋',
    go: '围棋',
    gomoku: '五子棋',
  };
  return names[game] || '棋类游戏';
}

async function callOllama(prompt, model, temperature) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), AI_TIMEOUT_MS);
  try {
    const response = await fetch(`${OLLAMA_URL}/api/generate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      signal: controller.signal,
      body: JSON.stringify({
        model,
        prompt,
        stream: false,
        keep_alive: '30m',
        options: {
          temperature,
          num_predict: 8,
          top_p: 0.9,
          repeat_penalty: 1.1,
        },
      }),
    });
    if (!response.ok) {
      throw new Error(`ollama ${response.status}`);
    }
    const data = await response.json();
    return String(data.response || '').trim();
  } finally {
    clearTimeout(timer);
  }
}

function matchMove(text, legalMoves) {
  const normalized = normalize(text);
  if (!normalized) return null;
  const number = normalized.match(/^\d{1,2}$/);
  if (number) {
    const index = Number(number[0]) - 1;
    if (index >= 0 && index < legalMoves.length) return legalMoves[index];
  }
  for (const move of legalMoves) {
    const id = normalize(move.id);
    const label = normalize(move.label);
    if (id && normalized === id) return move;
    if (label && normalized === label) return move;
    if (id && normalized.includes(id)) return move;
    if (label && normalized.includes(label)) return move;
  }
  return null;
}

async function pickMove(payload) {
  const legalMoves = Array.isArray(payload.legalMoves)
    ? payload.legalMoves
        .filter((m) => m && typeof m.id === 'string')
        .slice(0, 8)
    : [];
  if (legalMoves.length === 0) return { move: null, source: 'no-legal-moves' };
  if (legalMoves.length === 1) {
    return { move: legalMoves[0], source: 'forced' };
  }

  const model =
    typeof payload.model === 'string' && payload.model.trim()
      ? payload.model.trim()
      : OLLAMA_MODEL;
  const level = Number(payload.level || 1);
  const base = {
    game: payload.game || 'chess',
    state: String(payload.state || '').slice(0, 6000),
    legalMoves,
    player: Number(payload.player || 0),
    level,
  };

  let text = '';
  for (let attempt = 0; attempt < 2; attempt++) {
    const prompt = buildPrompt({ ...base, retry: attempt > 0 });
    text = await callOllama(prompt, model, attempt === 0 ? 0.35 : 0);
    const move = matchMove(text, legalMoves);
    if (move) {
      return { move, source: attempt === 0 ? 'llm' : 'llm-retry', raw: text };
    }
  }
  return { move: null, source: 'invalid-model-output', raw: text };
}

async function handleAiRequest(req, res) {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'access-control-allow-origin': '*',
      'access-control-allow-headers': 'content-type',
      'access-control-allow-methods': 'POST, GET, OPTIONS',
    });
    res.end();
    return;
  }
  if (req.method !== 'POST') {
    json(res, 405, { error: 'method not allowed' });
    return;
  }
  const started = Date.now();
  try {
    const body = JSON.parse(await readBody(req));
    const result = await pickMove(body || {});
    json(res, 200, {
      ...result,
      model: body?.model || OLLAMA_MODEL,
      latencyMs: Date.now() - started,
    });
  } catch (error) {
    json(res, 200, {
      move: null,
      source: 'error',
      error: error.message,
      latencyMs: Date.now() - started,
    });
  }
}

async function handleAiHealth(req, res) {
  warmUp();
  const started = Date.now();
  try {
    const response = await fetch(`${OLLAMA_URL}/api/tags`, {
      signal: AbortSignal.timeout(3000),
    });
    const data = await response.json();
    const models = (data.models || []).map((m) => m.name);
    json(res, 200, {
      ok: true,
      ollama: OLLAMA_URL,
      model: OLLAMA_MODEL,
      models,
      latencyMs: Date.now() - started,
    });
  } catch (error) {
    json(res, 200, {
      ok: false,
      ollama: OLLAMA_URL,
      model: OLLAMA_MODEL,
      error: error.message,
      latencyMs: Date.now() - started,
    });
  }
}

let warmed = false;
async function warmUp() {
  if (warmed) return;
  warmed = true;
  try {
    await fetch(`${OLLAMA_URL}/api/generate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      signal: AbortSignal.timeout(120000),
      body: JSON.stringify({
        model: OLLAMA_MODEL,
        prompt: 'ok',
        stream: false,
        keep_alive: '30m',
        options: { num_predict: 1, temperature: 0 },
      }),
    });
    console.log(`[ai] warmed ${OLLAMA_MODEL}`);
  } catch (error) {
    warmed = false;
    console.log('[ai] warmup failed:', error.message);
  }
}

module.exports = { handleAiRequest, handleAiHealth, warmUp };
