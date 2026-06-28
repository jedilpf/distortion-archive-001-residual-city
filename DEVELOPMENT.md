# 《失真档案 001：残机城》开发范式与协作指南

> 这份文档是本仓库的**唯一开发事实来源**。任何人(包括 AI agent)接手开发前，
> 必须先读完第 1～3 节。它把项目早期踩过的真实坑提炼成硬规则——照着做，
> 就不会重复犯错；不照着做，几乎必然重蹈覆辙。
>
> （`CLAUDE.md` / `AGENTS.md` 被 `.gitignore` 排除、且由引擎工具链提供，不要把
> 规范写进它们——会丢。规范一律写进本文件并提交。）
>
> 📌 **配套文档**：
> - 代码级“必须/禁止”条款见 [`CODING_STANDARDS.md`](./CODING_STANDARDS.md)（讲“代码具体怎么写”）。
> - 图片素材的尺寸/比例/锚点/平铺/出图方案见 [`ASSET_SPEC.md`](./ASSET_SPEC.md)
>   （专治“拉伸变形 / 角色下沉 / 帧动画乱跳”）。

---

## 0. 一句话项目定位

面向 **TapTap 手机端**（横屏、虚拟按键）的像素横版动作短篇。
玩家进入“残机城”，清理代码淤泥、击败半成品怪物、提炼模块，最后抵达
那个“仍在运行的旧项目”。主题是自指的：**关于 AI 生成时代“坏原型”的一款游戏。**

⚠️ **正因为它讽刺“差不多能跑但没人验证”的坏原型，我们自己更不能做成那样。**

---

## 1. 技术栈（务必先认清）

| 层 | 用什么 | 关键事实 |
|---|---|---|
| 引擎 | XD/TapTap **SCE「tapcode」引擎**（Urho3D 的 Lua 封装） | `collection_type: sce`；`Scene/Octree/Viewport/PhysicsWorld2D` 全是 Urho 标志 |
| 语言 | **Lua 5.4**（tolua 绑定） | 见 `scripts/.luarc.json` |
| 渲染 | **NanoVG** 立即模式 | 世界和 UI 都用 `nvg*`；不是 Urho Sprite2D。每帧在 `HandleRender` 里画 |
| 物理 | **Box2D**（Urho 2D） | `RigidBody2D`/`CollisionBox2D`/`CollisionCircle2D`/`PhysicsBeginContact2D` |
| 输入 | Urho `input:*` + 自研 `VirtualControls` | 见第 3 节铁律一 |
| 音频 | Urho `SoundSource`（Music/Effect 分类） | `PlaySFX` 已用 `SetAutoRemoveMode(REMOVE_COMPONENT)`，别再手动回收 |
| 构建 | SCE 构建器 → `dist/` | 源取自 `assets`+`scripts`；每个资源配 `.meta`（uuid） |
| 入口 | `main.lua` 的 `Start()`/`Stop()` + `SubscribeToEvent` 回调 | Urho Lua 主脚本范式 |

### ⛔ 头号约束：云端 / CI 环境**跑不起来这个游戏**

引擎本体与官方资源（`engine-docs/`、`urhox-libs/`、`lua-tools/` 等）被 `.gitignore`
排除，且不会安装到云端会话里。**所以在 Claude Code on the web / CI 里无法 build、
无法运行、无法看到画面。** 这意味着：

- 你**不能**用“跑一下看看”来验证逻辑。必须靠**读代码 + 静态校验 + 设计层兜底**（见第 6 节）。
- 任何改动**手感**（速度、跳跃、碰撞盒、敌人 AI、Boss）的提交，**必须在 TapTap 真机或真 build 上由人验收后**才算完成。文档里写“已修复”但没真机验证的，一律标注 ⚠️。

---

## 2. 项目结构

```
.project/            引擎工程配置(project.json 含 TapTap 商店文案 / i18n / resources)
assets/
  audio/             bgm + sfx (.ogg，各配 .meta)
  image/frames/      角色帧动画(10 动作 × 8 帧)
scripts/
  main.lua           主逻辑(场景/输入/战斗/相机/UI/音频/剧情/渲染)——目前 ~2400 行
  config.lua         全局配置(物理/战斗/关卡/状态枚举)
  systems/           CombatSystem(战斗判定)、CoordinateSystem(坐标转换)
  entities/          EnemyFactory(敌人创建)
  data/              Level_001A~F(关卡数据)、AssetManifest(资源清单)
```

**职责分离原则**：数据进 `data/`，可复用系统进 `systems/`，实体工厂进 `entities/`，
只有“胶水/流程”留在 `main.lua`。新功能优先按这个分层放，别再往 `main.lua` 堆。

---

## 3. 铁律（硬规则，违反即视为 bug）

每条都来自一次真实的失误。**反面教材 = 项目早期版本本身。**

### 铁律一：每个交互必须**同时**有键盘路径和触屏路径

> 反面教材：早期“提炼冲刺核心”的确认只写在 `HandleKeyDown`（键盘 E/回车），
> 触屏玩家互动后**被永久冻结**（`showConfirm_` 解不开）——这是目标平台手机上的硬软锁。
> 同类问题还有：死亡复活 / 结局推进只读 `vJump_.isPressed`，但那两个状态下
> 虚拟按钮被隐藏（`_shouldShow=false`）；结束菜单 `ST_MENU` 根本没有触屏入口。

**规则**：
- 任何能推进游戏的操作，写完键盘分支后**立刻**问自己：“手机没有键盘，怎么触发这个？”
- 全屏提示界面（标题/死亡/结局/菜单）用 **`input:GetMouseButtonPress(MOUSEB_LEFT)` 点屏兜底**
  （触摸→鼠标事件映射，与现有标题页一致）。
- 游戏内动作用**虚拟按钮**（`vAtk_`/`vJump_`/`vClean_`/`vDash_`/`vInteract_`）。
- 确认逻辑**抽成函数**供两条路径共用，别复制粘贴（见 `ConfirmDashCore()`）。
- `.isPressed` 是**边沿触发**（按下当帧），`.isTouchPressed` 是**按住**。
  单次触发用 `.isPressed`，长按（如蓄力跳）用 `.isTouchPressed`。别用错。

### 铁律二：内容**数据驱动**，逻辑与数据分离

> 反面教材：引擎本就支持多房间（`roomDefs_` 数组 / `BuildRoom(idx)` / `curRoom_`），
> 但早期 `DefineRooms` 只装 1 关、`NextRoom` 直接跳结局，白白浪费了已有架构。

**规则**：加关卡 = 写一个 `data/Level_xxx.lua` 数据文件 + 在 `DefineRooms` 注册，
**不改 `BuildRoom` 的逻辑**。同理，敌人参数进 `config.lua` / 关卡数据，不要硬编码在循环里。

### 铁律三：**承诺必须等于实现**（文案 = build）

> 反面教材：`project.json` 的 TapTap 描述承诺“6 个房间、2 种敌人、1 个 Boss”，
> 实际 build 只有 1 个房间、1 种敌人，`ENABLE_BOSS=false`。这是“货不对板”，
> 直接影响玩家信任与评分，比任何手感问题都严重。

**规则**：每次改动后，对照 `.project/project.json` 的 `taptap_publish.description` 检查：
**描述里写的每一项，build 里都真的存在吗？** 不存在就**要么补上、要么改文案**，
二选一，不允许长期不一致。当前状态见第 8 节对照表。

### 铁律四：改完**必须验证**（见第 6 节分层验证）

不允许“看起来对就提交”。最低限度跑 `luac5.4 -p` 语法校验；改数据跑 runtime 校验；
改手感打 ⚠️ 等真机。

### 铁律五：不留**死代码 / 重复资源 / 冗余逻辑**

> 反面教材：两套出口逻辑（位置触发 + 门互动）并存且未说明；
> `objImgs_.sludgeClean/Break/Block` 三个状态指向同一张图（视觉上无区别）；
> Boss 攻击逻辑用 `--[[ ]]` 注释成一大块死代码。

**规则**：要么接通、要么删除并在 commit 说明原因。临时禁用用**开关**（如 `Config.ENABLE_BOSS`）
+ 一行注释说明何时启用，不要大段注释尸体。

---

## 4. 坐标与数值约定（不背会就会画错位置）

存在**三套坐标系**，别混：

1. **世界坐标（米）**——物理/逻辑用。原点在房间左下区域，Y 向上为正。
   - 主地面：`{x=0, y=GY, w=12, h=PH}`，其中 `GY=-1.2`、`PH=1.0` → **地面顶面 y = GY+PH = -0.2**。
   - **实体脚底对齐节点位置**：敌人/主角的 `y` 用 `GY+PH`（站在地面上）。碰撞盒 `SetCenter(0, H/2)` 上移使底边=节点。
   - 主角出生点固定 `x=2`；房间宽 `roomWidth`（默认 `ROOM_W=12`）；出口门惯例放 `x≈10.6`。
   - `PPU=108`（每米像素数），相机正交。
