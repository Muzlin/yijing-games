# 弈境 · 棋牌合集

用 Flutter 编写的多棋种棋牌 App：**国际象棋、中国象棋、军棋、斗兽棋、国际跳棋、蛇棋、围棋、五子棋**。

内置棋规引擎与 AI，支持人机、双人、AI 对战观战、公网联机、账号系统、AI 托管与本地 Ollama 大模型。

## 棋种

| 棋种 | 规则要点 | AI / 联机 / 托管 |
| --- | --- | --- |
| 国际象棋 | 完整规则：易位、吃过路兵、升变、将死、三次重复 | ✓ |
| 中国象棋 | 九宫、楚河汉界、蹩马腿、塞象眼、炮架、飞将 | ✓ |
| 军棋 | 5×10 明棋简化版：司令/军长/师长…、地雷、炸弹、军旗、大本营 | ✓ |
| 斗兽棋 | 7×9、河流、兽穴、陷阱、鼠克象、狮虎跳河 | ✓ |
| 国际跳棋 | 8×8、强制连吃、升王、无子可动判负 | ✓ |
| 蛇棋 | 10×10、掷骰子、蛇与梯子、精确到达 100 | ✓（掷骰子） |
| 围棋 | 9 路 / 13 路、提子、禁自杀、打劫、停一手、数子 | ✓ |
| 五子棋 | 15×15、五子连珠 | ✓ |

> 军棋目前是“明棋简化版”（双方可见、无铁路线），保留司令—工兵等级、炸弹同归于尽、地雷、军旗与大本营。隐藏兵力的四国军棋暂未实现。

## 功能

- **人机对战**：4 档 AI 棋力（入门 / 业余 / 高手 / 大师），可选先后手。
- **双人对弈**：同屏轮流落子。
- **AI 对战**：两名 AI 自动对弈，可暂停/继续，也可以点“接管”亲手替 AI 走一步。
- **联机对战**：公网 WebSocket 匹配在线玩家，随机分配先后手；匹配不到真人时由服务端安排一位“在线对手”应战。
- **账号系统**：手机号 + 密码注册/登录、PBKDF2 密码哈希、HMAC-SHA256 令牌（30 天）、昵称、ELO、胜负和。
- **AI 托管 / 辅助**：AI 代下、托管自动落子；联机中也可使用提示与托管。托管固定使用最高难度的引擎。
- **本地大模型 AI**：国际象棋可使用本机 Ollama（默认 `qwen2.5:32b`），模型只能从规则引擎给出的合法着法中选择，非法输出自动回退；AI 托管使用内置大师引擎。
- **完整对局体验**：合法落点、上一步高亮、将军提示、悔棋、认输/停一手、翻盘、结果统计、音效与震动。
- **自动存档**：国际象棋本地对局自动保存，可从棋牌合集继续。
- **适配**：手机竖屏与平板/桌面宽屏，支持 iOS、Android、macOS、Web。

## 运行

```bash
flutter pub get
flutter run
```

服务端（账号、联机、本地模型桥）：

```bash
cd server
npm install
node index.js
```

默认端口 `8787`：

- WebSocket：`ws://127.0.0.1:8787/ws`
- 账号 API：`http://127.0.0.1:8787/acc-*`
- 本地模型：`http://127.0.0.1:8787/ai/move` → 本机 Ollama

构建时指定服务器地址：

```bash
flutter build apk --release \
  --dart-define=ONLINE_SERVER_URL=wss://game.example.com/ws \
  --dart-define=ACCOUNT_SERVER_URL=https://game.example.com \
  --dart-define=AI_BRIDGE_URL=https://game.example.com \
  --dart-define=AI_MODEL=qwen2.5:32b
```

局域网测试可换成 Mac 的局域网 IP。公网部署、HTTPS/WSS、Docker、数据持久化与安全说明见 [`server/README.md`](server/README.md)。

## 测试

```bash
flutter test
```

联机 / 账号 / 状态同步联调（需先启动服务端）：

```bash
YIJING_ONLINE_TEST=1 flutter test test/online_integration_test.dart
```

覆盖：

- 国际象棋 Perft（起始局面、Kiwipete、升变/易位等 6 组标准局面）
- 8 种棋的走子、吃子、胜负、悔棋、AI 合法性
- 围棋提子/自杀/数子，跳棋强制连吃与升王，斗兽棋鼠克象/跳河，军棋炸弹/军旗
- 联机匹配、账号注册登录令牌、Gomoku 状态同步
- 手机/宽屏布局、八个棋种进入对局、AI 托管/接管

## 目录

```
lib/
  main.dart                    应用入口、中文本地化
  core/chess.dart              国际象棋规则
  core/chess_ai.dart           国际象棋引擎
  game/                        国际象棋对局控制器/存档
  account/                     账号登录、个人中心、令牌
  online/                      匹配、WebSocket 会话、昵称
  ai/ai_bridge.dart            Ollama 合法着法桥
  games/core/                  棋种元数据、TurnGame 接口、注册表
  games/impl/                  七种新棋的规则 + AI + 棋盘
  games/ui/                    棋牌合集、设置面板、通用对局页
  ui/                          国际象棋页面、主题、音效
server/                        匹配/账号/本地模型服务
```

## 致谢

国际象棋棋子矢量图形基于 Wikimedia Commons 的 **Cburnett** 棋子（CC BY-SA 3.0），经 `chess_vectors_flutter` 矢量路径适配。

- https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces
