'use strict';

const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const { handleAiRequest, handleAiHealth, warmUp } = require('./ai');
const {
  handleAuthRequest,
  accountByToken,
  accountByUid,
  applyMatchResult,
} = require('./accounts');

const PORT = Number(process.env.PORT || 8787);
const BOT_WAIT_MS = Number(process.env.BOT_WAIT_MS || 7000);
const MAX_ROOMS = Number(process.env.MAX_ROOMS || 5000);
const ALLOWED_GAMES = new Set([
  'chess',
  'xiangqi',
  'junqi',
  'jungle',
  'draughts',
  'snakes',
  'go',
  'gomoku',
]);

const BOT_NAMES = [
  '清风棋客',
  '夜航船',
  '长安小卒',
  '听雨观棋',
  '松下手谈',
  '云间一局',
  '竹影半子',
  '江畔少年',
  '孤舟棋友',
  '明月棋社',
  '半山棋客',
  '不悔棋',
  '观棋不语',
  '一步三算',
  '小林同学',
  '老张下棋',
  'Alex棋友',
  '周末棋局',
  '北窗棋客',
  '落子无悔',
];
const BOT_RATINGS = [900, 1100, 1300, 1500, 1750];

const queues = new Map(); // game -> [entry]
const rooms = new Map(); // roomId -> room
const clients = new Map(); // ws -> {game,name,roomId,msgWindow}

const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  if (await handleAuthRequest(req, res, parsedUrl.pathname, parsedUrl.searchParams)) {
    return;
  }
  if (req.url === '/ai/move') {
    handleAiRequest(req, res);
    return;
  }
  if (req.url === '/ai/health') {
    handleAiHealth(req, res);
    return;
  }
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(
      JSON.stringify({
        ok: true,
        rooms: rooms.size,
        queues: [...queues.entries()].map(([game, list]) => [game, list.length]),
        uptime: Math.round(process.uptime()),
      }),
    );
    return;
  }
  res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
  res.end('Yijing online server is running.\n');
});

const wss = new WebSocketServer({
  server,
  path: '/ws',
  maxPayload: 64 * 1024,
  perMessageDeflate: false,
});

wss.on('connection', (ws, req) => {
  const url = new URL(req.url || '/ws', `http://${req.headers.host}`);
  const game = sanitizeGame(url.searchParams.get('game'));
  const account = accountByToken(url.searchParams.get('token') || '');
  const name = account
    ? sanitizeName(account.nick || account.u)
    : sanitizeName(url.searchParams.get('name'));
  ws.isAlive = true;
  ws.meta = {
    game,
    name,
    roomId: null,
    messageTimes: [],
    account: account
      ? { uid: account.uid, nick: account.nick, rating: Number(account.rating || 1200) }
      : null,
  };
  clients.set(ws, ws.meta);
  log(`connect ${name} (${game})`);

  ws.on('pong', () => {
    ws.isAlive = true;
  });

  ws.on('message', (raw) => {
    if (!allowMessage(ws)) return;
    let message;
    try {
      message = JSON.parse(raw.toString());
    } catch {
      return;
    }
    if (!message || typeof message.type !== 'string') return;
    switch (message.type) {
      case 'queue':
        enqueue(ws, message);
        break;
      case 'cancel':
        removeFromQueue(ws);
        send(ws, { type: 'cancelled' });
        break;
      case 'move':
        relayMove(ws, message);
        break;
      case 'resign':
        resign(ws);
        break;
      case 'result':
        reportResult(ws, message);
        break;
      case 'leave':
        leave(ws);
        break;
      case 'ping':
        send(ws, { type: 'pong' });
        break;
      default:
        break;
    }
  });

  ws.on('close', () => cleanup(ws));
  ws.on('error', () => cleanup(ws));

  send(ws, { type: 'hello', server: 'yijing-online', botWaitMs: BOT_WAIT_MS });
});

function sanitizeGame(value) {
  if (typeof value === 'string' && ALLOWED_GAMES.has(value)) return value;
  return 'chess';
}

function sanitizeName(value) {
  if (typeof value !== 'string') return '棋友';
  const cleaned = value.trim().replace(/[\u0000-\u001f<>]/g, '').slice(0, 16);
  return cleaned || '棋友';
}

function send(ws, payload) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}

function allowMessage(ws) {
  const now = Date.now();
  const entry = ws.meta;
  entry.messageTimes = entry.messageTimes.filter((t) => now - t < 2000);
  if (entry.messageTimes.length > 40) {
    log('rate limit, closing socket');
    ws.close();
    return false;
  }
  entry.messageTimes.push(now);
  return true;
}

function enqueue(ws, message) {
  const meta = ws.meta;
  const game = sanitizeGame(message.game || meta.game);
  meta.game = game;
  meta.name = meta.account
    ? sanitizeName(meta.account.nick || meta.name)
    : sanitizeName(message.name || meta.name);
  if (meta.roomId) leave(ws);

  const waiting = queues.get(game) || [];
  const index = waiting.findIndex(
    (entry) => entry.ws !== ws && entry.ws.readyState === entry.ws.OPEN,
  );
  if (index >= 0) {
    const opponent = waiting.splice(index, 1)[0];
    clearTimeout(opponent.timer);
    queues.set(game, waiting);
    createRoom(game, opponent, { ws, name: meta.name });
    return;
  }

  const entry = {
    ws,
    name: meta.name,
    game,
    joinedAt: Date.now(),
    timer: null,
  };
  entry.timer = setTimeout(() => {
    removeEntry(entry);
    if (ws.readyState !== ws.OPEN) return;
    if (message.allowBot === false) {
      send(ws, { type: 'noMatch' });
      return;
    }
    sendBotMatch(ws, game);
  }, BOT_WAIT_MS);
  waiting.push(entry);
  queues.set(game, waiting);
  send(ws, { type: 'queued', game, waitMs: BOT_WAIT_MS });
  log(`queue ${meta.name} for ${game} (${waiting.length} waiting)`);
}

function createRoom(game, a, b) {
  if (rooms.size >= MAX_ROOMS) {
    send(a.ws, { type: 'error', message: '服务器繁忙，请稍后再试' });
    send(b.ws, { type: 'error', message: '服务器繁忙，请稍后再试' });
    return;
  }
  const roomId = crypto.randomUUID();
  const firstColor = Math.random() < 0.5 ? 0 : 1;
  const players = [
    {
      ws: a.ws,
      name: a.name,
      color: firstColor,
      uid: a.ws.meta.account?.uid || null,
      rating: a.ws.meta.account?.rating || 1200,
    },
    {
      ws: b.ws,
      name: b.name,
      color: 1 - firstColor,
      uid: b.ws.meta.account?.uid || null,
      rating: b.ws.meta.account?.rating || 1200,
    },
  ];
  const room = {
    id: roomId,
    game,
    players,
    createdAt: Date.now(),
  };
  rooms.set(roomId, room);
  players.forEach((player) => {
    player.ws.meta.roomId = roomId;
  });
  players.forEach((player, index) => {
    const opponent = players[1 - index];
    send(player.ws, {
      type: 'matched',
      roomId,
      game,
      color: player.color,
      bot: false,
      opponent: {
        name: opponent.name,
        rating: opponent.rating || 1200,
      },
    });
  });
  log(`room ${roomId} ${game}: ${a.name} vs ${b.name}`);
}

function sendBotMatch(ws, game) {
  const level = Math.floor(Math.random() * 4);
  const opponent = BOT_NAMES[Math.floor(Math.random() * BOT_NAMES.length)];
  send(ws, {
    type: 'matched',
    roomId: `bot-${crypto.randomUUID()}`,
    game,
    color: Math.random() < 0.5 ? 0 : 1,
    bot: true,
    botLevel: level,
    opponent: {
      name: opponent,
      rating: BOT_RATINGS[level],
    },
  });
  log(`bot match for ${ws.meta.name}: ${opponent} level ${level}`);
}

