# 开发规范 · CODING STANDARDS

> 写给在本仓库写代码的人 / AI。**只列“必须”和“禁止”，照抄即可。**
> 原理、流程、SOP 见 [`DEVELOPMENT.md`](./DEVELOPMENT.md)。
> 每次提交前，对照本文件最后的「完成的定义」逐条自检。

---

## ⛔ 七条绝不（NEVER DO）

读不完全文也要记住这七条。每一条都对应过一次真实的线上事故。

1. **绝不**只写键盘分支不写触屏分支（目标是手机！）。
2. **绝不**把内容（关卡/敌人摆位/数值）硬编码进逻辑——放进 `data/` 或 `config.lua`。
3. **绝不**让商店文案承诺 build 里不存在的东西（见 `DEVELOPMENT.md` 第 8 节对照表）。
4. **绝不**用 `--[[ ]]` 留大段注释死代码——要么删，要么用开关 `Config.ENABLE_xxx`。
5. **绝不**写裸数字坐标（用 `GY+PH`，不写 `-0.2`）或裸模块状态名（必须带尾下划线）。
6. **绝不**提交没跑过 `luac5.4 -p` 的代码，也绝不提交 `luac.out` / `dist/` / `.build/` 等产物。
7. **绝不**声称手感/物理/AI“已修复”而没经过 **TapTap 真机**验收（云端跑不起来，见铁律四）。

---

## A. 命名

| 对象 | 规则 | 例 |
|---|---|---|
| 模块级可变状态 | 小驼峰 **+ 尾下划线** | `gameState_` `playerNode_` `enemies_` `curRoom_` |
| 文件级常量（取自 Config） | 全大写，**文件顶部统一 `local X = Config.X` 别名** | `MOVE_SPEED` `GY` `MAX_HP`（已有 34 处，照此加） |
| 函数 | PascalCase | `CreatePlayer` `BuildRoom` `PerformAttack` |
| 局部临时变量 | 短小写 | `dt` `pp` `vel` `mx` |
| 关卡文件 | `data/Level_001X.lua`（X 为大写字母顺延） | `Level_001G.lua` |

- 禁止在逻辑里反复写 `Config.X`——顶部别名一次，后面用裸名。

## B. 函数作用域（最易犯错，重点看）

- **只有引擎事件回调用 `function`（全局）**，且函数名必须与
  `SubscribeToEvent("Event", "Name")` 里的字符串**逐字相同**。
  当前全局回调：`Start` `Stop` `HandleUpdate` `HandleRender` `HandleKeyDown`
  `HandleBegin` `HandleEnd`。
- **新增的辅助函数默认 `local function`**，并**定义在第一个调用它的函数之前**
  （Lua 自上而下解析局部，靠后定义会被当成全局 → 运行时 `nil` 崩溃）。
- 例外：现存的 `Update*` / `Draw*` / `Perform*` 历史上是全局（为绕开互调的定义顺序）。
  新增同类若与它们互调且改 local 会引入顺序问题，**保持全局、与现状一致**即可。
- **验证**：`luac5.4 -l -l <file> | grep <你的函数名>` → 调用处应是
  `GETUPVAL`（局部/上值，正确），不能是 `GETTABUP _ENV`（误成全局）。

## C. 注释与分节

- 大段分节用 `-- ===...===` 包裹标题（沿用现有风格）。
- 注释用**中文**，写“**为什么 / 有什么约束**”，不要复述代码字面。
- 临时禁用功能 → 用开关 + 一行说明（如 `Config.ENABLE_BOSS`），见绝不第 4 条。

## D. 数据表风格

- 关卡 / 配置数据用**紧凑单行表**：`{x=0, y=GY, w=12, h=PH}`。
- 关卡的五个数组 `platforms / sludges / enemies / interactables / hazards`
  **永远写全**，没有内容就写空表 `{}`（否则 `BuildRoom` 里 `ipairs(nil)` 崩溃）。
- 坐标用 `GY / PH` 等符号表达，见绝不第 5 条。
- 枚举型字段只用已支持的取值：
  - `interactables.type` ∈ `dash_core`(仅 R1) / `exit_door`
  - `hazards.type` ∈ `damage`
  - `enemies.type` ∈ `semi_executor`（目前唯一）
  - `debris.type` ∈ `hpbar / popup / missing / halfui / todo`

## E. 引擎 API 约定

- 向量：`Vector2(x, y)` / `Vector3(x, y, z)`。
- 取资源：`cache:GetResource("Type", "path")`。
- 节点/组件：`scene_:CreateChild("Name")` → `node:CreateComponent("RigidBody2D")`。
- **新脚本 / 新资源必须配 `.meta`**（24 字符 base64url uuid）：
  ```bash
  u=$(head -c18 /dev/urandom | base64 | tr '+/' '-_' | tr -d '='); printf '{\n  "uuid": "%s"\n}\n' "$u" > 路径.meta
  ```

## F. 输入（铁律一的代码落地）

| 意图 | 键盘 | 触屏 |
|---|---|---|
| 单次动作（攻击/跳/确认） | `input:GetKeyPress(KEY_X)` | `vBtn_.isPressed`（边沿） |
| 持续按住（移动/蓄力/长按清理） | `input:GetKeyDown(KEY_X)` | `vBtn_.isTouchPressed` |
| 全屏界面推进（标题/死亡/结局/菜单） | `KEY_RETURN/SPACE` | **必加** `input:GetMouseButtonPress(MOUSEB_LEFT)` |

- 同一交互的键盘分支与触屏分支**调用同一个函数**，禁止复制逻辑（参考 `ConfirmDashCore()`）。

## G. 提交

- 信息格式 `type: 摘要`，`type` ∈ `feat / fix / docs / refactor`；正文写**为什么**。
- 一次提交只做一件事。
- 开发分支：`claude/...`；不经允许不推 `master`，不建 PR。

---

## ✅ 完成的定义（Definition of Done）

**全部勾上才算“完成”**，否则只是“写完了”——这俩不是一回事。

- [ ] 所有改过的 `.lua` 过 `luac5.4 -p`；无残留 `luac.out`
- [ ] 新增 `local function` 经 `luac -l` 确认是 `GETUPVAL`
- [ ] 新交互**键盘 + 触屏双路径**（绝不第 1 条）
- [ ] 新脚本 / 资源配了 `.meta`
- [ ] 关卡数据五数组齐全、坐标符号化、枚举取值合法
- [ ] 无死代码 / 重复资源（绝不第 4 条）
- [ ] 对照 `project.json` 文案，**承诺 = build**（绝不第 3 条），否则在 commit 注明差距
- [ ] 手感 / 物理 / AI 改动标 ⚠️ 待真机（绝不第 7 条）
- [ ] commit 说清**为什么**

> 记住这游戏在讽刺什么：“功能完成不代表体验完成。”别把自己活成被嘲笑的那个原型。
