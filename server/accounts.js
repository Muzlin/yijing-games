'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const DATA_DIR = path.join(__dirname, 'data');
const ACCOUNTS_FILE = path.join(DATA_DIR, 'accounts.json');
const SECRET_FILE = path.join(DATA_DIR, 'account_secret');
const TOKEN_TTL = Number(process.env.ACCOUNT_TOKEN_TTL || 30 * 86400);
const PHONE_RE = /^[0-9]{6,20}$/;
const NICK_RE = /^[\u4e00-\u9fffA-Za-z0-9_\- ]{2,12}$/;
const QUICK_LOGIN = process.env.QUICK_LOGIN === 'true';

fs.mkdirSync(DATA_DIR, { recursive: true });

function secret() {
  if (process.env.ACCOUNT_SECRET && process.env.ACCOUNT_SECRET.length >= 32) {
    return process.env.ACCOUNT_SECRET;
  }
  try {
    return fs.readFileSync(SECRET_FILE, 'utf8').trim();
  } catch {
    const value = crypto.randomBytes(32).toString('hex');
    fs.writeFileSync(SECRET_FILE, value, { mode: 0o600 });
    return value;
  }
}

function loadAccounts() {
  try {
    const data = JSON.parse(fs.readFileSync(ACCOUNTS_FILE, 'utf8'));
    return data && typeof data === 'object' ? data : {};
  } catch {
    return {};
  }
}

