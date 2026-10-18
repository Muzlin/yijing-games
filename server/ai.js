'use strict';

const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'qwen2.5:32b';
const AI_TIMEOUT_MS = Number(process.env.AI_TIMEOUT_MS || 90000);

const GAME_RULES = {
  chess: [
    '8x8 国际象棋。王一步任意方向；后横竖斜任意距离；车横竖；象斜线；马走日；兵向前一步、初始可两步、斜吃、到底线升变。',
    '王车易位、吃过路兵有效。被将军时必须应将；将死对方或对方无合法着法获胜。',
    '局面用 FEN 表示。',
  ].join('\n'),
  gomoku: [
    '15x15 五子棋，X=黑方先手，O=白方，.=空。',
    '双方轮流在空点落子，横、竖、斜任意方向先连成 5 子（或更多）者获胜。',
  ].join('\n'),
  go: [
    '围棋，X=黑方先手，O=白方，.=空。',
    '棋子落在交叉点；无气的对方棋子被提掉；不能自杀；不能立即还原上一手造成的局面（打劫）。',
    '可以停一手；双方连续停一手后按中国规则数子，白方贴 6.5 子。',
  ].join('\n'),
  draughts: [
    '8x8 国际跳棋。w=白兵、W=白王、b=黑兵、B=黑王，.=空。白方向上走（y 减小），黑方向下走。',
    '兵每次斜走一格；吃子时跳过相邻敌子落到后面的空格；兵和王的吃子方向都是四条斜线。',
    '有吃子时必须吃；一次可以连续吃多子；兵到达对方底线升为王；王按当前实现每次斜走一格。',
    '无子可动或棋子被吃光判负。',
  ].join('\n'),
  xiangqi: [
    '9x10 中国象棋。红方大写 K=帅 A=仕 B=相 N=马 R=车 C=炮 P=兵；黑方小写。',
    '帅/将只能在九宫内走一步；仕斜一步在九宫；相/象走田字、塞象眼、不过河；马走日、蹩马腿；车直线任意距离；',
    '炮平移/直行不吃子，吃子必须隔一个炮架；兵/卒向前一步，过河后可横走；将帅不能照面（飞将）。',
    '被将军时必须应将；将死或困毙（无合法着法）判负。',
  ].join('\n'),
  jungle: [
    '7x9 斗兽棋。红方在下（y=8 一侧），蓝方在上（y=0 一侧）。',
    '每次走一格上下左右；鼠可以进河，其他动物不能进河；狮、虎可以跳过河，但路径中有鼠则不能跳。',
    '等级：鼠1<猫2<狗3<狼4<豹5<虎6<狮7<象8；同级可互吃；鼠可吃象，象不能吃鼠。',
    '兽穴周围的陷阱会让进入的敌方棋子失去防御；不能进入自己的兽穴；进入对方兽穴、吃光对方或对方无子可动获胜。',
    '棋局没有和棋。',
  ].join('\n'),
  junqi: [
    '5x10 军棋（明棋简化版）。红方在下（y=9 一侧），蓝方在上（y=0 一侧）。',
    '每次上下左右走一格；等级：工兵4<排长5<连长6<营长7<团长8<旅长9<师长10<军长11<司令12，大吃小、同级互吃。',
    '炸弹3与任何棋子相遇同归于尽；地雷2不能移动，只有工兵4可以吃；军旗1不能移动，被吃即输。',
    '营（安全格）中的棋子不能被吃；吃光对方军旗、对方无子可动或吃光对方判胜。',
  ].join('\n'),
  snakes: '蛇棋没有策略，只能掷骰子，因此不使用大模型。',
  reversi: [
    '8x8 黑白棋（奥赛罗），X=黑方先手，O=白方，.=空。',
    '在空格落子，必须沿横、竖、斜某个方向夹住至少一个对方棋子，落子后把被夹住的棋子全部翻成己方颜色。',
    '没有合法着法的一方自动跳过；双方都没有合法着法时数子，子多者胜。',
  ].join('\n'),
  connect4: [
    '7x6 四子棋，R=红方先手，Y=黄方，.=空。',
    '每回合选一列，棋子落到该列最下面的空位；横、竖、斜先连成 4 子者胜。',
  ].join('\n'),
  connect6: [
    '19x19 六子棋，X=黑方先手，O=白方，.=空。',
    '黑方第一手只下 1 子；之后每方每回合下 2 子（可以下在任意两个空点）。',
    '横、竖、斜先连成 6 子（或更多）者胜。',
  ].join('\n'),
  nineMensMorris: [
    '九子棋，双方各 9 子，先在 24 个点上布子，再走子。',
    '三子连成一线（横或竖）可吃掉对方一子；不能吃已成三连的棋子，除非对方所有棋子都在三连中。',
    '棋子少于 3 或无法移动者负；只剩 3 子时可以飞到任意空点。',
  ].join('\n'),
  amazons: [
    '10x10 亚马逊棋，X=黑方皇后，O=白方皇后，*=箭，.=空。',
    '每回合移动一个己方皇后（横竖斜任意距离），然后从新位置射出一箭；皇后和箭都不能越过棋子。',
    '皇后无路可走者负。',
  ].join('\n'),
  tiger: [
    '5x5 老虎棋，T=老虎（先手），D=犬，.=空。老虎每次走一格，或跳过相邻的一只犬落到后面的空格并吃掉它。',
    '老虎吃掉 4 只犬获胜；犬把老虎围住（老虎无合法着法）获胜。没有和棋。',
  ].join('\n'),
  chineseCheckers: [
    '中国跳棋，X=红方在顶部营区，O=蓝方在底部营区，.=空，红方先手。',
    '每回合移动一个己方棋子：走一格到相邻空位，或连续跳过相邻棋子落到后面的空位；可以连跳和转向，不能一次走加跳。',
    '十子全部进入对方营区者胜。',
  ].join('\n'),
  flyingChess: '飞行棋是掷骰子游戏，使用引擎决策，不使用大模型。',
  backgammon: '双陆棋是掷骰子游戏，使用引擎决策，不使用大模型。',
  shogi: [
    '9x9 将棋，黑方先手。棋子：歩、香、桂、銀、金、角、飛、玉；升变后为 と、杏、圭、全、馬、龍。',
    '进入敌阵（黑方为 0-2 行，白方为 6-8 行）可升变；被吃棋子进入持驹，可落子。',
    '王被将死或无合法着法者负；不能把王留在被将军的状态。',
  ].join('\n'),
  tycoon: '地产大亨是掷骰子棋盘游戏，使用引擎决策，不使用大模型。',
  doudizhu: '斗地主（二人简化版）使用引擎决策，不使用大模型。',
  mahjong: '麻将（二人简化版）使用引擎决策，不使用大模型。',
};

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
    '规则：',
    GAME_RULES[game] || '',
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
    reversi: '黑白棋',
    connect4: '四子棋',
    connect6: '六子棋',
    nineMensMorris: '九子棋',
    amazons: '亚马逊棋',
    tiger: '老虎棋',
    chineseCheckers: '中国跳棋',
    flyingChess: '飞行棋',
    backgammon: '双陆棋',
    shogi: '将棋',
    tycoon: '地产大亨',
    doudizhu: '斗地主',
    mahjong: '麻将',
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