2. **设计坐标（1920×1080）**——`VirtualControls` 按钮布局用。`scale = min(W,H)/1080`。
3. **屏幕坐标（像素）**——NanoVG 绘制用。`W2S(wx,wy)` 把世界→屏幕；
   `CoordSys.buttonToScreen(...)` 把设计→屏幕。需要画 UI 锚到世界物体时用 `W2S`。

**关键数值**都在 `config.lua`，**改数值改那里，别在逻辑里塞魔法数**：
`MOVE_SPEED`/`JUMP_SPEED`/`GRAVITY`/`DASH_*`/`ATK_*`/`MAX_HP`/`INV_TIME`/`CLEAR_TIME`/`COYOTE_TIME`/`HITSTOP_DUR`、
敌人 `ENEMY_*`、碰撞盒 `PLAYER_BOX_*`/`PLAYER_FOOT_*`、关卡 `GY/PH`。

---

## 5. 操作 SOP（手把手）

### 5.1 加一个新房间

1. 复制下面的模板到 `scripts/data/Level_xxx.lua`。
2. 生成配套 `.meta`（**必须有，否则构建器自动生成会变成未跟踪文件、且与仓库不一致**）：
   ```bash
   u=$(head -c18 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=')   # 24 字符 base64url
   printf '{\n  "uuid": "%s"\n}\n' "$u" > scripts/data/Level_xxx.lua.meta
   ```
3. 在 `main.lua` 顶部 `require` 它，并加入 `DefineRooms` 的 `roomDefs_` 数组（按顺序）。
4. 更新 `Config.TOTAL_ROOMS`。
5. 跑第 6 节验证。

**关卡数据模板**（字段含义见注释；五个数组 `platforms/sludges/enemies/interactables/hazards`
**必须存在**，可为空表 `{}`，否则 `BuildRoom` 里 `ipairs(nil)` 崩溃）：

```lua
-- data/Level_xxx.lua
local Config = require("config")
local Level = {}
local GY, PH = Config.GY, Config.PH

Level.name = "房间名"
Level.roomWidth = 12          -- 房间宽(米)；相机/出口按它走
-- Level.isBoss = true        -- 仅 Boss 房；ENABLE_BOSS=false 时退化为结局前走廊

Level.platforms = {           -- 必须含一条连续地面，禁止深坑(见铁律四的“无软锁”约定)
    {x=0, y=GY, w=12, h=PH},
    {x=4.5, y=GY+2.0, w=2.0, h=0.4},
}
Level.enemies = {             -- type 目前只有 "semi_executor"
    {type="semi_executor", x=3.5, y=GY+PH, hp=2},
}
Level.sludges = {             -- blocking=true 会生成静态碰撞盒(可清可跳)
    {x=6.0, y=GY+0.6, blocking=true},
}
Level.interactables = {       -- type: "dash_core"(仅 R1) | "exit_door"
    {x=10.6, y=GY+PH, type="exit_door"},
}
Level.hazards = {             -- type "damage"：踩到扣 1 血(重生满血，仅扣血不致软锁)
    {x=6.7, y=GY+0.5, w=1.0, h=0.3, type="damage"},
}
Level.hasExit = true          -- 走到最右或按门 → NextRoom

-- 可选的氛围/剧情文本：
Level.killText  = {"模块残留：","……"}       -- 击杀敌人时浮现
Level.clearText = {"TODO：","……"}           -- 清理淤泥时浮现
Level.wallTexts = {{text="…", wx=1, wy=2.2, color={150,150,150,110}, size=10}}
Level.debris    = {{type="hpbar", x=1.2, y=2.6}}  -- type 仅: hpbar/popup/missing/halfui/todo

return Level
```

**无软锁硬约束**：每个房间必须能从出生点（x=2）走到出口。**禁止做出无法跨越的深坑/高墙**；
危险区只允许扣血（重生满血）；阻挡淤泥必须可清理或可跳过。改完用“纸面走一遍”确认可达。

### 5.2 加第二种敌人（兑现“2 种敌人”承诺）⚠️ 需真机验证

1. 在 `config.lua` 加该类型的参数（速度/血量/攻击距离/弹道等），**别硬编码**。
2. 在 `EnemyFactory.create` 里按 `enemyData.type` 分支设置碰撞盒/初始状态。
3. 在 `UpdateEnemies` 的 AI 状态机里按 `e.type` 分支行为（如远程敌人用投射物，参考 `UpdateProjs`）。
4. 渲染：在 `AssetManifest` 注册贴图，`DrawGame` 里按类型选图。
5. 关卡数据用 `{type="新类型", ...}` 放置。
6. **打 ⚠️，等真机验收。**

### 5.3 启用 Boss（兑现“1 个 Boss”承诺）⚠️ 需真机验证