function reportResult(ws, message) {
  const roomId = ws.meta.roomId;
  if (!roomId) return;
  const room = rooms.get(roomId);
  if (!room) return;
  const winner = Number(message.winner);
  if (![0, 1, 2].includes(winner)) return;
  const color0 = room.players.find((p) => p.color === 0);
  const color1 = room.players.find((p) => p.color === 1);
  if (!color0 || !color1) return;
  const updates = applyMatchResult(color0.uid, color1.uid, winner);
  rooms.delete(roomId);
  color0.ws.meta.roomId = null;
  color1.ws.meta.roomId = null;
  if (updates) {
    send(color0.ws, {
      type: 'ratingUpdate',
      rating: updates.a.rating,
      delta: updates.a.rating - (color0.rating || 1200),
    });
    send(color1.ws, {
      type: 'ratingUpdate',
      rating: updates.b.rating,
      delta: updates.b.rating - (color1.rating || 1200),
    });
  }
}

function relayMove(ws, message) {
  const roomId = ws.meta.roomId;
  if (!roomId) return;
  const room = rooms.get(roomId);
  if (!room) return;
  const opponent = room.players.find((p) => p.ws !== ws);
  if (!opponent || opponent.ws.readyState !== opponent.ws.OPEN) return;
  send(opponent.ws, {
    type: 'move',
    payload: message.payload,
  });
}

function resign(ws) {
  finishRoom(ws, 'opponentResigned');
}

function leave(ws) {
  removeFromQueue(ws);
  finishRoom(ws, 'opponentLeft');
}

function finishRoom(ws, notifyType) {
  const roomId = ws.meta.roomId;
  if (!roomId) return;
  ws.meta.roomId = null;
  const room = rooms.get(roomId);
  if (!room) return;
  rooms.delete(roomId);

  const leaver = room.players.find((p) => p.ws === ws);
  const opponent = room.players.find((p) => p.ws !== ws);
  if (opponent) {
    opponent.ws.meta.roomId = null;
    send(opponent.ws, { type: notifyType });
    if (leaver && opponent.uid && leaver.uid) {
      const color0 = room.players.find((p) => p.color === 0);
      const color1 = room.players.find((p) => p.color === 1);
      const updates = applyMatchResult(
        color0?.uid,
        color1?.uid,
        opponent.color,
      );
      if (updates) {
        const entry = opponent.color === 0 ? updates.a : updates.b;
        const oldRating = opponent.rating || 1200;
        send(opponent.ws, {
          type: 'ratingUpdate',
          rating: entry.rating,
          delta: entry.rating - oldRating,
        });
      }
    }
  }
  send(ws, { type: 'left' });
}

function removeEntry(entry) {
  const list = queues.get(entry.game);
  if (!list) return;
  const index = list.indexOf(entry);
  if (index >= 0) list.splice(index, 1);
  if (list.length === 0) queues.delete(entry.game);
  clearTimeout(entry.timer);
}

function removeFromQueue(ws) {
  for (const [game, list] of queues.entries()) {
    const index = list.findIndex((entry) => entry.ws === ws);
    if (index >= 0) {
      clearTimeout(list[index].timer);
      list.splice(index, 1);
    }
    if (list.length === 0) queues.delete(game);
  }
}

function cleanup(ws) {
  removeFromQueue(ws);
  leave(ws);
  clients.delete(ws);
}

const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) {
      ws.terminate();
      continue;
    }
    ws.isAlive = false;
    try {
      ws.ping();
    } catch {
      // Ignore.
    }
  }
}, 30000);

wss.on('close', () => clearInterval(heartbeat));

function log(...args) {
  if (process.env.LOG_LEVEL === 'quiet') return;
  console.log(new Date().toISOString(), ...args);
}

server.listen(PORT, () => {
  console.log(`Yijing online server listening on :${PORT}`);
  console.log(`Bot fallback after ${BOT_WAIT_MS} ms`);
  // Load the 32B model in the background so the first AI move is not delayed
  // by a cold 10-20 second model load.
  warmUp();
});
