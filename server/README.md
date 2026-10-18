# 弈境联机服务

一个零依赖业务框架的 Node.js 服务，包含：

- **联机匹配**：按棋种排队、随机分配先后手、WebSocket 转发走子。
- **机器人兜底**：等待 7 秒没有真人时，自动匹配一位“在线对手”，客户端用本地 AI 代打（可配置等待时间或关闭）。
- **本地大模型 AI**：把 Ollama 包装成 `/ai/move`，只允许模型从规则引擎给出的合法着法中选择，非法输出自动回退。
- **账号系统**：手机号 + 密码注册/登录、PBKDF2 密码哈希、HMAC-SHA256 登录令牌、昵称、ELO 与胜负和。

账号设计与小李播放器一致：`u`/`p` 登录、`pbkdf2$salt$hash`、`base64(payload).hmac` 令牌、默认 30 天有效期。

## 快速开始

```bash
cd server
npm install
node index.js
```

默认监听 `:8787`。

```bash
curl http://127.0.0.1:8787/health
curl http://127.0.0.1:8787/ai/health
```

### 使用本机 Ollama

服务默认调用 `http://127.0.0.1:11434`，模型 `qwen2.5:32b`（首次加载约 10–20 秒，之后常驻 10 分钟）：

```bash
ollama list
OLLAMA_MODEL=qwen2.5:32b node index.js
```

如需 32B：

```bash
OLLAMA_MODEL=qwen2.5:1.5b AI_TIMEOUT_MS=20000 node index.js
```

### 环境变量

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `PORT` | `8787` | HTTP / WebSocket 端口 |
| `BOT_WAIT_MS` | `7000` | 匹配不到真人后多久安排机器人对手 |
| `MAX_ROOMS` | `5000` | 最大房间数 |
| `ACCOUNT_SECRET` | 自动生成并保存 | 令牌 HMAC 密钥，生产环境务必固定 |
| `ACCOUNT_TOKEN_TTL` | `2592000` | 登录有效期（秒），默认 30 天 |
| `QUICK_LOGIN` | `false` | 是否允许只凭手机号快捷登录/建号 |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | Ollama 地址 |
| `OLLAMA_MODEL` | `qwen2.5:32b` | 默认模型 |
| `AI_TIMEOUT_MS` | `90000` | 单次模型调用超时 |
| `LOG_LEVEL` | - | 设为 `quiet` 关闭日志 |

### 数据

运行时写入 `server/data/`：

- `accounts.json`：账号、密码哈希、昵称、ELO、胜负和。
- `account_secret`：自动生成的令牌密钥。

部署时请挂载持久化卷，并备份该目录。`data/` 已在 `.gitignore` 中。

## API

### 账号

```http
POST /acc-register   {"u":"13800138000","p":"password","nick":"清风棋客"}
POST /acc-login      {"u":"13800138000","p":"password"}
POST /acc-token      {"tk":"<token>"}
POST /acc-set-nick   {"tk":"<token>","nick":"新名字"}
POST /acc-quick-login {"u":"13800138000"}    # 需 QUICK_LOGIN=true
GET  /acc-token?tk=<token>
```

成功响应：

```json
{
  "ok": true,
  "token": "...",
  "uid": "u...",
  "u": "13800138000",
  "phone": "13800138000",
  "nick": "清风棋客",
  "rating": 1200,
  "wins": 0,
  "losses": 0,
  "draws": 0,
  "created": 1234567890
}
```

### 联机

连接：

```
ws://host:8787/ws?game=chess&name=棋友&token=<token>
```

`token` 有效时，服务端以账号昵称和账号 ELO 为准；游客可以只用 `name`。

消息：

```json
{"type":"queue","game":"chess","allowBot":true}
{"type":"move","payload":{"move":1234}}
{"type":"result","winner":0}
{"type":"resign"}
{"type":"leave"}
```

服务端下发：

```json
{"type":"queued","game":"chess","waitMs":7000}
{"type":"matched","roomId":"...","game":"chess","color":0,
 "bot":false,"opponent":{"name":"棋友","rating":1200}}
{"type":"matched","roomId":"bot-...","bot":true,"botLevel":1,
 "opponent":{"name":"夜航船","rating":1100}}
{"type":"move","payload":{"move":1234}}
{"type":"ratingUpdate","rating":1212,"delta":12}
{"type":"opponentLeft"}
```

`winner` 为 `0`/`1`/`2`（和棋），用于更新双方 ELO。

### 本地模型 AI

```http
POST /ai/move
{
  "game": "chess",
  "state": "FEN: ...",
  "player": 0,
  "level": 2,
  "legalMoves": [
    {"id": "e2e4", "label": "e4"},
    {"id": "d2d4", "label": "d4"}
  ]
}
```

响应：

```json
{"move": {"id": "e2e4", "label": "e4"}, "source": "llm", "latencyMs": 304}
```

模型只能从 `legalMoves` 中选一个；输出不合法时返回 `move: null`，客户端使用内置引擎兜底。

## 公网部署

1. 准备一台有公网 IP 的服务器（或 Render / Railway / Fly.io 等）。
2. 使用 Docker：

```bash
docker build -t yijing-server .
docker run -d --name yijing \
  -p 8787:8787 \
  -v $PWD/data:/app/data \
  -e ACCOUNT_SECRET='至少32位的随机字符串' \
  -e OLLAMA_URL='http://host.docker.internal:11434' \
  yijing-server
```

3. 用 Caddy / Nginx 反向代理并启用 TLS。Caddy 示例：

```
game.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

自动获得：

- `https://game.example.com/acc-*`
- `https://game.example.com/ai/*`
- `wss://game.example.com/ws`

4. 构建客户端时指定：

```bash
flutter build apk --release \
  --dart-define=ONLINE_SERVER_URL=wss://game.example.com/ws \
  --dart-define=ACCOUNT_SERVER_URL=https://game.example.com \
  --dart-define=AI_BRIDGE_URL=https://game.example.com \
  --dart-define=AI_MODEL=qwen2.5:32b
```

其他设备安装这个 APK 后即可使用公网账号与匹配。“别的设备的 AI”只需要能访问同一个 `AI_BRIDGE_URL`，模型仍然运行在你的 Ollama 主机上；把服务端代码推到 Git 后在服务器上部署即可。

## 安全说明

- 密码使用 PBKDF2-SHA256（12 万次迭代）加盐存储，不保存明文。
- 登录令牌使用 HMAC-SHA256 签名，默认 30 天过期。
- 登录/注册有基础频率限制；消息大小和发送频率有限制。
- 生产环境务必使用 HTTPS/WSS，并固定 `ACCOUNT_SECRET`。
- 联机走子由客户端规则校验，服务器只做转发；如需强反作弊，应在服务端实现各棋种规则。
- 机器人兜底会把 AI 显示为“在线对手”。上架应用商店前建议按平台要求提供明确标识或说明。