function saveAccounts(accounts) {
  const tmp = `${ACCOUNTS_FILE}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(accounts, null, 2));
  fs.renameSync(tmp, ACCOUNTS_FILE);
}

function hashPassword(password) {
  const salt = crypto.randomBytes(8).toString('hex');
  const hash = crypto
    .pbkdf2Sync(String(password), salt, 120000, 32, 'sha256')
    .toString('hex');
  return `pbkdf2$${salt}$${hash}`;
}

function verifyPassword(password, stored) {
  try {
    const [algo, salt, hash] = String(stored).split('$');
    if (algo !== 'pbkdf2' || !salt || !hash) return false;
    const want = crypto
      .pbkdf2Sync(String(password), salt, 120000, 32, 'sha256')
      .toString('hex');
    return crypto.timingSafeEqual(Buffer.from(hash, 'hex'), Buffer.from(want, 'hex'));
  } catch {
    return false;
  }
}

function signToken(u, uid, ttl = TOKEN_TTL) {
  const exp = Math.floor(Date.now() / 1000) + Number(ttl);
  const payload = `${u}|${uid}|${exp}`;
  const sig = crypto
    .createHmac('sha256', secret())
    .update(payload)
    .digest('hex');
  const body = Buffer.from(payload, 'utf8').toString('base64url');
  return `${body}.${sig}`;
}

function verifyToken(token) {
  try {
    const [body, sig] = String(token || '').split('.');
    if (!body || !sig) return null;
    const payload = Buffer.from(body, 'base64url').toString('utf8');
    const [u, uid, exp] = payload.split('|');
    if (!u || !uid || !exp) return null;
    const want = crypto
      .createHmac('sha256', secret())
      .update(payload)
      .digest('hex');
    if (sig.length !== want.length) return null;
    if (!crypto.timingSafeEqual(Buffer.from(sig, 'hex'), Buffer.from(want, 'hex'))) {
      return null;
    }
    if (Number(exp) < Math.floor(Date.now() / 1000)) return null;
    return { u, uid, exp: Number(exp) };
  } catch {
    return null;
  }
}

function accountByToken(token) {
  const info = verifyToken(token);
  if (!info) return null;
  const accounts = loadAccounts();
  const account =
    accounts[info.u.toLowerCase()] ||
    Object.values(accounts).find((a) => a.uid === info.uid);
  if (!account || account.uid !== info.uid) return null;
  return account;
}

function accountByUid(uid) {
  if (!uid) return null;
  return Object.values(loadAccounts()).find((a) => a.uid === uid) || null;
}

function publicUser(account) {
  return {
    ok: true,
    uid: account.uid,
    u: account.u,
    phone: account.phone || account.u,
    nick: account.nick || '',
    rating: Number(account.rating || 1200),
    wins: Number(account.wins || 0),
    losses: Number(account.losses || 0),
    draws: Number(account.draws || 0),
    created: account.created || 0,
  };
}

function authResponse(account, message = '') {
  return {
    ...publicUser(account),
    token: signToken(account.u, account.uid),
    msg: message,
  };
}

function sanitizeNick(value) {
  return String(value || '')
    .trim()
    .replace(/[\u0000-\u001f<>]/g, '')
    .slice(0, 12);
}

function defaultNick(phone) {
  return `棋友${String(phone).slice(-4)}`;
}

const authBuckets = new Map(); // ip -> [timestamps]

function allowAuth(ip) {
  const now = Date.now();
  const key = String(ip || 'unknown');
  const list = (authBuckets.get(key) || []).filter((t) => now - t < 60000);
  if (list.length >= 20) {
    authBuckets.set(key, list);
    return false;
  }
  list.push(now);
  authBuckets.set(key, list);
  if (authBuckets.size > 5000) {
    for (const [k, v] of authBuckets) {
      if (!v.some((t) => now - t < 60000)) authBuckets.delete(k);
    }
  }
  return true;
}

function corsHeaders() {
  return {
    'access-control-allow-origin': '*',
    'access-control-allow-headers': 'content-type, authorization',
    'access-control-allow-methods': 'GET, POST, OPTIONS',
  };
}

function json(res, status, payload) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    ...corsHeaders(),
  });
  res.end(JSON.stringify(payload));
}

function readJson(req, limit = 32 * 1024) {
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
    req.on('end', () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}'));
      } catch {
        reject(new Error('bad json'));
      }
    });
    req.on('error', reject);
  });
}

function createAccount(accounts, { u, p, nick, uid }) {
  const key = u.toLowerCase();
  if (accounts[key] || Object.values(accounts).some((a) => a.phone === u)) {
    throw new Error('该手机号已注册，请直接登录');
  }
  const cleanNick = sanitizeNick(nick) || defaultNick(u);
  if (cleanNick.length < 2) throw new Error('昵称至少 2 个字符');
  if (!NICK_RE.test(cleanNick)) throw new Error('昵称只能包含中文、字母、数字、空格或下划线');
  if (Object.values(accounts).some((a) => (a.nick || '').toLowerCase() === cleanNick.toLowerCase())) {
    throw new Error('昵称已被使用，换一个吧');
  }
  const finalUid = uid && !Object.values(accounts).some((a) => a.uid === uid)
    ? uid
    : `u${Date.now()}-${crypto.randomBytes(4).toString('hex')}`;
  const account = {
    u,
    pw: hashPassword(p),
    uid: finalUid,
    phone: u,
    nick: cleanNick,
    rating: 1200,
    wins: 0,
    losses: 0,
    draws: 0,
    created: Math.floor(Date.now() / 1000),
    last_login: Math.floor(Date.now() / 1000),
  };
  accounts[key] = account;
  return account;
}

async function handleAuthRequest(req, res, pathname, query) {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
    res.end();
    return true;
  }

  if (pathname === '/acc/health' || pathname === '/acc-health') {
    json(res, 200, { ok: true, service: 'yijing-accounts', quickLogin: QUICK_LOGIN });
    return true;
  }

  if (pathname === '/acc-token' && req.method === 'GET') {
    const token = query.get('tk') || '';
    const account = accountByToken(token);
    if (!account) return json(res, 401, { ok: false, error: '登录已过期，请重新登录' }), true;
    json(res, 200, authResponse(account));
    return true;
  }

  if (!['/acc-register', '/acc-login', '/acc-token', '/acc-set-nick',
        '/acc-quick-login'].includes(pathname)) {
    return false;
  }

  if (req.method !== 'POST') {
    json(res, 405, { ok: false, error: 'method not allowed' });
    return true;
  }

  const ip = req.socket.remoteAddress || '';
  if ((pathname === '/acc-register' || pathname === '/acc-login') && !allowAuth(ip)) {
    json(res, 429, { ok: false, error: '操作太频繁，请稍后再试' });
    return true;
  }

  let body;
  try {
    body = await readJson(req);
  } catch {
    json(res, 400, { ok: false, error: '请求格式错误' });
    return true;
  }

  try {
    if (pathname === '/acc-register') {
      const u = String(body.u || body.phone || '').trim();
      const p = String(body.p || body.password || '');
      if (!PHONE_RE.test(u)) {
        return json(res, 400, { ok: false, error: '请输入 6-20 位手机号' }), true;
      }
      if (p.length < 6 || p.length > 64) {
        return json(res, 400, { ok: false, error: '密码需 6-64 位' }), true;
      }
      const accounts = loadAccounts();
      const account = createAccount(accounts, {
        u,
        p,
        nick: body.nick,
        uid: String(body.uid || ''),
      });
      saveAccounts(accounts);
      json(res, 200, authResponse(account, '注册成功'));
      return true;
    }

    if (pathname === '/acc-login') {
      const u = String(body.u || body.phone || '').trim();
      const p = String(body.p || body.password || '');
      const accounts = loadAccounts();
      const account =
        accounts[u.toLowerCase()] ||
        Object.values(accounts).find((a) => a.phone === u);
      if (!account || !verifyPassword(p, account.pw)) {
        return json(res, 401, { ok: false, error: '手机号或密码错误' }), true;
      }
      if (!account.nick || account.nick.length < 2) {
        account.nick = defaultNick(account.phone || account.u);
      }
      account.last_login = Math.floor(Date.now() / 1000);
      saveAccounts(accounts);
      json(res, 200, authResponse(account));
      return true;
    }

    if (pathname === '/acc-token') {
      const account = accountByToken(String(body.tk || body.token || ''));
      if (!account) {
        return json(res, 401, { ok: false, error: '登录已过期，请重新登录' }), true;
      }
      json(res, 200, publicUser(account));
      return true;
    }

    if (pathname === '/acc-set-nick') {
      const account = accountByToken(String(body.tk || body.token || ''));
      if (!account) {
        return json(res, 401, { ok: false, error: '登录已过期，请重新登录' }), true;
      }
      const nick = sanitizeNick(body.nick);
      if (nick.length < 2 || !NICK_RE.test(nick)) {
        return json(res, 400, { ok: false, error: '昵称需为 2-12 个中文、字母或数字' }), true;
      }
      const accounts = loadAccounts();
      if (Object.values(accounts).some(
        (a) => a.uid !== account.uid &&
          (a.nick || '').toLowerCase() === nick.toLowerCase())) {
        return json(res, 409, { ok: false, error: '昵称已被使用，换一个吧' }), true;
      }
      const stored = accounts[account.u.toLowerCase()] ||
        Object.values(accounts).find((a) => a.uid === account.uid);
      stored.nick = nick;
      saveAccounts(accounts);
      json(res, 200, { ...publicUser(stored), token: signToken(stored.u, stored.uid) });
      return true;
    }

    if (pathname === '/acc-quick-login') {
      if (!QUICK_LOGIN) {
        return json(res, 403, { ok: false, error: '快捷登录未开启' }), true;
      }
      const u = String(body.u || body.phone || '').trim();
      if (!PHONE_RE.test(u)) {
        return json(res, 400, { ok: false, error: '请输入手机号' }), true;
      }
      const accounts = loadAccounts();
      let account = accounts[u.toLowerCase()] ||
        Object.values(accounts).find((a) => a.phone === u);
      let created = false;
      if (!account) {
        account = createAccount(accounts, { u, p: crypto.randomBytes(12).toString('hex'), nick: body.nick });
        created = true;
      }
      account.last_login = Math.floor(Date.now() / 1000);
      saveAccounts(accounts);
      json(res, 200, authResponse(account, created ? '注册成功' : ''));
      return true;
    }
  } catch (error) {
    json(res, 400, { ok: false, error: error.message || '操作失败' });
    return true;
  }
  return false;
}

function applyMatchResult(uidA, uidB, winner /* 0,1,2=draw */) {
  if (!uidA || !uidB) return null;
  const accounts = loadAccounts();
  const a = Object.values(accounts).find((x) => x.uid === uidA);
  const b = Object.values(accounts).find((x) => x.uid === uidB);
  if (!a || !b) return null;
  const ra = Number(a.rating || 1200);
  const rb = Number(b.rating || 1200);
  const expectedA = 1 / (1 + Math.pow(10, (rb - ra) / 400));
  const scoreA = winner === 0 ? 1 : winner === 1 ? 0 : 0.5;
  const k = 24;
  const delta = Math.round(k * (scoreA - expectedA));
  a.rating = Math.max(100, ra + delta);
  b.rating = Math.max(100, rb - delta);
  if (winner === 2) {
    a.draws = Number(a.draws || 0) + 1;
    b.draws = Number(b.draws || 0) + 1;
  } else if (winner === 0) {
    a.wins = Number(a.wins || 0) + 1;
    b.losses = Number(b.losses || 0) + 1;
  } else {
    a.losses = Number(a.losses || 0) + 1;
    b.wins = Number(b.wins || 0) + 1;
  }
  saveAccounts(accounts);
  return {
    a: { uid: a.uid, rating: a.rating },
    b: { uid: b.uid, rating: b.rating },
  };
}

module.exports = {
  handleAuthRequest,
  accountByToken,
  accountByUid,
  publicUser,
  applyMatchResult,
  QUICK_LOGIN,
};