- Boss 房 `Level_001F` 已就位（`isBoss=true`）。逻辑骨架在 `SpawnBoss`/`UpdateBoss`/`DamageBoss`/
  `UpdateBossProjs`，主角打 Boss 的判定目前被注释在 `PerformAttack` 里。
- 启用步骤：`Config.ENABLE_BOSS=true` → 接回 `PerformAttack` 中被注释的 Boss 命中段 →
  确认 `bossLocked_` 在 Boss 死亡后解锁、触发结局 → **真机反复验收难度与手感**。
- 在没真机验证前，**保持 `ENABLE_BOSS=false`**：此时 Boss 房自动退化为结局前演出走廊，不影响流程。

---

## 6. 验证工作流（提交前必做）

因为**云端跑不起来**，验证靠分层：

| 层级 | 工具 | 查什么 |
|---|---|---|
| 1. 语法 | `luac5.4 -p <file>` | 所有改过的 `.lua` 必须通过 |
| 2. 符号解析 | `luac5.4 -l -l <file> \| grep <fn>` | 确认新函数是 `GETUPVAL`(局部/上值) 而非 `GETTABUP _ENV`(误成全局→运行时 nil) |
| 3. 数据校验 | `lua5.4` 加载关卡数据 | 五个必需数组都存在；坐标合理；debris/interactable type 合法 |
| 4. 纸面走查 | 人脑 | 从出生点到出口可达？每个交互有键鼠双路径？承诺对得上 build？ |
| 5. 真机 ⚠️ | TapTap 真机 / 真 build | **任何手感/物理/AI 改动的最终验收。云端做不到。** |

**提交前 checklist**：
- [ ] `luac5.4 -p` 全过，无遗留 `luac.out`（那是字节码副产物，别提交）
- [ ] 新增脚本都配了 `.meta`（uuid，24 字符 base64url）
- [ ] 新交互同时有键盘 + 触屏路径（铁律一）
- [ ] 没有引入死代码 / 重复资源（铁律五）
- [ ] 对照 `project.json` 文案，承诺与实现一致（铁律三），或在 commit 注明差距
- [ ] 手感类改动已标 ⚠️ 待真机
- [ ] commit message 说清“为什么”，不只是“改了什么”

**常用命令**：
```bash
# 语法批量校验
for f in scripts/main.lua scripts/config.lua scripts/data/*.lua; do luac5.4 -p "$f" && echo "OK $f"; done; rm -f luac.out
```

---

## 7. 状态机与流程（改流程前先看懂）

游戏状态枚举在 `config.lua`（`ST_*`）。主循环 `HandleUpdate` 按 `gameState_` 分派。
关键流程：`ST_TITLE → ST_OPENING → ST_PLAY`（逐房间，`NextRoom` 推进）`→ … → ST_ENDING → ST_MENU`。
死亡进 `ST_DEAD`，`Respawn` 留在当前房间并回满血。`ST_PAUSE/ST_SETTINGS/ST_ARCHIVE` 为菜单态。
顶部有“防呆”：`ENABLE_BOSS=false` 时强制把 Boss 相关态转回 `ST_PLAY`——**别移除它**。

---

## 8. 当前状态 vs 商店承诺（铁律三对照表，改动后请更新此表）

| 承诺（project.json） | 当前实现 | 状态 |
|---|---|---|
| 6 个房间 | `Level_001A~F`，`NextRoom` 逐房间推进 | ✅ |
| 1 个完整结尾 | `ST_ENDING` 三段式 | ✅ |
| 2 种敌人 | 仅 `semi_executor` | ❌ 待补（5.2） |
| 1 个 Boss | 房间就位，战斗 gated（`ENABLE_BOSS=false`） | ⚠️ 待接通+真机（5.3） |
| 完整触屏操作 | 标题/确认/死亡/结局/菜单已补触屏 | ✅（⚠️ 触摸→鼠标映射需真机确认） |

---

## 9. 已知技术债

- `main.lua` 仍 ~2400 行，渲染（`DrawGame`/`DrawTitle`/…）可拆到 `systems/Renderer`。
- 淤泥三态贴图相同，缺清理/破碎/阻挡的视觉区分（缺美术资源）。
- 第二种敌人、Boss 战未兑现（见第 8 节）。
- 房间装饰（线缆/电梯门等）目前 `curRoom_==1` 硬编码，理想应数据驱动进关卡的 `decor` 字段。

---

> **最后一句**：这游戏在嘲笑“功能完成不代表体验完成”。请把每一次提交都当成对这句话的回应——
> 不是“能跑”，而是“在玩家的手机上、真的好玩且不卡住”。
