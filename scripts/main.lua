-- ============================================================================
-- 《失真档案 001：残机城》- 残机城·浅层街区
-- 6房间线性短流程 + 完整剧情文本 + UI + 音频
-- ============================================================================

require "LuaScripts/Utilities/Sample"
require "urhox-libs.UI.VirtualControls"

local Config = require("config")
local Assets = require("data.AssetManifest")
local CoordSys = require("systems.CoordinateSystem")
local Level001A = require("data.Level_001A")
local Level001B = require("data.Level_001B")
local Level001C = require("data.Level_001C")
local Level001D = require("data.Level_001D")
local Level001E = require("data.Level_001E")
local Level001F = require("data.Level_001F")
local EnemyFactory = require("entities.EnemyFactory")
local CombatSystem = require("systems.CombatSystem")

-- ============================================================================
-- 前置声明(供音频系统引用)
-- ============================================================================
local scene_, cameraNode_, nvg_, physWorld_

-- ============================================================================
-- 设置(必须在音频系统前声明)
-- ============================================================================
local settings_ = {
    musicVol = 0.7,     -- 音乐音量 0~1
    sfxVol = 1.0,       -- 音效音量 0~1
    vibration = true,   -- 振动开关
    btnScale = 1.0,     -- 按钮缩放 0.8~1.4
    btnOpacity = 0.55,  -- 按钮透明度 0.3~0.9
}
local settingSel_ = 1   -- 设置项选中索引
local SETTING_ITEMS = {"musicVol","sfxVol","vibration","btnScale","btnOpacity"}
local musicVol_ = 0.7
local sfxVol_ = 1.0

-- ============================================================================
-- 音频系统
-- ============================================================================
local sfxNode_, musicNode_, musicSource_
local sfx_ = {}
local curMusic_ = ""

local function InitAudio()
    sfxNode_ = scene_:CreateChild("SFX")
    musicNode_ = scene_:CreateChild("Music")
    musicSource_ = musicNode_:CreateComponent("SoundSource")
    musicSource_:SetSoundType("Music")
    musicSource_:SetGain(0.5)
    -- 预加载音效
    local names = {"sfx_attack","sfx_hurt","sfx_enemy_hit","sfx_clean","sfx_fragment","sfx_dash","sfx_boss_enter","sfx_boss_die","sfx_proj"}
    for _, n in ipairs(names) do
        sfx_[n] = cache:GetResource("Sound", "audio/sfx/"..n..".ogg")
    end
end

local function PlaySFX(name)
    local snd = sfx_[name]
    if not snd or not sfxNode_ then return end
    local src = sfxNode_:CreateComponent("SoundSource")
    src:SetSoundType("Effect")
    src:SetGain(settings_.sfxVol)
    src:SetAutoRemoveMode(REMOVE_COMPONENT)
    src:Play(snd)
end

local function PlayMusic(path)
    if curMusic_ == path then return end
    curMusic_ = path
    if path == "" then musicSource_:Stop(); return end
    local snd = cache:GetResource("Sound", path)
    if snd then snd.looped = true; musicSource_:Play(snd) end
end

local function StopMusic()
    musicSource_:Stop(); curMusic_ = ""
end

-- 视觉效果
local screenFlash_ = 0
local cleanInterrupted_ = 0

-- ============================================================================
-- 常量
-- ============================================================================
local W, H = 1, 1 -- 实际值在Start()中从graphics获取
local DPR = 1
-- 从Config读取(本地别名,便于访问)
local PPU = Config.PPU
local GRAVITY = Config.GRAVITY
local MOVE_SPEED = Config.MOVE_SPEED
local JUMP_SPEED = Config.JUMP_SPEED
local PLAYER_R = Config.PLAYER_R
local DASH_SPEED = Config.DASH_SPEED
local DASH_DUR = Config.DASH_DUR
local DASH_CD = Config.DASH_CD
local ATK_RANGE = Config.ATK_RANGE
local ATK_DMG = Config.ATK_DMG
local ATK_CD = Config.ATK_CD
local KNOCKBACK = Config.KNOCKBACK
local MAX_HP = Config.MAX_HP
local INV_TIME = Config.INV_TIME
local CLEAR_TIME = Config.CLEAR_TIME
local COYOTE_TIME = Config.COYOTE_TIME
local HITSTOP_DUR = Config.HITSTOP_DUR
local ROOM_W = Config.ROOM_W
local TOTAL_ROOMS = Config.TOTAL_ROOMS
local CAT_GROUND = Config.CAT_GROUND
local CAT_PLAYER = Config.CAT_PLAYER
local CAT_SENSOR = Config.CAT_SENSOR
local CAT_ENEMY = Config.CAT_ENEMY

-- 状态枚举从Config读取
local ST_TITLE = Config.ST_TITLE
local ST_OPENING = Config.ST_OPENING
local ST_PLAY = Config.ST_PLAY
local ST_DEAD = Config.ST_DEAD
local ST_BOSS = Config.ST_BOSS
local ST_BOSS_INTRO = Config.ST_BOSS_INTRO
local ST_ENDING = Config.ST_ENDING
local ST_MENU = Config.ST_MENU
local ST_ARCHIVE = Config.ST_ARCHIVE
local ST_PAUSE = Config.ST_PAUSE
local ST_SETTINGS = Config.ST_SETTINGS
local pausePrev_ = ST_PLAY  -- 暂停前状态

-- ============================================================================
-- 全局
-- ============================================================================
local gameState_ = ST_TITLE
local curRoom_ = 1
local curRoomW_ = ROOM_W   -- 当前房间实际宽度
local hp_ = MAX_HP
local invT_ = 0
local hasDash_ = false
local dashT_ = 0
local dashCD_ = 0
local dashing_ = false
local dashDir_ = 1
local atkT_ = 0
local attacking_ = false
local atkDir_ = 1
local facingR_ = true
local shake_ = 0
local blink_ = 0
local cleaning_ = false
local cleanTarget_ = nil
local cleanProg_ = 0
local coyoteT_ = 0      -- 土狼时间计时器(离开平台后仍可跳)
local jumpBuf_ = 0      -- 跳跃缓冲计时器(空中按跳,落地自动执行)
local hitstopT_ = 0     -- 命中停顿计时器
local wasOnGround_ = false
local landingT_ = 0
local interactTarget_ = nil
local showConfirm_ = false
local debugDraw_ = false
-- 教程弹窗(屏幕中上方,单句,2秒淡出)
local tutText_ = ""
local tutTimer_ = 0

local function ShowTutorial(text)
    tutText_ = text; tutTimer_ = 2.5
end

-- ============================================================================
-- 轻量粒子系统(视觉打磨用)
-- ============================================================================
local vfx_ = {} -- {x,y,vx,vy,life,maxLife,r,g,b,size,type}

local function SpawnVFX(x, y, count, preset)
    for i=1,count do
        local p = {x=x, y=y, life=0, maxLife=0.5}
        if preset=="hit_spark" then
            local angle=math.random()*math.pi*2
            local spd=2+math.random()*3
            p.vx=math.cos(angle)*spd; p.vy=math.sin(angle)*spd-1
            p.r=255; p.g=180+math.random(60); p.b=50; p.size=2+math.random()*2
            p.maxLife=0.3+math.random()*0.2
        elseif preset=="land_dust" then
            p.vx=(math.random()-0.5)*2; p.vy=-0.5-math.random()*1.5
            p.r=100; p.g=140; p.b=120; p.size=2+math.random()*3
            p.maxLife=0.4+math.random()*0.2
        elseif preset=="clean_burst" then
            local angle=math.random()*math.pi*2
            local spd=1.5+math.random()*2.5
            p.vx=math.cos(angle)*spd; p.vy=math.sin(angle)*spd
            p.r=80; p.g=220; p.b=200; p.size=2+math.random()*3
            p.maxLife=0.5+math.random()*0.3
        elseif preset=="dash_burst" then
            p.vx=(math.random()-0.5)*1.5; p.vy=(math.random()-0.5)*1.5
            p.r=60; p.g=200; p.b=230; p.size=1.5+math.random()*2
            p.maxLife=0.25+math.random()*0.15
        end
        table.insert(vfx_, p)
    end
end

local fragments_ = 0
local totalSludge_ = 0
local sludgeCleared_ = 0
local playerNode_, playerBody_, playerFootNode_
local onGround_ = false
local gndCount_ = 0
local platforms_ = {}
local enemies_ = {}
local sludges_ = {}
local pickups_ = {}
local interactables_ = {}
local hazards_ = {}
local projs_ = {}
local floatTexts_ = {}
local roomTexts_ = {}
local roomDebris_ = {}

-- ============================================================================
-- [DISABLED in v0.1] Boss系统 - 将在v1.0启用
-- ============================================================================
local bossHP_, bossMaxHP_ = 0, 12
local bossNode_, bossBody_
local bossPhase_ = 1
local bossAtkT_ = 0
local bossInvT_ = 0
local bossPat_ = 1
local bossProjs_ = {}
local bossGroundWarn_ = {} -- 地面预警标记
local bossLocked_ = false
local bossHalfShown_ = false
local bossLowShown_ = false

-- 叙事
local firstDashUsed_ = false
local deathT_ = 0

-- 开场字幕
local openingLines_ = {
    "在 AI 可以快速生成游戏之后，",
    "人们开始拥有无数个\"差不多能跑\"的原型。",
    "",
    "有些没有手感。",
    "有些没有结尾。",
    "有些只是像游戏。",
    "",
    "后来，它们被关掉，被遗忘，被覆盖。",
    "",
    "但没有真正停止运行。",
}
local openLine_ = 0
local openLineT_ = 0

-- Boss出场文本
local bossIntroLines_ = {
    "正在生成核心玩法……",
    "正在添加类银河城元素……",
    "正在添加肉鸽成长……",
    "正在添加卡牌构筑……",
    "错误：手感缺失。",
}
local bossIntroLine_ = 0
local bossIntroT_ = 0

-- 结尾
local endPhase_ = 0 -- 0=Boss击败文本 1=黑屏等待 2=归档文本
local endT_ = 0
local endLine_ = 0
local endLineT_ = 0

-- 虚拟控制
local vJoy_, vJump_, vAtk_, vClean_, vDash_, vInteract_

-- ============================================================================
-- 房间定义
-- ============================================================================
local roomDefs_ = {}
local function DefineRooms()
    roomDefs_ = { Level001A, Level001B, Level001C, Level001D, Level001E, Level001F }
    totalSludge_ = 0
    for _, r in ipairs(roomDefs_) do totalSludge_ = totalSludge_ + #r.sludges end
end

-- ============================================================================
-- 工具
-- ============================================================================
local function W2S(wx, wy)
    local cx, cy = cameraNode_.position.x, cameraNode_.position.y
    return W/2+(wx-cx)*PPU, H/2-(wy-cy)*PPU
end

local function ShowFloat(lines, wx, wy, color, dur)
    color = color or {200,200,200,220}; dur = dur or 4.0
    for i, l in ipairs(lines) do
        table.insert(floatTexts_, {text=l, x=wx, y=wy+(i-1)*0.55, timer=0, duration=dur, color=color})
    end
end

-- ============================================================================
-- 初始化
-- ============================================================================
-- 图片句柄
local charImgs_ = {}
local envImgs_ = {}

function Start()
    SampleStart()
    -- 获取实际屏幕尺寸(适配所有分辨率)
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    DPR = dpr
    W = math.floor(physW / dpr)
    H = math.floor(physH / dpr)
    Config.W = W; Config.H = H; Config.DPR = DPR
    print("[Init] Screen: "..W.."x"..H.." (phys "..physW.."x"..physH..", dpr="..dpr..")")
    nvg_ = nvgCreate(1)
    nvgCreateFont(nvg_, "px", "Fonts/MiSans-Regular.ttf")
    -- 加载角色帧动画(基于设定图生成的正式像素精灵)
    -- 加载角色帧动画
    -- 加载帧动画套件(每动作8帧)
    charImgs_.idle = {}
    charImgs_.run = {}
    charImgs_.attack = {}
    charImgs_.dash = {}
    charImgs_.jump = {}
    charImgs_.cast = {}
    charImgs_.hit = {}
    for i=1,8 do
        charImgs_.idle[i] = nvgCreateImage(nvg_, Assets.char.idle[i], 0)
        charImgs_.run[i] = nvgCreateImage(nvg_, Assets.char.run[i], 0)
        charImgs_.attack[i] = nvgCreateImage(nvg_, Assets.char.attack[i], 0)
        charImgs_.dash[i] = nvgCreateImage(nvg_, Assets.char.dash[i], 0)
        charImgs_.jump[i] = nvgCreateImage(nvg_, Assets.char.jump[i], 0)
        charImgs_.cast[i] = nvgCreateImage(nvg_, Assets.char.cast[i], 0)
        charImgs_.hit[i] = nvgCreateImage(nvg_, Assets.char.hit[i], 0)
    end
    -- 加载对局物件素材
    objImgs_ = {}
    objImgs_.sludge = nvgCreateImage(nvg_, Assets.objects.sludge, 0)
    objImgs_.sludgeClean = objImgs_.sludge
    objImgs_.sludgeBreak = objImgs_.sludge
    objImgs_.sludgeBlock = objImgs_.sludge
    objImgs_.enemyIdle = nvgCreateImage(nvg_, Assets.enemy.idle, 0)
    objImgs_.enemyWalk1 = nvgCreateImage(nvg_, Assets.enemy.walk1, 0)
    objImgs_.enemyWalk2 = nvgCreateImage(nvg_, Assets.enemy.walk2, 0)
    objImgs_.enemyHit = nvgCreateImage(nvg_, Assets.enemy.hurt, 0)
    objImgs_.casterIdle = nvgCreateImage(nvg_, Assets.enemy.caster_idle, 0)
    objImgs_.casterCast = nvgCreateImage(nvg_, Assets.enemy.caster_cast, 0)
    objImgs_.casterHurt = nvgCreateImage(nvg_, Assets.enemy.caster_hurt, 0)
    objImgs_.bossIdle = nvgCreateImage(nvg_, Assets.boss.idle, 0)
    objImgs_.bossAtk = nvgCreateImage(nvg_, Assets.boss.attack, 0)
    objImgs_.door = nvgCreateImage(nvg_, Assets.objects.door, 0)
    objImgs_.fragment = nvgCreateImage(nvg_, Assets.objects.fragment, 0)
    objImgs_.dashCore = nvgCreateImage(nvg_, Assets.objects.dashCore, 0)
    objImgs_.platUpper = nvgCreateImage(nvg_, Assets.objects.platUpper, 0)
    -- 加载按钮图标
    btnImgs_ = {}
    btnImgs_.attack = nvgCreateImage(nvg_, Assets.buttons.attack, 0)
    btnImgs_.jump = nvgCreateImage(nvg_, Assets.buttons.jump, 0)
    btnImgs_.clean = nvgCreateImage(nvg_, Assets.buttons.clean, 0)
    btnImgs_.dash = nvgCreateImage(nvg_, Assets.buttons.dash, 0)
    btnImgs_.pause = nvgCreateImage(nvg_, Assets.buttons.pause, 0)
    btnImgs_.settings = nvgCreateImage(nvg_, Assets.buttons.settings, 0)
    -- 加载环境素材
    envImgs_.bgFar = nvgCreateImage(nvg_, Assets.env.bgFar, NVG_IMAGE_REPEATX)
    envImgs_.bgWall = nvgCreateImage(nvg_, Assets.env.bgWall, NVG_IMAGE_REPEATX)
    envImgs_.ground = nvgCreateImage(nvg_, Assets.env.ground, NVG_IMAGE_REPEATX)
    envImgs_.platform = nvgCreateImage(nvg_, Assets.env.platform, NVG_IMAGE_REPEATX)
    envImgs_.monitor = nvgCreateImage(nvg_, Assets.env.monitor, 0)
    envImgs_.debris = nvgCreateImage(nvg_, Assets.env.debris, 0)
    envImgs_.titleBg = nvgCreateImage(nvg_, Assets.env.titleBg, 0)
    envImgs_.endingBg = nvgCreateImage(nvg_, Assets.env.sceneEnding, 0)
    DefineRooms()
    CreateScene()
    InitAudio()
    CreateControls()
    PlayMusic(Assets.audio.bgm_explore)
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent(nvg_, "NanoVGRender", "HandleRender")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("PhysicsBeginContact2D", "HandleBegin")
    SubscribeToEvent("PhysicsEndContact2D", "HandleEnd")
end

function Stop()
    VirtualControls.Shutdown()
    if nvg_ then nvgDelete(nvg_) end
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree"); scene_:CreateComponent("DebugRenderer")
    physWorld_ = scene_:CreateComponent("PhysicsWorld2D")
    physWorld_.gravity = Vector2(0, -GRAVITY)
    cameraNode_ = scene_:CreateChild("Camera")
    local cam = cameraNode_:CreateComponent("Camera")
    cam.orthographic = true; cam.orthoSize = H/PPU
    cameraNode_.position = Vector3(ROOM_W/2, 1, -10) -- 相机稍微看高,底部留给UI
    renderer:SetViewport(0, Viewport:new(scene_, cam))
end

local vPause_
local vArchive_ -- 档案按钮(结束菜单用)

function CreateControls()
    -- VirtualControls 坐标系: 1920x1080 设计分辨率
    -- ===== 左下: 摇杆(大区域,半透明) =====
    vJoy_ = VirtualControls.CreateJoystick({
        position=Vector2(180,-160), alignment={HA_LEFT,VA_BOTTOM},
        radius=120, knobRadius=48, keyBinding="AD",
        color={80,210,220}, opacity=0.5, activeOpacity=0.7,
        alwaysShow=true,
    })

    -- ===== 右下: 横排4按钮(正式手机动作游戏尺寸) =====
    -- 攻击  跳跃  清理  冲刺
    local btnY = -95      -- 距底部(1080坐标系)
    local btnR = 62       -- 按钮半径(更大更清楚)
    local gap = 138       -- 按钮间距(更宽松)

    -- 攻击(最左)
    vAtk_ = VirtualControls.CreateButton({
        position=Vector2(-gap*3-55, btnY), alignment={HA_RIGHT,VA_BOTTOM},
        radius=btnR-2, label="", keyBinding=KEY_J,
        iconPath=Assets.buttons.attack,
        color={255,110,70}, opacity=0.6, activeOpacity=0.9,
        alwaysShow=true,
    })
    -- 跳跃(第二,最大)
    vJump_ = VirtualControls.CreateButton({
        position=Vector2(-gap*2-55, btnY), alignment={HA_RIGHT,VA_BOTTOM},
        radius=btnR+6, label="", keyBinding=KEY_SPACE,
        iconPath=Assets.buttons.jump,
        color={80,200,255}, opacity=0.6, activeOpacity=0.9,
        alwaysShow=true,
    })
    -- 清理(第三)
    vClean_ = VirtualControls.CreateButton({
        position=Vector2(-gap*1-55, btnY), alignment={HA_RIGHT,VA_BOTTOM},
        radius=btnR-4, label="", keyBinding=KEY_K,
        iconPath=Assets.buttons.clean,
        color={180,90,240}, opacity=0.55, activeOpacity=0.85,
        alwaysShow=true,
    })
    -- 冲刺(最右)
    vDash_ = VirtualControls.CreateButton({
        position=Vector2(-55, btnY), alignment={HA_RIGHT,VA_BOTTOM},
        radius=btnR-4, label="", keyBinding=KEY_L,
        iconPath=Assets.buttons.dash,
        color={80,220,230}, opacity=0.55, activeOpacity=0.85,
        cooldown=DASH_CD, alwaysShow=true,
    })
    -- 互动E(攻击上方)
    vInteract_ = VirtualControls.CreateButton({
        position=Vector2(-gap*3-55, btnY-130), alignment={HA_RIGHT,VA_BOTTOM},
        radius=42, label="E", keyBinding=KEY_E,
        color={230,210,70}, opacity=0.4, activeOpacity=0.75,
        alwaysShow=true,
    })

    -- ===== 右上: 暂停 + 设置 =====
    vPause_ = VirtualControls.CreateButton({
        position=Vector2(-40,40), alignment={HA_RIGHT,VA_TOP},
        radius=26, label="||", keyBinding=KEY_ESCAPE,
        iconPath=Assets.buttons.pause,
        color={160,160,170}, opacity=0.45, alwaysShow=true,
    })
    vArchive_ = VirtualControls.CreateButton({
        position=Vector2(-100,40), alignment={HA_RIGHT,VA_TOP},
        radius=26, label="", keyBinding=KEY_2,
        iconPath=Assets.buttons.settings,
        color={160,160,170}, opacity=0.45, alwaysShow=true,
    })

    -- 库按钮视觉透明化: 只保留触摸命中,外观由 DrawTouchButtons 用 NanoVG 自绘
    -- (避免库的廉价彩色圆与自绘按钮重叠双绘)
    for _,v in ipairs({vJoy_,vAtk_,vJump_,vClean_,vDash_,vInteract_,vPause_,vArchive_}) do
        v.opacity=0.0; v.activeOpacity=0.0
    end
end

-- ============================================================================
-- 房间
-- ============================================================================
local function ClearRoom()
    for _,e in ipairs(enemies_) do if e.node then e.node:Remove() end end
    for _,s in ipairs(sludges_) do if s.node then s.node:Remove() end end
    for _,p in ipairs(platforms_) do if p.node then p.node:Remove() end end
    for _,pk in ipairs(pickups_) do if pk.node then pk.node:Remove() end end
    for _,it in ipairs(interactables_) do if it.node then it.node:Remove() end end
    for _,hz in ipairs(hazards_) do if hz.node then hz.node:Remove() end end
    for _,pr in ipairs(projs_) do if pr.node then pr.node:Remove() end end
    if bossNode_ then bossNode_:Remove(); bossNode_=nil end
    for _,bp in ipairs(bossProjs_) do if bp.node then bp.node:Remove() end end
    enemies_={}; sludges_={}; platforms_={}; pickups_={}
    interactables_={}; hazards_={}; projs_={}; bossProjs_={}; bossGroundWarn_={}
    floatTexts_={}; roomTexts_={}; roomDebris_={}
    cleanTarget_=nil; interactTarget_=nil; showConfirm_=false; bossLocked_=false
end

local function BuildRoom(idx)
    ClearRoom()
    local rd = roomDefs_[idx]; if not rd then return end
    for _,pd in ipairs(rd.platforms) do
        local n=scene_:CreateChild("Platform"); n:SetPosition2D(pd.x+pd.w/2,pd.y+pd.h/2)
        local b=n:CreateComponent("RigidBody2D"); b.bodyType=BT_STATIC
        local s=n:CreateComponent("CollisionBox2D"); s:SetSize(pd.w,pd.h); s.friction=0.4; s.categoryBits=CAT_GROUND
        table.insert(platforms_,{x=pd.x,y=pd.y,w=pd.w,h=pd.h,node=n})
    end
    -- 墙
    local wl=scene_:CreateChild("Wall"); wl:SetPosition2D(-0.5,0)
    local wlb=wl:CreateComponent("RigidBody2D"); wlb.bodyType=BT_STATIC
    local wls=wl:CreateComponent("CollisionBox2D"); wls:SetSize(1,20); wls.categoryBits=CAT_GROUND
    table.insert(platforms_,{x=-1,y=-10,w=1,h=20,node=wl,wall=true})
    local rw=rd.roomWidth or ROOM_W; curRoomW_=rw
    local wr=scene_:CreateChild("Wall"); wr:SetPosition2D(rw+0.5,0)
    local wrb=wr:CreateComponent("RigidBody2D"); wrb.bodyType=BT_STATIC
    local wrs=wr:CreateComponent("CollisionBox2D"); wrs:SetSize(1,20); wrs.categoryBits=CAT_GROUND
    if rd.hasExit then wrs.trigger=true end
    table.insert(platforms_,{x=ROOM_W,y=-10,w=1,h=20,node=wr,wall=true,exit=rd.hasExit})
    -- 淤泥
    for _,sd in ipairs(rd.sludges) do
        local n=scene_:CreateChild("Sludge"); n:SetPosition2D(sd.x,sd.y)
        if sd.blocking then
            local b=n:CreateComponent("RigidBody2D"); b.bodyType=BT_STATIC
            local sh=n:CreateComponent("CollisionBox2D"); sh:SetSize(1.2,1.5); sh.categoryBits=CAT_GROUND
        end
        table.insert(sludges_,{x=sd.x,y=sd.y,node=n,alive=true,blocking=sd.blocking})
    end
    -- 敌人
    for _,ed in ipairs(rd.enemies) do
        local enemy = EnemyFactory.create(scene_, ed)
        table.insert(enemies_, enemy)
    end
    for _,it in ipairs(rd.interactables) do
        local n=scene_:CreateChild("Interact"); n:SetPosition2D(it.x,it.y)
        table.insert(interactables_,{x=it.x,y=it.y,node=n,type=it.type,used=false})
    end
    for _,hz in ipairs(rd.hazards) do
        local n=scene_:CreateChild("Hazard"); n:SetPosition2D(hz.x+hz.w/2,hz.y+hz.h/2)
        table.insert(hazards_,{x=hz.x,y=hz.y,w=hz.w,h=hz.h,node=n,type=hz.type})
    end
    if rd.wallTexts then for _,wt in ipairs(rd.wallTexts) do table.insert(roomTexts_,wt) end end
    if rd.debris then for _,d in ipairs(rd.debris) do table.insert(roomDebris_,d) end end
    -- 教程弹窗
    if idx==1 then ShowTutorial("左侧摇杆移动 → 向右推进") end
    if rd.isBoss and Config.ENABLE_BOSS then
        bossIntroLine_=0; bossIntroT_=0
        gameState_=ST_BOSS_INTRO; bossLocked_=true
    end
end

-- ============================================================================
-- 玩家
-- ============================================================================
local function CreatePlayer()
    if playerNode_ then playerNode_:Remove() end
    local groundTop = Config.GY + Config.PH
    playerNode_=scene_:CreateChild("Player"); playerNode_:SetPosition2D(2, groundTop)
    playerBody_=playerNode_:CreateComponent("RigidBody2D")
    playerBody_.bodyType=BT_DYNAMIC; playerBody_.fixedRotation=true
    playerBody_.linearDamping=0; playerBody_.gravityScale=1.3
    -- 主体碰撞盒(矩形,底部对齐节点位置=脚底)
    local bs=playerNode_:CreateComponent("CollisionBox2D")
    bs:SetSize(Config.PLAYER_BOX_W, Config.PLAYER_BOX_H)
    bs:SetCenter(0, Config.PLAYER_BOX_H/2)
    bs.density=1; bs.friction=0; bs.restitution=0
    bs.categoryBits=CAT_PLAYER; bs.maskBits=CAT_GROUND|CAT_ENEMY
    -- 独立脚底传感器节点(只有它触发onGround)
    playerFootNode_=playerNode_:CreateChild("PlayerFootSensor")
    playerFootNode_:SetPosition2D(0, 0)  -- 相对父节点,在脚底
    local ftBody=playerFootNode_:CreateComponent("RigidBody2D")
    ftBody.bodyType=BT_DYNAMIC; ftBody.fixedRotation=true; ftBody.gravityScale=0
    local ft=playerFootNode_:CreateComponent("CollisionBox2D")
    ft:SetSize(Config.PLAYER_FOOT_W, Config.PLAYER_FOOT_H)
    ft:SetCenter(0, -Config.PLAYER_FOOT_H/2)
    ft.trigger=true; ft.categoryBits=CAT_SENSOR; ft.maskBits=CAT_GROUND
    onGround_=false; gndCount_=0
end

-- ============================================================================
-- Boss
-- ============================================================================
local bossAtkType_ = 0     -- 当前攻击类型: 1=弹幕, 2=召唤骑士, 3=淤泥
local bossWarnType_ = 0    -- 预警中的攻击类型
local bossSummonCount_ = 0 -- 已召唤骑士计数
local bossSludgeCount_ = 0 -- 已生成淤泥计数

local function SpawnBoss()
    if not Config.ENABLE_BOSS then return end
    bossHP_=bossMaxHP_; bossPhase_=1; bossAtkT_=2; bossInvT_=0; bossPat_=1
    bossHalfShown_=false; bossLowShown_=false
    bossAtkType_=0; bossWarnType_=0; bossSummonCount_=0; bossSludgeCount_=0
    -- Boss 出现在右侧平台上 (平台顶面 y=-0.5+1.0=0.5, Boss半径1.0→中心0.5+1.0=1.5)
    bossNode_=scene_:CreateChild("Boss"); bossNode_:SetPosition2D(11, 1.5)
    bossBody_=bossNode_:CreateComponent("RigidBody2D")
    bossBody_.bodyType=BT_DYNAMIC; bossBody_.fixedRotation=true; bossBody_.gravityScale=1
    local s=bossNode_:CreateComponent("CollisionCircle2D")
    s.radius=1.0; s.density=2; s.friction=0.3
    s.categoryBits=CAT_ENEMY; s.maskBits=CAT_GROUND|CAT_PLAYER
    gameState_=ST_BOSS
end

-- ============================================================================
-- 伤害
-- ============================================================================
local function DamagePlayer(dmg)
    if invT_>0 or dashing_ then return end
    hp_=hp_-dmg; invT_=INV_TIME; shake_=0.2
    PlaySFX("sfx_hurt")
    if cleaning_ then cleaning_=false; cleanProg_=cleanProg_*0.5; cleanInterrupted_=0.4 end  -- 保留一半进度
    if hp_<=0 then
        gameState_=ST_DEAD; deathT_=0
        -- 死亡像素碎裂
        if playerNode_ then
            local dp=playerNode_.position2D
            for i=1,16 do
                local p={x=dp.x+(math.random()-0.5)*0.5,y=dp.y+(math.random()-0.5)*0.8,
                    vx=(math.random()-0.5)*4,vy=math.random()*3+1,
                    life=0,maxLife=0.6+math.random()*0.4,
                    r=60+math.random(80),g=180+math.random(60),b=200+math.random(50),
                    size=3+math.random()*3}
                table.insert(vfx_,p)
            end
        end
    end
end

local function DamageBoss(dmg)
    if bossInvT_>0 then return end
    bossHP_=bossHP_-dmg; bossInvT_=0.3; shake_=0.15; PlaySFX("sfx_enemy_hit")
    -- 半血文本
    if bossHP_<=bossMaxHP_/2 and not bossHalfShown_ then
        bossHalfShown_=true
        ShowFloat({"功能已完成。","体验未定义。"}, 8, 2.5, {255,200,50,230}, 3)
    end
    -- 残血文本(25%)
    if bossHP_<=math.floor(bossMaxHP_*0.25) and not bossLowShown_ then
        bossLowShown_=true
        ShowFloat({"为什么我什么都有，","却还是不好玩？"}, 8, 2.5, {200,100,100,230}, 3.5)
    end
    if bossHP_<=0 then
        if bossNode_ then bossNode_:Remove(); bossNode_=nil end
        bossLocked_=false; PlaySFX("sfx_boss_die"); PlayMusic(Assets.audio.bgm_ending)
        gameState_=ST_ENDING; endPhase_=0; endT_=0; endLine_=0; endLineT_=0
    end
end

local function SpawnFrag(x,y)
    local n=scene_:CreateChild("Frag"); n:SetPosition2D(x,y)
    table.insert(pickups_,{x=x,y=y,node=n,t=0})
end

-- ============================================================================
-- 流程
-- ============================================================================
local function StartGame()
    -- 进入开场字幕
    gameState_=ST_OPENING; openLine_=0; openLineT_=0
end

local function ActualStart()
    gameState_=ST_PLAY; curRoom_=1
    hp_=MAX_HP; invT_=0; hasDash_=false; dashing_=false
    dashT_=0; dashCD_=0; attacking_=false; atkT_=0
    cleaning_=false; cleanProg_=0; firstDashUsed_=false
    fragments_=0; sludgeCleared_=0; showConfirm_=false
    CreatePlayer(); BuildRoom(1)
end

local function Respawn()
    hp_=MAX_HP; invT_=0; dashing_=false; dashT_=0
    attacking_=false; atkT_=0; cleaning_=false; cleanProg_=0
    local spawnY = (roomDefs_[curRoom_].isBoss and Config.ENABLE_BOSS) and 1.5 or (Config.GY + Config.PH)
    if playerNode_ then playerNode_:SetPosition2D(2,spawnY); playerBody_.linearVelocity=Vector2(0,0) end
    onGround_=false; gndCount_=0
    -- Boss房重生: 直接重生Boss,不重播出场文本
    if roomDefs_[curRoom_].isBoss and Config.ENABLE_BOSS then
        if bossNode_ then bossNode_:Remove(); bossNode_=nil end
        for _,bp in ipairs(bossProjs_) do if bp.node then bp.node:Remove() end end
        bossProjs_={}; bossGroundWarn_={}
        for _,e in ipairs(enemies_) do if e.node then e.node:Remove() end end
        enemies_={}
        for _,s in ipairs(sludges_) do if s.node then s.node:Remove() end end
        sludges_={}
        SpawnBoss()
    else
        gameState_=ST_PLAY
    end
end

local function NextRoom()
    -- 多房间推进: 还有下一间则切换并重建,最后一间通过才进入结局
    if curRoom_ < #roomDefs_ then
        curRoom_ = curRoom_ + 1
        CreatePlayer()      -- 在新房间起点(x=2)重新放置主角(HP 跨房间保留)
        BuildRoom(curRoom_) -- ClearRoom 会清掉上一间的实体;Boss 房在 ENABLE_BOSS 开启时由此进入出场
        return
    end
    -- 终点 → 结局
    PlayMusic(Assets.audio.bgm_ending)
    gameState_=ST_ENDING; endPhase_=0; endT_=0; endLine_=0; endLineT_=0
end

-- ============================================================================
-- 更新
-- ============================================================================
function HandleUpdate(eventType, eventData)
    local dt=eventData["TimeStep"]:GetFloat()
    -- [防呆] Boss disabled时不允许停留在Boss相关状态
    if not Config.ENABLE_BOSS and (gameState_==ST_BOSS_INTRO or gameState_==ST_BOSS) then
        gameState_=ST_PLAY; bossLocked_=false
    end
    blink_=blink_+dt; shake_=math.max(0,shake_-dt*3)
    screenFlash_=math.max(0,screenFlash_-dt*2)
    cleanInterrupted_=math.max(0,cleanInterrupted_-dt*2)
    landingT_=math.max(0,landingT_-dt*4)
    tutTimer_=math.max(0,tutTimer_-dt)
    -- 粒子更新
    for i=#vfx_,1,-1 do local p=vfx_[i]; p.life=p.life+dt
        p.x=p.x+p.vx*dt; p.y=p.y+p.vy*dt; p.vy=p.vy+8*dt
        if p.life>=p.maxLife then table.remove(vfx_,i) end
    end
    -- 命中停顿：冻结一切
    if hitstopT_>0 then hitstopT_=hitstopT_-dt; return end
    -- 土狼时间+跳跃缓冲
    if onGround_ then coyoteT_=COYOTE_TIME else coyoteT_=math.max(0,coyoteT_-dt) end
    jumpBuf_=math.max(0,jumpBuf_-dt)
    -- 落地检测+缓冲跳跃执行
    if onGround_ and not wasOnGround_ then
        landingT_=0.15; shake_=math.max(shake_,0.04)
        if playerNode_ then local pp=playerNode_.position2D; SpawnVFX(pp.x,pp.y-0.3,4,"land_dust") end
        -- 落地瞬间:如果有缓冲跳跃,立即执行
        if jumpBuf_>0 and playerBody_ then
            playerBody_.linearVelocity=Vector2(playerBody_.linearVelocity.x,JUMP_SPEED)
            onGround_=false; jumpBuf_=0; coyoteT_=0
        end
    end
    wasOnGround_=onGround_
    -- 浮动文本
    for i=#floatTexts_,1,-1 do
        floatTexts_[i].timer=floatTexts_[i].timer+dt
        if floatTexts_[i].timer>floatTexts_[i].duration then table.remove(floatTexts_,i) end
    end

    -- 所有按钮只在游戏中显示(标题/开场/结局/菜单时完全隐藏)
    local inGame=(gameState_==ST_PLAY or gameState_==ST_BOSS or gameState_==ST_PAUSE or gameState_==ST_SETTINGS)
    if vJoy_ then vJoy_.alwaysShow=inGame; vJoy_._shouldShow=inGame end
    if vAtk_ then vAtk_.alwaysShow=inGame; vAtk_._shouldShow=inGame end
    if vJump_ then vJump_.alwaysShow=inGame; vJump_._shouldShow=inGame end
    if vClean_ then vClean_.alwaysShow=inGame; vClean_._shouldShow=inGame end
    if vDash_ then vDash_.alwaysShow=inGame; vDash_._shouldShow=inGame end
    if vInteract_ then vInteract_.alwaysShow=inGame; vInteract_._shouldShow=inGame end
    if vPause_ then vPause_.alwaysShow=inGame; vPause_._shouldShow=inGame end
    if vArchive_ then vArchive_.alwaysShow=inGame; vArchive_._shouldShow=inGame end

    -- 点击屏幕进入游戏(标题/开场/Boss出场/结束菜单重开)
    if gameState_==ST_TITLE or gameState_==ST_OPENING or gameState_==ST_BOSS_INTRO or gameState_==ST_MENU then
        if input:GetMouseButtonPress(MOUSEB_LEFT) then
            if gameState_==ST_TITLE then StartGame()
            elseif gameState_==ST_OPENING then ActualStart()
            elseif gameState_==ST_MENU then ActualStart()
            elseif gameState_==ST_BOSS_INTRO and Config.ENABLE_BOSS then PlaySFX("sfx_boss_enter"); PlayMusic(Assets.audio.bgm_boss); SpawnBoss()
            end
        end
    end

    if gameState_==ST_OPENING then
        openLineT_=openLineT_+dt
        if openLineT_>1.0 then openLineT_=0; openLine_=openLine_+1
            if openLine_>#openingLines_ then ActualStart() end
        end
    elseif gameState_==ST_BOSS_INTRO and Config.ENABLE_BOSS then
        bossIntroT_=bossIntroT_+dt
        if bossIntroT_>0.8 then bossIntroT_=0; bossIntroLine_=bossIntroLine_+1
            if bossIntroLine_>#bossIntroLines_ then PlaySFX("sfx_boss_enter"); PlayMusic(Assets.audio.bgm_boss); SpawnBoss() end
        end
    elseif gameState_==ST_PAUSE then
        -- 暂停状态: 检查按钮恢复或进入设置
        if vPause_ and vPause_.isPressed then gameState_=pausePrev_ end
        if input:GetKeyPress(KEY_S) then gameState_=ST_SETTINGS end
        if input:GetKeyPress(KEY_RETURN) or input:GetKeyPress(KEY_ESCAPE) then gameState_=pausePrev_ end
        if input:GetKeyPress(KEY_R) then ActualStart() end
    elseif gameState_==ST_SETTINGS then
        -- 设置状态: 上下选择,左右调节
        if input:GetKeyPress(KEY_UP) or input:GetKeyPress(KEY_W) then settingSel_=math.max(1,settingSel_-1) end
        if input:GetKeyPress(KEY_DOWN) or input:GetKeyPress(KEY_S) then settingSel_=math.min(#SETTING_ITEMS,settingSel_+1) end
        local key=SETTING_ITEMS[settingSel_]
        local delta=0
        if input:GetKeyDown(KEY_LEFT) or input:GetKeyDown(KEY_A) then delta=-dt end
        if input:GetKeyDown(KEY_RIGHT) or input:GetKeyDown(KEY_D) then delta=dt end
        if delta~=0 then
            if key=="musicVol" then settings_.musicVol=math.max(0,math.min(1,settings_.musicVol+delta*0.8))
            elseif key=="sfxVol" then settings_.sfxVol=math.max(0,math.min(1,settings_.sfxVol+delta*0.8))
            elseif key=="btnScale" then settings_.btnScale=math.max(0.8,math.min(1.4,settings_.btnScale+delta*0.5))
            elseif key=="btnOpacity" then settings_.btnOpacity=math.max(0.3,math.min(0.9,settings_.btnOpacity+delta*0.6))
            end
        end
        if key=="vibration" and (input:GetKeyPress(KEY_LEFT) or input:GetKeyPress(KEY_RIGHT) or input:GetKeyPress(KEY_RETURN)) then
            settings_.vibration=not settings_.vibration
        end
        -- 实时应用音量
        if musicSource_ then musicSource_:SetGain(settings_.musicVol) end
        musicVol_=settings_.musicVol; sfxVol_=settings_.sfxVol
        -- 返回暂停
        if input:GetKeyPress(KEY_ESCAPE) or (vPause_ and vPause_.isPressed) then gameState_=ST_PAUSE end
    elseif gameState_==ST_ARCHIVE then
        -- 档案页: 按暂停/档案/跳跃按钮返回
        if (vPause_ and vPause_.isPressed) or (vArchive_ and vArchive_.isPressed) or (vJump_ and vJump_.isPressed) then
            gameState_=pausePrev_ or ST_MENU
        end
    elseif gameState_==ST_PLAY or gameState_==ST_BOSS then
        -- 暂停/档案检测
        if vPause_ and vPause_.isPressed then pausePrev_=gameState_; gameState_=ST_PAUSE; return end
        if vArchive_ and vArchive_.isPressed then pausePrev_=gameState_; gameState_=ST_SETTINGS; return end
        UpdatePlayer(dt); UpdateEnemies(dt); UpdatePickups(dt)
        UpdateHazards(dt); UpdateProjs(dt); UpdateCamera(dt)
        -- Boss 战: 此前 UpdateBoss/UpdateBossProjs 定义了却从未接入主循环,补上
        if gameState_==ST_BOSS then UpdateBoss(dt); UpdateBossProjs(dt) end
        if playerNode_ then
            -- 安全兜底: 如果因物理bug穿透了地面,放回地面(不扣血)
            local safeY = roomDefs_[curRoom_].isBoss and 1.5 or 0.5
            if playerNode_.position2D.y<-6 then
                playerNode_:SetPosition2D(2,safeY); playerBody_.linearVelocity=Vector2(0,0)
            end
            -- 房间过渡
            if not bossLocked_ and playerNode_.position2D.x>curRoomW_-0.3 and roomDefs_[curRoom_].hasExit then NextRoom() end
        end
    elseif gameState_==ST_DEAD then
        deathT_=deathT_+dt
        -- 触屏: 跳跃按钮或点屏幕作为确认(死亡界面按钮已隐藏,需点屏兜底)
        if deathT_>1.5 and ((vJump_ and vJump_.isPressed) or input:GetMouseButtonPress(MOUSEB_LEFT)) then Respawn() end
    elseif gameState_==ST_ENDING then
        -- 触屏: 跳跃按钮或点屏幕跳过结局阶段(结局界面按钮已隐藏,需点屏兜底)
        if (vJump_ and vJump_.isPressed) or input:GetMouseButtonPress(MOUSEB_LEFT) then
            if endPhase_==0 then endPhase_=1; endT_=0
            elseif endPhase_==1 then endPhase_=2; endT_=0; endLine_=0; endLineT_=0
            elseif endPhase_==2 then gameState_=ST_MENU end
        end
        endT_=endT_+dt
        if endPhase_==0 then
            -- Phase0: 黑屏2秒(Boss击败后静默)
            if endT_>2.0 then endPhase_=1; endT_=0 end
        elseif endPhase_==1 then
            -- Phase1: 项目信息显示3.5秒
            if endT_>3.5 then endPhase_=2; endT_=0; endLine_=0; endLineT_=0 end
        elseif endPhase_==2 then
            -- Phase2: 归档文本逐行
            endLineT_=endLineT_+dt
            if endLineT_>1.5 then endLineT_=0; endLine_=endLine_+1
                if endLine_>4 then gameState_=ST_MENU end
            end
        end
    end
end

-- 确认提炼冲刺核心(键盘与触屏共用,避免确认逻辑只存在于 HandleKeyDown 导致手机软锁)
local function ConfirmDashCore()
    if not (showConfirm_ and interactTarget_) then return end
    hasDash_=true; showConfirm_=false
    interactTarget_.used=true; if interactTarget_.node then interactTarget_.node:Remove() end
    fragments_=fragments_+1; shake_=0.1; screenFlash_=0.5; PlaySFX("sfx_fragment")
    ShowFloat({"检测到可提炼模块。","模块名称：冲刺种子。","状态：可运行。","副作用：未知。"},
        8, 2, {100,220,255,230}, 4)
end

function UpdatePlayer(dt)
    if not playerNode_ then return end
    invT_=math.max(0,invT_-dt); atkT_=math.max(0,atkT_-dt); dashCD_=math.max(0,dashCD_-dt)
    -- 冲刺按钮视觉透明化(获得/未获得/冷却状态由 DrawTouchButtons 自绘体现)
    if vDash_ then vDash_.opacity=0.0; vDash_.activeOpacity=0.0 end
    if showConfirm_ then
        -- 触屏: 互动按钮确认提炼(键盘 E/回车 在 HandleKeyDown 处理)
        if vInteract_ and vInteract_.isPressed then ConfirmDashCore() end
        if playerBody_ then playerBody_.linearVelocity=Vector2(0,playerBody_.linearVelocity.y) end
        return
    end
    if dashing_ then
        dashT_=dashT_-dt
        if dashT_<=0 then dashing_=false; playerBody_.gravityScale=1.3
        else playerBody_.linearVelocity=Vector2(dashDir_*DASH_SPEED,0); playerBody_.gravityScale=0; return end
    end
    -- 清理
    local cleanHeld=input:GetKeyDown(KEY_K) or (vClean_ and vClean_.isPressed)
    if cleanHeld and cleanTarget_ then
        cleaning_=true; cleanProg_=cleanProg_+dt
        if cleanProg_>=CLEAR_TIME then
            cleanTarget_.alive=false
            if cleanTarget_.node then cleanTarget_.node:Remove() end
            sludgeCleared_=sludgeCleared_+1; SpawnFrag(cleanTarget_.x,cleanTarget_.y+0.5); PlaySFX("sfx_clean")
            SpawnVFX(cleanTarget_.x,cleanTarget_.y,10,"clean_burst")
            if roomDefs_[curRoom_] and roomDefs_[curRoom_].clearText then
                ShowFloat(roomDefs_[curRoom_].clearText, cleanTarget_.x, cleanTarget_.y+1.2, {100,200,100,220}, 3.5)
            end
            cleanTarget_=nil; cleanProg_=0; cleaning_=false
        end
        playerBody_.linearVelocity=Vector2(0,playerBody_.linearVelocity.y); return
    else cleaning_=false; cleanProg_=0 end
    -- 移动(带加速/减速曲线,地面急停,空中惯性)
    local mx=0
    if input:GetKeyDown(KEY_A) or input:GetKeyDown(KEY_LEFT) then mx=-1 end
    if input:GetKeyDown(KEY_D) or input:GetKeyDown(KEY_RIGHT) then mx=1 end
    if vJoy_ then local jx=vJoy_.x or 0; if math.abs(jx)>0.2 then mx=jx>0 and 1 or -1 end end
    if mx~=0 then facingR_=(mx>0) end
    local vel=playerBody_.linearVelocity
    local targetSpd=onGround_ and MOVE_SPEED or (MOVE_SPEED*0.92)
    local targetVx=mx*targetSpd
    -- 加速/减速插值(地面响应快,空中略慢)
    local accel=onGround_ and 28.0 or 14.0  -- 地面加速极快≈即时响应
    if mx==0 and onGround_ then accel=35.0 end -- 松手急停(地面)
    local newVx=vel.x+(targetVx-vel.x)*math.min(1,accel*dt)
    -- 极小速度归零(防止滑动感)
    if mx==0 and math.abs(newVx)<0.3 then newVx=0 end
    playerBody_.linearVelocity=Vector2(newVx,vel.y)
    -- 跳跃(土狼时间+缓冲输入+跳跃截断)
    local jmp=input:GetKeyPress(KEY_SPACE) or input:GetKeyPress(KEY_W) or input:GetKeyPress(KEY_UP)
    if vJump_ and vJump_.isPressed then jmp=true end
    if jmp then
        if coyoteT_>0 then
            -- 正常跳跃(含土狼时间宽容)
            playerBody_.linearVelocity=Vector2(playerBody_.linearVelocity.x,JUMP_SPEED)
            onGround_=false; coyoteT_=0; jumpBuf_=0
        else
            -- 空中按跳:存入缓冲,落地后自动执行
            jumpBuf_=0.18
        end
    end
    -- 跳跃截断(松开跳跃键时削减上升速度→可控跳跃高度)
    local jmpHeld=input:GetKeyDown(KEY_SPACE) or input:GetKeyDown(KEY_W) or input:GetKeyDown(KEY_UP)
    if vJump_ then jmpHeld=jmpHeld or vJump_.isTouchPressed end
    if not jmpHeld and playerBody_.linearVelocity.y>2.0 and not onGround_ then
        -- 松开跳跃键:立即削减上升速度(短按=小跳,长按=高跳)
        local vy=playerBody_.linearVelocity.y*0.5
        playerBody_.linearVelocity=Vector2(playerBody_.linearVelocity.x,math.min(vy,3.0))
    end
    -- 攻击(无移动锁定,攻击时可移动)
    local atk=input:GetKeyPress(KEY_J)
    if vAtk_ and vAtk_.isPressed then atk=true end
    if atk and atkT_<=0 then attacking_=true; atkT_=ATK_CD; atkDir_=facingR_ and 1 or -1; PlaySFX("sfx_attack"); PerformAttack() end
    if atkT_<=ATK_CD-0.12 then attacking_=false end  -- 攻击动画更短更利落
    -- 冲刺
    local dash=input:GetKeyPress(KEY_L) or input:GetKeyPress(KEY_LSHIFT) or input:GetKeyPress(KEY_RSHIFT)
    if vDash_ and vDash_.isPressed then dash=true end
    if dash and hasDash_ and dashCD_<=0 then
        dashing_=true; dashT_=DASH_DUR; dashCD_=DASH_CD
        dashDir_=facingR_ and 1 or -1; PlaySFX("sfx_dash")
        local pp=playerNode_.position2D; SpawnVFX(pp.x,pp.y,6,"dash_burst")
        playerBody_.linearVelocity=Vector2(dashDir_*DASH_SPEED,0); playerBody_.gravityScale=0
        -- R5首次冲刺文本
        if not firstDashUsed_ then
            firstDashUsed_=true
            ShowFloat({"系统提示：","移动模块接入成功。","请注意：功能完成不代表体验完成。"},
                playerNode_.position2D.x, playerNode_.position2D.y+2, {150,200,200,220}, 3.5)
        end
    end
    -- 互动
    local interact=input:GetKeyPress(KEY_E)
    if vInteract_ and vInteract_.isPressed then interact=true end
    if interact and interactTarget_ and not interactTarget_.used then
        if interactTarget_.type=="dash_core" then showConfirm_=true
        elseif interactTarget_.type=="exit_door" then
            -- 进入下一房间;Boss 战未结束(bossLocked_)时不放行,防止按门跳过 Boss
            if not bossLocked_ then NextRoom() end
        end
    end
    -- 检测目标
    local pp=playerNode_.position2D
    cleanTarget_=nil
    for _,s in ipairs(sludges_) do
        if s.alive and math.sqrt((s.x-pp.x)^2+(s.y-pp.y)^2)<1.5 then cleanTarget_=s; break end
    end
    interactTarget_=nil
    for _,it in ipairs(interactables_) do
        if not it.used and math.sqrt((it.x-pp.x)^2+(it.y-pp.y)^2)<1.8 then interactTarget_=it; break end
    end
    -- 位置触发教程(R1各段,每2单位一个目标)
    if curRoom_==1 and tutTimer_<=0 then
        if pp.x>2.5 and pp.x<3.5 and not attacking_ then ShowTutorial("点击攻击消灭敌人")
        elseif pp.x>4.5 and pp.x<5.5 and cleanTarget_ then ShowTutorial("长按清理：清除代码淤泥")
        elseif pp.x>6.5 and pp.x<7.5 and hasDash_ then ShowTutorial("冲刺穿越危险区")
        end
    end
end

function PerformAttack()
    if not playerNode_ then return end
    local pp = playerNode_.position2D
    CombatSystem.performAttack(pp, atkDir_, enemies_, {
        onHit = function(e)
            hitstopT_ = HITSTOP_DUR
            shake_ = 0.08
            PlaySFX("sfx_enemy_hit")
            SpawnVFX(e.node.position2D.x, e.node.position2D.y, 5, "hit_spark")
        end,
        onKill = function(e, deathPos)
            SpawnFrag(deathPos.x, deathPos.y + 0.5)
            SpawnVFX(deathPos.x, deathPos.y, 8, "hit_spark")
            if roomDefs_[curRoom_] and roomDefs_[curRoom_].killText then
                ShowFloat(roomDefs_[curRoom_].killText, deathPos.x, deathPos.y + 1, {200,200,100,220}, 3.5)
            end
        end,
    })
    -- 主角近战命中 Boss(近战盒前伸半个攻击距离,圆形判定)
    if gameState_ == ST_BOSS and bossNode_ and bossBody_ and bossHP_ > 0 then
        local ax = pp.x + atkDir_ * ATK_RANGE * 0.5
        local bp = bossNode_.position2D
        if math.sqrt((ax-bp.x)^2+(pp.y-bp.y)^2) < ATK_RANGE+0.3 then
            DamageBoss(ATK_DMG); hitstopT_ = HITSTOP_DUR
            local kb = (bp.x > pp.x) and 1 or -1
            bossBody_.linearVelocity = Vector2(kb*3, 2)
        end
    end
end

-- 敌方投射物(报错弹幕): 射入 projs_,由 UpdateProjs 统一移动+近距判定扣血
local function SpawnEnemyProj(x, y, tx, ty)
    if not scene_ then return end
    local dir = Vector2(tx - x, ty - y):Normalized()
    local spd = Config.CASTER_PROJ_SPEED
    local pn = scene_:CreateChild("EProj"); pn:SetPosition2D(x, y)
    table.insert(projs_, {node=pn, vx=dir.x*spd, vy=dir.y*spd, life=3.0})
    PlaySFX("sfx_proj")
end

function UpdateEnemies(dt)
    for _,e in ipairs(enemies_) do if e.alive and e.node then
        e.invT = math.max(0, e.invT - dt)
        local ep = e.node.position2D
        local pp = playerNode_ and playerNode_.position2D
        local distToPlayer = pp and math.abs(ep.x - pp.x) or 999
        e.atkTimer = math.max(0, e.atkTimer - dt)

        if e.type == "semi_caster" then
            -- 远程施法器: 站桩,朝玩家,蓄力(带预警)后发射弹幕;被近身则后撤
            e.atkDir = (pp and pp.x > ep.x) and 1 or -1
            if e.atkState == "idle" then
                if e.body then e.body.linearVelocity = Vector2(0, e.body.linearVelocity.y) end
                if pp and distToPlayer < Config.CASTER_RANGE then
                    e.atkState = "windup"; e.atkTimer = Config.CASTER_WINDUP
                end
            elseif e.atkState == "windup" then
                -- 太近就后撤拉开距离,其余时间站桩蓄力
                local flee = (pp and distToPlayer < Config.CASTER_MIN_RANGE)
                    and (-e.atkDir * Config.CASTER_RETREAT_SPEED) or 0
                if e.body then e.body.linearVelocity = Vector2(flee, e.body.linearVelocity.y) end
                if e.atkTimer <= 0 then e.atkState = "attack"; e.atkTimer = 0.05 end
            elseif e.atkState == "attack" then
                if pp then
                    SpawnEnemyProj(ep.x, ep.y + Config.ENEMY_HEIGHT*0.6, pp.x, pp.y + 0.4)
                end
                e.atkState = "cooldown"; e.atkTimer = Config.CASTER_CD
            elseif e.atkState == "cooldown" then
                if e.body then e.body.linearVelocity = Vector2(0, e.body.linearVelocity.y) end
                if e.atkTimer <= 0 then e.atkState = "idle" end
            end

        -- 近战执行器(原有行为)
        elseif e.atkState == "idle" then
            -- 巡逻移动
            e.moveT = e.moveT + dt
            if e.moveT > 2.0 then e.moveT = 0; e.moveDir = -e.moveDir end
            if e.body then e.body.linearVelocity = Vector2(e.moveDir * 1.8, e.body.linearVelocity.y) end
            -- 发现玩家 → 进入前摇
            if distToPlayer < Config.ENEMY_ATK_RANGE then
                e.atkState = "windup"
                e.atkTimer = Config.ENEMY_ATK_WINDUP
                e.atkDir = (pp.x > ep.x) and 1 or -1
                if e.body then e.body.linearVelocity = Vector2(0, e.body.linearVelocity.y) end
            end
        elseif e.atkState == "windup" then
            -- 前摇中: 停止移动
            if e.body then e.body.linearVelocity = Vector2(0, e.body.linearVelocity.y) end
            if e.atkTimer <= 0 then
                e.atkState = "attack"
                e.atkTimer = 0.15  -- 攻击持续时间
            end
        elseif e.atkState == "attack" then
            -- 攻击中: 检测命中
            if pp and CombatSystem.checkEnemyAttack(e, pp) then
                if invT_ <= 0 then
                    DamagePlayer(1)
                end
            end
            if e.atkTimer <= 0 then
                e.atkState = "cooldown"
                e.atkTimer = Config.ENEMY_ATK_CD
            end
        elseif e.atkState == "cooldown" then
            -- 冷却: 缓慢移动
            if e.body then e.body.linearVelocity = Vector2(e.moveDir * 0.8, e.body.linearVelocity.y) end
            if e.atkTimer <= 0 then
                e.atkState = "idle"
            end
        end
    end end
end

function UpdatePickups(dt)
    if not playerNode_ then return end; local pp=playerNode_.position2D
    for i=#pickups_,1,-1 do local pk=pickups_[i]; pk.t=pk.t+dt
        if pk.node then pk.node:SetPosition2D(pk.x,pk.y+math.sin(pk.t*4)*0.08)
            local pos=pk.node.position2D
            if math.sqrt((pos.x-pp.x)^2+(pos.y-pp.y)^2)<0.8 then
                fragments_=fragments_+1; pk.node:Remove(); table.remove(pickups_,i); PlaySFX("sfx_fragment")
            end
        end
    end
end

function UpdateHazards(dt)
    if not playerNode_ then return end; local pp=playerNode_.position2D
    for _,hz in ipairs(hazards_) do
        if hz.type=="damage" and pp.x>hz.x and pp.x<hz.x+hz.w and pp.y>hz.y and pp.y<hz.y+hz.h+0.5 then
            DamagePlayer(1)
        end
    end
end

function UpdateProjs(dt)
    for i=#projs_,1,-1 do local p=projs_[i]; p.life=p.life-dt
        if p.life<=0 then if p.node then p.node:Remove() end; table.remove(projs_,i)
        elseif p.node then local pos=p.node.position2D
            p.node:SetPosition2D(pos.x+p.vx*dt,pos.y+p.vy*dt)
            if playerNode_ then local pp=playerNode_.position2D
                if math.sqrt((pos.x-pp.x)^2+(pos.y-pp.y)^2)<0.45 then DamagePlayer(1); p.life=0 end
            end
        end
    end
end

function UpdateCamera(dt)
    if not playerNode_ then return end; local pp=playerNode_.position2D
    local tx=math.max(W/(2*PPU),math.min(pp.x,curRoomW_-W/(2*PPU)))
    local orthoH=H/PPU -- 可见世界高度(随屏幕自适应)
    -- 平台顶部对齐设计坐标y=740(屏幕68.5%高度处)
    local ty=pp.y+0.185*orthoH-PLAYER_R; local cx,cy=cameraNode_.position.x,cameraNode_.position.y
    local sp=6*dt; local nx=cx+(tx-cx)*sp; local ny=cy+(ty-cy)*sp
    local sx,sy=0,0
    if shake_>0 then sx=(math.random()-0.5)*shake_*0.4; sy=(math.random()-0.5)*shake_*0.4 end
    cameraNode_.position=Vector3(nx+sx,ny+sy,-10)
end

local bossWarnT_ = 0  -- Boss攻击预警计时

function UpdateBoss(dt)
    if not bossNode_ or bossHP_<=0 then return end
    bossInvT_=math.max(0,bossInvT_-dt); bossAtkT_=bossAtkT_-dt
    local bp=bossNode_.position2D; local pp=playerNode_ and playerNode_.position2D or Vector2(4,1.5)
    local dx=pp.x-bp.x; local spd=bossPhase_==2 and 2.5 or 1.5

    -- 更新地面预警
    for i=#bossGroundWarn_,1,-1 do
        bossGroundWarn_[i].timer=bossGroundWarn_[i].timer-dt
        if bossGroundWarn_[i].timer<=0 then table.remove(bossGroundWarn_,i) end
    end

    -- 预警期间: Boss红光闪烁,不移动
    if bossWarnT_>0 then
        bossWarnT_=bossWarnT_-dt; bossBody_.linearVelocity=Vector2(0,bossBody_.linearVelocity.y)
        if bossWarnT_<=0 then
            -- 预警结束,执行攻击
            if bossWarnType_==1 then
                -- 攻击1: 方块弹幕(3个红色报错方块,速度中等)
                for i=-1,1 do
                    local pn=scene_:CreateChild("BP"); pn:SetPosition2D(bp.x,bp.y+0.5)
                    local dir=Vector2(dx,1.0+i*0.8):Normalized()
                    table.insert(bossProjs_,{node=pn,vx=dir.x*4.5,vy=dir.y*4.5,life=3.0})
                end
                PlaySFX("sfx_proj"); bossAtkT_=2.5
            elseif bossWarnType_==2 then
                -- 攻击2: 召唤半成品骑士(半血后,最多1只)
                if bossSummonCount_<1 then
                    local sx=pp.x+(math.random()>0.5 and 2 or -2)
                    sx=math.max(2,math.min(12,sx))
                    local n=scene_:CreateChild("Enemy"); n:SetPosition2D(sx,3)
                    local b=n:CreateComponent("RigidBody2D"); b.bodyType=BT_DYNAMIC; b.fixedRotation=true
                    local sh=n:CreateComponent("CollisionCircle2D"); sh.radius=0.38; sh.density=1; sh.friction=0.2
                    sh.categoryBits=CAT_ENEMY; sh.maskBits=CAT_GROUND|CAT_PLAYER
                    -- 补齐 atkState/atkTimer/atkDir: UpdateEnemies 第一行就读 atkTimer,
                    -- 缺字段会 nil 崩溃(此前 Boss 禁用从未触发,属隐藏 bug)。补全后走近战 AI。
                    table.insert(enemies_,{type="knight",node=n,body=b,hp=2,alive=true,invT=0,
                        moveDir=1,moveT=0,atkState="idle",atkTimer=0,atkDir=1,
                        shootT=0,baseX=sx,baseY=3,floatT=0})
                    bossSummonCount_=bossSummonCount_+1
                end
                bossAtkT_=3.0
            elseif bossWarnType_==3 then
                -- 攻击3: 生成代码淤泥(残血,1小块)
                if bossSludgeCount_<1 then
                    local sx=pp.x+(math.random()>0.5 and 1.5 or -1.5)
                    sx=math.max(2,math.min(12,sx))
                    local n=scene_:CreateChild("Sludge"); n:SetPosition2D(sx,0.5)
                    table.insert(sludges_,{x=sx,y=0.5,node=n,alive=true,blocking=false})
                    bossSludgeCount_=bossSludgeCount_+1
                end
                bossAtkT_=3.5
            end
        end
        return
    end

    -- 移动: 缓慢追踪玩家
    if math.abs(dx)>3 then
        bossBody_.linearVelocity=Vector2(dx>0 and spd or -spd,bossBody_.linearVelocity.y)
    end

    -- 接触伤害
    if playerNode_ and math.sqrt((bp.x-pp.x)^2+(bp.y-pp.y)^2)<1.3 then DamagePlayer(1) end

    -- 攻击选择
    if bossAtkT_<=0 then
        bossWarnT_=0.5; shake_=0.05  -- 0.5秒前摇
        -- 根据阶段选择攻击类型
        if bossPhase_==1 then
            -- Phase1: 只有弹幕
            bossWarnType_=1
        elseif bossPhase_==2 then
            -- Phase2(半血): 弹幕+召唤骑士
            local roll=math.random(1,3)
            if roll<=2 then bossWarnType_=1
            else bossWarnType_=2
                -- 地面红色故障圈预警
                table.insert(bossGroundWarn_,{x=pp.x,y=0.6,timer=0.5,type="circle"})
            end
        else
            -- Phase3(残血): 弹幕+淤泥
            local roll=math.random(1,3)
            if roll<=2 then bossWarnType_=1
            else bossWarnType_=3
                -- 地面红色裂纹预警
                table.insert(bossGroundWarn_,{x=pp.x,y=0.6,timer=0.5,type="crack"})
            end
        end
    end

    -- 阶段升级
    if bossHP_<=bossMaxHP_/2 and bossPhase_==1 then bossPhase_=2; bossAtkT_=1; shake_=0.3 end
    if bossHP_<=math.floor(bossMaxHP_*0.25) and bossPhase_==2 then bossPhase_=3; bossAtkT_=1.5; shake_=0.3 end
end

function UpdateBossProjs(dt)
    for i=#bossProjs_,1,-1 do local p=bossProjs_[i]; p.life=p.life-dt
        if p.life<=0 then if p.node then p.node:Remove() end; table.remove(bossProjs_,i)
        elseif p.node then local pos=p.node.position2D
            p.node:SetPosition2D(pos.x+p.vx*dt,pos.y+p.vy*dt)
            if playerNode_ then local pp=playerNode_.position2D
                if math.sqrt((pos.x-pp.x)^2+(pos.y-pp.y)^2)<0.5 then DamagePlayer(1); p.life=0 end
            end
        end
    end
end

-- ============================================================================
-- 碰撞
-- ============================================================================
function HandleBegin(eventType, eventData)
    local nA=eventData["NodeA"]:GetPtr("Node"); local nB=eventData["NodeB"]:GetPtr("Node")
    if not playerFootNode_ then return end
    -- 只响应 PlayerFootSensor 的接触(不响应主体碰撞)
    local o=(nA==playerFootNode_) and nB or (nB==playerFootNode_) and nA or nil
    if o and (o.name=="Platform" or o.name=="Wall") then
        gndCount_=gndCount_+1; onGround_=true
    end
end
function HandleEnd(eventType, eventData)
    local nA=eventData["NodeA"]:GetPtr("Node"); local nB=eventData["NodeB"]:GetPtr("Node")
    if not playerFootNode_ then return end
    local o=(nA==playerFootNode_) and nB or (nB==playerFootNode_) and nA or nil
    if o and (o.name=="Platform" or o.name=="Wall") then
        gndCount_=gndCount_-1
        if gndCount_<=0 then gndCount_=0; onGround_=false end
    end
end

-- ============================================================================
-- 按键
-- ============================================================================
function HandleKeyDown(eventType, eventData)
    local key=eventData["Key"]:GetInt()
    if key==KEY_F1 then debugDraw_=not debugDraw_; return end
    if gameState_==ST_TITLE then
        if key==KEY_RETURN or key==KEY_SPACE then StartGame() end
    elseif gameState_==ST_OPENING then
        if key==KEY_RETURN or key==KEY_SPACE then ActualStart() end
    elseif gameState_==ST_BOSS_INTRO and Config.ENABLE_BOSS then
        if key==KEY_RETURN or key==KEY_SPACE then SpawnBoss() end
    elseif gameState_==ST_DEAD then
        if deathT_>1.5 and (key==KEY_RETURN or key==KEY_SPACE) then Respawn() end
    elseif gameState_==ST_ENDING then
        if key==KEY_RETURN or key==KEY_SPACE then
            if endPhase_==0 then endPhase_=1; endT_=0
            elseif endPhase_==1 then endPhase_=2; endT_=0; endLine_=0; endLineT_=0
            elseif endPhase_==2 then gameState_=ST_MENU end
        end
    elseif gameState_==ST_MENU then
        if key==KEY_1 or key==KEY_RETURN then ActualStart()
        elseif key==KEY_2 then gameState_=ST_ARCHIVE end
    elseif gameState_==ST_ARCHIVE then
        if key==KEY_RETURN or key==KEY_SPACE or key==KEY_ESCAPE then
            gameState_=pausePrev_ or ST_MENU
        end
    elseif gameState_==ST_PAUSE then
        -- 暂停菜单按键(继续/设置/重开已在Update中通过GetKeyPress处理)
        return
    elseif showConfirm_ then
        if key==KEY_ESCAPE then showConfirm_=false
        elseif key==KEY_E or key==KEY_RETURN then ConfirmDashCore() end
    else
        -- 游戏中按ESC → 暂停
        if key==KEY_ESCAPE and (gameState_==ST_PLAY or gameState_==ST_BOSS) then
            pausePrev_=gameState_; gameState_=ST_PAUSE
        end
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================
function HandleRender(eventType, eventData)
    nvgBeginFrame(nvg_, W, H, DPR)
    if gameState_==ST_TITLE then DrawTitle()
    elseif gameState_==ST_OPENING then DrawOpening()
    elseif gameState_==ST_BOSS_INTRO and Config.ENABLE_BOSS then DrawBossIntro()
    elseif gameState_==ST_PLAY or gameState_==ST_BOSS then DrawGame(); DrawHUD()
    elseif gameState_==ST_DEAD then DrawGame(); DrawDeath()
    elseif gameState_==ST_PAUSE then DrawGame(); DrawHUD(); DrawPause()
    elseif gameState_==ST_SETTINGS then DrawGame(); DrawHUD(); DrawSettings()
    elseif gameState_==ST_ENDING then DrawEnding()
    elseif gameState_==ST_MENU then DrawMenu()
    elseif gameState_==ST_ARCHIVE then DrawArchive()
    end
    nvgEndFrame(nvg_)
end

function DrawTitle()
    -- 标题背景图(全屏,无遮罩)
    if envImgs_.titleBg and envImgs_.titleBg~=0 then
        nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H)
        nvgFillPaint(nvg_,nvgImagePattern(nvg_,0,0,W,H,0,envImgs_.titleBg,1.0))
        nvgFill(nvg_)
    else
        nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(6,4,10,255)); nvgFill(nvg_)
    end
    -- 底部轻微暗化(让底部文字可读)
    nvgBeginPath(nvg_); nvgRect(nvg_,0,H*0.7,W,H*0.3)
    nvgFillPaint(nvg_,nvgLinearGradient(nvg_,0,H*0.7,0,H,nvgRGBA(0,0,0,0),nvgRGBA(0,0,0,150)))
    nvgFill(nvg_)
    -- 故障扫描线(淡)
    for i=1,3 do nvgBeginPath(nvg_); nvgRect(nvg_,math.random(0,W),math.random(0,H),math.random(40,200),1)
        nvgFillColor(nvg_,nvgRGBA(0,255,80,math.random(8,20))); nvgFill(nvg_) end
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    -- 标题
    nvgFontSize(nvg_,32); nvgFillColor(nvg_,nvgRGBA(200,50,50,240))
    nvgText(nvg_,W/2,H*0.35,"失真档案 001：残机城")
    -- 副标题
    nvgFontSize(nvg_,13); nvgFillColor(nvg_,nvgRGBA(100,190,100,160))
    nvgText(nvg_,W/2,H*0.35+35,"没做完的游戏，还剩一条命。")
    -- 点击提示(呼吸闪烁)
    local a=math.floor(math.sin(blink_*2)*80)+160
    nvgFontSize(nvg_,14); nvgFillColor(nvg_,nvgRGBA(200,200,200,a))
    nvgText(nvg_,W/2,H*0.78,"点击屏幕开始")
end

function DrawOpening()
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(5,5,8,255)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    local sy=H/2-(#openingLines_*11)
    for i=1,math.min(openLine_,#openingLines_) do
        local line=openingLines_[i] or ""
        local fade=(i==openLine_) and math.min(1,openLineT_/0.4) or 1
        nvgFontSize(nvg_,15); nvgFillColor(nvg_,nvgRGBA(180,180,180,math.floor(fade*200)))
        nvgText(nvg_,W/2,sy+i*24,line)
    end
    nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(60,60,60,130))
    nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_BOTTOM)
    nvgText(nvg_,W/2,H-15,"空格跳过")
end

function DrawBossIntro()
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(8,5,12,255)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    for i=1,math.min(bossIntroLine_,#bossIntroLines_) do
        local line=bossIntroLines_[i] or ""
        local fade=(i==bossIntroLine_) and math.min(1,bossIntroT_/0.3) or 1
        nvgFontSize(nvg_,16)
        if i==#bossIntroLines_ then nvgFillColor(nvg_,nvgRGBA(255,80,50,math.floor(fade*240)))
        else nvgFillColor(nvg_,nvgRGBA(150,200,150,math.floor(fade*200))) end
        nvgText(nvg_,W/2,H/2-60+i*28,line)
    end
end

function DrawGame()
    local cx=cameraNode_.position.x

    -- ================================================================
    -- 第1层: 远景(最暗,最低对比,只提供氛围)
    -- 地下城市轮廓/巨大废弃机器/断裂建筑/坏屏/远处红灯
    -- ================================================================
    -- 基底(深蓝灰,不是纯黑)
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(8,10,18,255)); nvgFill(nvg_)
    -- 空间渐变(顶部紫→中部蓝灰→底部暗青)
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H*0.5)
    nvgFillPaint(nvg_,nvgLinearGradient(nvg_,0,0,0,H*0.5,nvgRGBA(16,12,30,200),nvgRGBA(8,10,18,0)))
    nvgFill(nvg_)
    nvgBeginPath(nvg_); nvgRect(nvg_,0,H*0.7,W,H*0.3)
    nvgFillPaint(nvg_,nvgLinearGradient(nvg_,0,H*0.7,0,H,nvgRGBA(0,0,0,0),nvgRGBA(8,16,20,45)))
    nvgFill(nvg_)
    -- 远景贴图(视差0.12,极暗)
    if envImgs_.bgFar and envImgs_.bgFar~=0 then
        nvgBeginPath(nvg_); nvgRect(nvg_,0,H*0.05,W,H*0.7)
        nvgFillPaint(nvg_,nvgImagePattern(nvg_,-cx*PPU*0.12,H*0.05,600,H*0.65,0,envImgs_.bgFar,0.45))
        nvgFill(nvg_)
    end
    -- 地下城市轮廓(程序化建筑剪影,视差0.1)
    for i=0,9 do
        local bx=(i*130+20)-math.fmod(cx*PPU*0.1,1300)
        local bw=30+i*7; local bh=H*0.2+math.sin(i*2.3)*H*0.12
        local by=H*0.35-bh*0.5+i*5
        if bx>-bw and bx<W+bw then
            nvgBeginPath(nvg_); nvgRect(nvg_,bx,by,bw,bh)
            nvgFillColor(nvg_,nvgRGBA(12,11,22,math.floor(55+i*3))); nvgFill(nvg_)
            -- 建筑窗户(暗点)
            for wi=0,math.floor(bh/20)-1 do
                for wj=0,math.floor(bw/12)-1 do
                    nvgBeginPath(nvg_); nvgRect(nvg_,bx+4+wj*12,by+6+wi*20,5,8)
                    nvgFillColor(nvg_,nvgRGBA(3,2,5,50)); nvgFill(nvg_)
                end
            end
        end
    end
    -- 巨大废弃机器(右侧远处一个巨型圆形轮廓)
    local machX=W*0.8-cx*PPU*0.08
    nvgBeginPath(nvg_); nvgCircle(nvg_,machX,H*0.3,60)
    nvgFillColor(nvg_,nvgRGBA(6,5,10,50)); nvgFill(nvg_)
    nvgStrokeColor(nvg_,nvgRGBA(15,12,22,25)); nvgStrokeWidth(nvg_,2); nvgStroke(nvg_)
    -- 机器内部辐条
    for i=0,5 do
        local angle=i*1.047+blink_*0.05
        nvgBeginPath(nvg_)
        nvgMoveTo(nvg_,machX,H*0.3)
        nvgLineTo(nvg_,machX+math.cos(angle)*55,H*0.3+math.sin(angle)*55)
        nvgStrokeColor(nvg_,nvgRGBA(12,10,18,18)); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
    end
    -- 远处红色小灯(信号灯/警报灯,缓慢闪烁)
    for i=0,5 do
        local lx=(i*180+50)-math.fmod(cx*PPU*0.1,1080)
        local ly=H*0.15+math.sin(i*3.7)*H*0.15
        local la=math.floor(math.sin(blink_*0.8+i*1.2)*25)+45
        if lx>0 and lx<W then
            nvgBeginPath(nvg_); nvgCircle(nvg_,lx,ly,2.5)
            nvgFillColor(nvg_,nvgRGBA(220,50,30,la)); nvgFill(nvg_)
            -- 灯光晕
            nvgBeginPath(nvg_); nvgCircle(nvg_,lx,ly,8)
            nvgFillColor(nvg_,nvgRGBA(180,30,20,math.floor(la*0.4))); nvgFill(nvg_)
        end
    end
    -- 坏掉的屏幕(远景,闪烁蓝光)
    local scrX=W*0.3-cx*PPU*0.08
    local scrFlicker=math.floor(blink_*3)%7==0 and 25 or 12
    nvgBeginPath(nvg_); nvgRoundedRect(nvg_,scrX,H*0.18,40,28,2)
    nvgFillColor(nvg_,nvgRGBA(8,12,20,40)); nvgFill(nvg_)
    nvgBeginPath(nvg_); nvgRoundedRect(nvg_,scrX+3,H*0.18+3,34,22,1)
    nvgFillColor(nvg_,nvgRGBA(20,40,60,scrFlicker)); nvgFill(nvg_)

    -- ================================================================
    -- 第2层: 中景(比远景略亮,但不抢主角)
    -- 管道/吊线/破碎UI/废弃广告牌/旧项目窗口/报错面板
    -- ================================================================
    -- 墙壁纹理(视差0.3)
    if envImgs_.bgWall and envImgs_.bgWall~=0 then
        nvgBeginPath(nvg_); nvgRect(nvg_,0,H*0.06,W,H*0.55)
        nvgFillPaint(nvg_,nvgImagePattern(nvg_,-cx*PPU*0.3,H*0.06,512,256,0,envImgs_.bgWall,0.3))
        nvgFill(nvg_)
    end
    -- 管道系统(竖管+横管+接头,视差0.4)
    for i=0,7 do
        local px=(i*3.2+0.5)*PPU-cx*PPU*0.4
        if px>-60 and px<W+60 then
            -- 竖管
            nvgBeginPath(nvg_); nvgRect(nvg_,px,H*0.01,4,H*0.5)
            nvgFillColor(nvg_,nvgRGBA(18,22,26,55)); nvgFill(nvg_)
            nvgBeginPath(nvg_); nvgRect(nvg_,px+1,H*0.01,1,H*0.5)
            nvgFillColor(nvg_,nvgRGBA(28,36,34,22)); nvgFill(nvg_)
            -- 横管
            local hy=H*0.18+i*12
            nvgBeginPath(nvg_); nvgRect(nvg_,px,hy,PPU*1.6,3)
            nvgFillColor(nvg_,nvgRGBA(15,20,22,50)); nvgFill(nvg_)
        end
    end
    -- 吊线(从顶部垂下的电缆)
    for i=0,4 do
        local wx=(i*220+80)-math.fmod(cx*PPU*0.35,1100)
        if wx>-20 and wx<W+20 then
            local sag=15+math.sin(blink_*0.5+i)*3
            nvgBeginPath(nvg_)
            nvgMoveTo(nvg_,wx,0); nvgBezierTo(nvg_,wx-10,H*0.15,wx+10,H*0.2+sag,wx-5,H*0.35+sag)
            nvgStrokeColor(nvg_,nvgRGBA(20,25,22,40)); nvgStrokeWidth(nvg_,1.5); nvgStroke(nvg_)
        end
    end
    -- 废弃广告牌/旧项目窗口/报错面板(中景debris)
    for _,d in ipairs(roomDebris_) do
        local sx,sy=W2S(d.x,d.y)
        local flicker=math.sin(blink_*1.2+d.x*2.5)*0.3+0.7
        local alpha=math.floor(flicker*32)
        if d.type=="hpbar" then
            -- 废弃血条UI
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx,sy,70,8,2)
            nvgFillColor(nvg_,nvgRGBA(25,8,8,alpha+22)); nvgFill(nvg_)
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx+2,sy+1,28,6,1)
            nvgFillColor(nvg_,nvgRGBA(130,22,22,alpha)); nvgFill(nvg_)
        elseif d.type=="popup" then
            -- 旧项目窗口(关闭按钮+标题栏+内容)
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx,sy,60,34,3)
            nvgFillColor(nvg_,nvgRGBA(10,8,16,alpha+28)); nvgFill(nvg_)
            nvgBeginPath(nvg_); nvgRect(nvg_,sx,sy,60,9)
            nvgFillColor(nvg_,nvgRGBA(50,18,18,alpha+12)); nvgFill(nvg_)
            -- 关闭按钮X
            nvgBeginPath(nvg_)
            nvgMoveTo(nvg_,sx+52,sy+2); nvgLineTo(nvg_,sx+57,sy+7)
            nvgMoveTo(nvg_,sx+57,sy+2); nvgLineTo(nvg_,sx+52,sy+7)
            nvgStrokeColor(nvg_,nvgRGBA(150,60,60,alpha+10)); nvgStrokeWidth(nvg_,0.7); nvgStroke(nvg_)
            nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,5); nvgTextAlign(nvg_,NVG_ALIGN_LEFT|NVG_ALIGN_TOP)
            nvgFillColor(nvg_,nvgRGBA(100,45,45,alpha+5)); nvgText(nvg_,sx+4,sy+13,"err: null ref")
            nvgFillColor(nvg_,nvgRGBA(60,60,80,alpha)); nvgText(nvg_,sx+4,sy+22,"stack overflow")
        elseif d.type=="missing" then
            -- 坏掉的屏幕
            if envImgs_.monitor and envImgs_.monitor~=0 then
                nvgBeginPath(nvg_); nvgRect(nvg_,sx,sy,38,36)
                nvgFillPaint(nvg_,nvgImagePattern(nvg_,sx,sy,38,36,0,envImgs_.monitor,alpha/255))
                nvgFill(nvg_)
            else
                nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx,sy,38,30,2)
                nvgFillColor(nvg_,nvgRGBA(8,12,16,alpha+18)); nvgFill(nvg_)
                nvgStrokeColor(nvg_,nvgRGBA(25,40,35,alpha)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_)
            end
        elseif d.type=="halfui" then
            -- 废弃广告牌(半截UI框架)
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx,sy,52,20,2)
            nvgFillColor(nvg_,nvgRGBA(12,12,20,alpha+22)); nvgFill(nvg_)
            nvgStrokeColor(nvg_,nvgRGBA(35,55,48,alpha-5)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_)
            -- 内容条
            nvgBeginPath(nvg_); nvgRect(nvg_,sx+4,sy+5,20,3)
            nvgFillColor(nvg_,nvgRGBA(45,70,55,alpha)); nvgFill(nvg_)
            nvgBeginPath(nvg_); nvgRect(nvg_,sx+4,sy+11,30,2)
            nvgFillColor(nvg_,nvgRGBA(35,55,45,alpha-5)); nvgFill(nvg_)
        elseif d.type=="todo" then
            -- 代码注释碎片
            nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,7); nvgTextAlign(nvg_,NVG_ALIGN_LEFT|NVG_ALIGN_TOP)
            nvgFillColor(nvg_,nvgRGBA(40,60,30,alpha+5))
            nvgText(nvg_,sx,sy,"// TODO: fix later")
        end
    end
    -- 网格暗线(技术空间纵深)
    for i=0,14 do local gx=(i*PPU*2.4)-(cx*PPU%(PPU*2.4))
        nvgBeginPath(nvg_); nvgMoveTo(nvg_,gx,H*0.08); nvgLineTo(nvg_,gx,H*0.82)
        nvgStrokeColor(nvg_,nvgRGBA(10,16,13,9)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_) end
    for i=0,4 do local gy=H*0.2+i*H*0.14
        nvgBeginPath(nvg_); nvgMoveTo(nvg_,0,gy); nvgLineTo(nvg_,W,gy)
        nvgStrokeColor(nvg_,nvgRGBA(10,15,12,6)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_) end

    -- ================================================================
    -- 第3层: 前景(平台/危险/淤泥/碎片/敌人/互动 - 最清楚)
    -- ================================================================
    -- 平台(厚实工业质感+顶部亮边+下方机械结构)
    for _,p in ipairs(platforms_) do if p.wall then goto cp end
        local sx,sy=W2S(p.x,p.y+p.h)
        local pw,ph=p.w*PPU,p.h*PPU
        local isMain=(p.h>=0.8) -- 主地面vs小平台

        -- ====== 下方机械结构(支架/管线/残缺面板) ======
        local underH=isMain and 40 or 16 -- 主平台下方结构更深
        -- 结构底色(暗铁色)
        nvgBeginPath(nvg_); nvgRect(nvg_,sx,sy+ph,pw,underH)
        nvgFillPaint(nvg_,nvgLinearGradient(nvg_,0,sy+ph,0,sy+ph+underH,nvgRGBA(22,26,28,220),nvgRGBA(8,10,12,200)))
        nvgFill(nvg_)
        if isMain then
            -- 竖向支撑柱(每隔一段)
            local pillarSpacing=PPU*2.5
            for px=sx+pillarSpacing*0.5,sx+pw-10,pillarSpacing do
                nvgBeginPath(nvg_); nvgRect(nvg_,px,sy+ph,6,underH)
                nvgFillColor(nvg_,nvgRGBA(35,40,42,200)); nvgFill(nvg_)
                -- 柱上铆钉
                nvgBeginPath(nvg_); nvgCircle(nvg_,px+3,sy+ph+8,2)
                nvgFillColor(nvg_,nvgRGBA(55,65,60,150)); nvgFill(nvg_)
                nvgBeginPath(nvg_); nvgCircle(nvg_,px+3,sy+ph+underH-8,2)
                nvgFillColor(nvg_,nvgRGBA(55,65,60,150)); nvgFill(nvg_)
            end
            -- 横向管线(2条)
            nvgBeginPath(nvg_); nvgRect(nvg_,sx+8,sy+ph+12,pw-16,3)
            nvgFillColor(nvg_,nvgRGBA(40,55,50,160)); nvgFill(nvg_)
            nvgBeginPath(nvg_); nvgRect(nvg_,sx+8,sy+ph+26,pw-16,2)
            nvgFillColor(nvg_,nvgRGBA(30,42,38,130)); nvgFill(nvg_)
            -- 残缺UI面板(随机位置)
            for pi=0,math.floor(pw/200) do
                local panelX=sx+60+pi*180
                if panelX<sx+pw-40 then
                    nvgBeginPath(nvg_); nvgRoundedRect(nvg_,panelX,sy+ph+6,32,18,2)
                    nvgFillColor(nvg_,nvgRGBA(12,15,20,180)); nvgFill(nvg_)
                    nvgStrokeColor(nvg_,nvgRGBA(40,60,55,80)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_)
                    -- 面板内小亮点(状态灯)
                    nvgBeginPath(nvg_); nvgCircle(nvg_,panelX+6,sy+ph+12,1.5)
                    nvgFillColor(nvg_,nvgRGBA(80,180,80,math.floor(math.sin(blink_*2+pi)*40)+60)); nvgFill(nvg_)
                    nvgBeginPath(nvg_); nvgCircle(nvg_,panelX+12,sy+ph+12,1.5)
                    nvgFillColor(nvg_,nvgRGBA(200,60,40,70)); nvgFill(nvg_)
                end
            end
        end
        -- 下方延伸到屏幕底部(平台不浮空)
        if isMain then
            local belowY=sy+ph+underH
            nvgBeginPath(nvg_); nvgRect(nvg_,sx,belowY,pw,H-belowY+10)
            nvgFillPaint(nvg_,nvgLinearGradient(nvg_,0,belowY,0,belowY+60,nvgRGBA(10,12,16,220),nvgRGBA(4,5,10,240)))
            nvgFill(nvg_)
        end

        -- ====== 平台主体(渐变金属面) ======
        nvgBeginPath(nvg_); nvgRect(nvg_,sx,sy,pw,ph)
        local tileImg=isMain and envImgs_.ground or envImgs_.platform
        if tileImg and tileImg~=0 then
            nvgFillPaint(nvg_,nvgImagePattern(nvg_,sx,sy,256,ph,0,tileImg,1.0))
        else
            nvgFillPaint(nvg_,nvgLinearGradient(nvg_,0,sy,0,sy+ph,nvgRGBA(42,50,58,255),nvgRGBA(22,28,34,255)))
        end
        nvgFill(nvg_)
        -- 表面纹路(水平金属板缝)
        if ph>20 then
            for li=1,math.floor(ph/16) do
                local ly=sy+li*16
                nvgBeginPath(nvg_); nvgMoveTo(nvg_,sx+3,ly); nvgLineTo(nvg_,sx+pw-3,ly)
                nvgStrokeColor(nvg_,nvgRGBA(20,30,26,60)); nvgStrokeWidth(nvg_,0.7); nvgStroke(nvg_)
            end
            -- 竖向分割线(拼接金属板)
            for vi=1,math.floor(pw/90) do
                local vx=sx+vi*90
                nvgBeginPath(nvg_); nvgMoveTo(nvg_,vx,sy+2); nvgLineTo(nvg_,vx,sy+ph-2)
                nvgStrokeColor(nvg_,nvgRGBA(18,28,24,40)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_)
            end
            -- 螺丝/铆钉(板缝交叉处)
            for vi=1,math.floor(pw/90) do
                local rx=sx+vi*90
                for ri=0,math.floor(ph/32) do
                    nvgBeginPath(nvg_); nvgCircle(nvg_,rx,sy+8+ri*32,1.8)
                    nvgFillColor(nvg_,nvgRGBA(55,65,70,80)); nvgFill(nvg_)
                end
            end
            -- 裂痕(随机短斜线)
            if isMain then
                for ci=0,math.floor(pw/160) do
                    local crx=sx+40+ci*160+math.sin(ci*3.7)*20
                    local cry=sy+ph*0.4+math.cos(ci*2.1)*ph*0.2
                    nvgBeginPath(nvg_)
                    nvgMoveTo(nvg_,crx,cry); nvgLineTo(nvg_,crx+8+ci*2,cry+6)
                    nvgMoveTo(nvg_,crx+3,cry-2); nvgLineTo(nvg_,crx+10,cry+3)
                    nvgStrokeColor(nvg_,nvgRGBA(15,20,18,50)); nvgStrokeWidth(nvg_,0.6); nvgStroke(nvg_)
                end
                -- 旧版本编号(金属面上的印刷)
                nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,6)
                nvgTextAlign(nvg_,NVG_ALIGN_LEFT|NVG_ALIGN_TOP)
                nvgFillColor(nvg_,nvgRGBA(45,55,50,45))
                nvgText(nvg_,sx+12,sy+ph-10,"v0.8.7")
                if pw>300 then nvgText(nvg_,sx+pw*0.5,sy+ph-10,"BUILD-001") end
            end
        end

        -- ====== 弱可读断续边缘(故障灯带风格) ======
        local edgeSegs=math.floor(pw/24) -- 每24px一段
        for seg=0,edgeSegs-1 do
            -- 50%概率断开(像坏掉的LED灯带)
            if (seg*7+math.floor(blink_*0.3))%3~=0 then
                local ex=sx+seg*24; local ew=math.min(16,pw-seg*24)
                if ew>2 then
                    local ea=math.floor(35+math.sin(seg*1.7+blink_*0.5)*12) -- 亮度35±12
                    nvgBeginPath(nvg_); nvgRect(nvg_,ex,sy,ew,1.5)
                    nvgFillColor(nvg_,nvgRGBA(80,160,150,ea)); nvgFill(nvg_)
                end
            end
        end
        ::cp:: end
    -- 上层平台悬挂线缆+跳跃路线暗示
    if curRoom_==1 then
        -- 上层平台位置: x=8.5, y=-2+2.2=0.2, w=1.8
        local upX,upY=W2S(8.5,1.0) -- 上层平台底部(GY+2.2)
        local upW=1.8*PPU
        -- 悬挂线缆(平台下方3条)
        for ci=0,2 do
            local cx=upX+upW*0.2+ci*upW*0.3
            local sag=8+ci*4+math.sin(blink_*0.8+ci)*2
            nvgBeginPath(nvg_)
            nvgMoveTo(nvg_,cx,upY); nvgBezierTo(nvg_,cx-3,upY+sag*0.5,cx+3,upY+sag*0.7,cx-1,upY+sag)
            nvgStrokeColor(nvg_,nvgRGBA(40,60,55,80)); nvgStrokeWidth(nvg_,1.2); nvgStroke(nvg_)
        end
        -- 跳跃路线暗示(虚线弧形 从主平台→上层平台)
        local startX,startY=W2S(7.5,-0.15)
        local endX,endY=W2S(9.0,1.4)
        local midX=(startX+endX)/2; local midY=math.min(startY,endY)-40
        local dots=8
        for di=0,dots-1 do
            local t=di/dots
            -- 二次贝塞尔插值
            local dx=(1-t)*(1-t)*startX+2*(1-t)*t*midX+t*t*endX
            local dy=(1-t)*(1-t)*startY+2*(1-t)*t*midY+t*t*endY
            local da=math.floor(math.sin(blink_*2+di*0.5)*15)+30
            nvgBeginPath(nvg_); nvgCircle(nvg_,dx,dy,1.5)
            nvgFillColor(nvg_,nvgRGBA(80,200,210,da)); nvgFill(nvg_)
        end
    end
    -- 场景视觉锚点(每一屏的标志性地标)
    if curRoom_==1 then
        -- ① 出生点锚点: 坏掉的电梯门(x=0.8)
        local ex,ey=W2S(0.8,-0.15)
        local edw,edh=36,70
        -- 电梯门框(暗铁色)
        nvgBeginPath(nvg_); nvgRoundedRect(nvg_,ex-edw/2,ey-edh,edw,edh,2)
        nvgFillColor(nvg_,nvgRGBA(22,25,28,220)); nvgFill(nvg_)
        nvgStrokeColor(nvg_,nvgRGBA(45,55,50,120)); nvgStrokeWidth(nvg_,1.5); nvgStroke(nvg_)
        -- 门缝(中间竖线)
        nvgBeginPath(nvg_); nvgMoveTo(nvg_,ex,ey-edh+6); nvgLineTo(nvg_,ex,ey-4)
        nvgStrokeColor(nvg_,nvgRGBA(8,8,12,200)); nvgStrokeWidth(nvg_,2); nvgStroke(nvg_)
        -- 门上指示灯(暗红=故障)
        nvgBeginPath(nvg_); nvgCircle(nvg_,ex,ey-edh-6,3)
        nvgFillColor(nvg_,nvgRGBA(180,40,30,math.floor(math.sin(blink_*1.5)*30)+60)); nvgFill(nvg_)
        -- BUILD 001 文字
        nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,8)
        nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg_,nvgRGBA(100,110,105,130))
        nvgText(nvg_,ex,ey-edh/2,"BUILD")
        nvgText(nvg_,ex,ey-edh/2+11,"001")


    end
    -- 伤害区(黑紫代码淤泥池+报错裂纹+闪烁文字)
    for _,hz in ipairs(hazards_) do
        local sx,sy=W2S(hz.x,hz.y+hz.h)
        local hw,hh=hz.w*PPU,hz.h*PPU
        local pulse=math.sin(blink_*5)*0.4+0.6
        -- 淤泥底色(深黑紫渐变,比平台明显暗)
        nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx-3,sy-6,hw+6,hh+14,4)
        nvgFillPaint(nvg_,nvgLinearGradient(nvg_,0,sy-6,0,sy+hh+8,nvgRGBA(35,8,45,220),nvgRGBA(20,5,25,240)))
        nvgFill(nvg_)
        -- 蠕动内层(偏移动画)
        local wobX=math.sin(blink_*3)*3
        nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx+wobX,sy-2,hw-4,hh+6,3)
        nvgFillColor(nvg_,nvgRGBA(45,12,55,180)); nvgFill(nvg_)
        -- 红色裂纹(锯齿形,更有代码故障感)
        nvgBeginPath(nvg_)
        for i=0,3 do
            local lx=sx+hw*0.15+i*hw*0.22
            local ly1=sy-3+math.sin(blink_*4+i)*2
            local ly2=sy+hh+3+math.cos(blink_*3+i)*2
            nvgMoveTo(nvg_,lx,ly1); nvgLineTo(nvg_,lx+5,ly1+hh*0.3)
            nvgLineTo(nvg_,lx-2,ly1+hh*0.6); nvgLineTo(nvg_,lx+4,ly2)
        end
        nvgStrokeColor(nvg_,nvgRGBA(220,35,35,math.floor(pulse*160))); nvgStrokeWidth(nvg_,1.2); nvgStroke(nvg_)
        -- 顶部红光警告条
        nvgBeginPath(nvg_); nvgRect(nvg_,sx,sy-6,hw,3)
        nvgFillPaint(nvg_,nvgLinearGradient(nvg_,sx,sy-6,sx+hw,sy-6,
            nvgRGBA(200,40,40,math.floor(pulse*200)),nvgRGBA(180,30,60,math.floor(pulse*140))))
        nvgFill(nvg_)
        -- 浮动报错文字(Null/Missing/Error)
        nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,7); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
        local errTexts={"Null","ERR","0x00","NaN"}
        local ti=math.floor(blink_*2)%4+1
        local ta=math.floor(pulse*100)+30
        nvgFillColor(nvg_,nvgRGBA(200,80,80,ta))
        nvgText(nvg_,sx+hw*0.3,sy+hh*0.4,errTexts[ti])
        nvgFillColor(nvg_,nvgRGBA(160,50,120,ta-20))
        nvgText(nvg_,sx+hw*0.7,sy+hh*0.6,errTexts[(ti%4)+1])
    end
    -- 淤泥(贴图渲染)
    for _,s in ipairs(sludges_) do if s.alive then
        local sx,sy=W2S(s.x-0.6,s.y+0.5)
        local pw=s.blocking and PPU*1.2 or PPU; local ph=s.blocking and PPU*1.5 or PPU*0.8
        local cleanFade=(cleanTarget_==s and cleaning_) and (1-cleanProg_/CLEAR_TIME) or 1
        -- 选择贴图帧
        local img=objImgs_.sludge
        if s.blocking then img=objImgs_.sludgeBlock end
        if cleanTarget_==s and cleaning_ then
            img=(cleanProg_/CLEAR_TIME>0.7) and objImgs_.sludgeBreak or objImgs_.sludgeClean
        end
        -- 蠕动偏移
        local ox=math.sin(blink_*2.5+s.x)*2
        local oy=math.cos(blink_*2+s.x)*1.5
        if img and img~=0 then
            nvgBeginPath(nvg_); nvgRect(nvg_,sx+ox,sy+oy,pw,ph)
            nvgFillPaint(nvg_,nvgImagePattern(nvg_,sx+ox,sy+oy,pw,ph,0,img,cleanFade))
            nvgFill(nvg_)
        end
        -- 清理进度条
        if cleanTarget_==s and cleaning_ then
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx,sy-12,pw,6,2)
            nvgFillColor(nvg_,nvgRGBA(15,25,25,200)); nvgFill(nvg_)
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,sx+1,sy-11,math.max(0,(pw-2)*(cleanProg_/CLEAR_TIME)),4,1)
            if cleanInterrupted_>0 then nvgFillColor(nvg_,nvgRGBA(255,60,60,255))
            else nvgFillColor(nvg_,nvgRGBA(100,230,220,255)) end
            nvgFill(nvg_) end
    end end
    -- 碎片(贴图渲染,悬浮+辉光)
    for _,pk in ipairs(pickups_) do if pk.node then
        local pos=pk.node.position2D; local sx,sy=W2S(pos.x,pos.y)
        local ft=pk.t or 0; local float=math.sin(ft*3)*3
        sy=sy+float
        local glow=math.sin(ft*4)*0.2+0.8
        local sz=28
        -- 外层辉光
        nvgBeginPath(nvg_); nvgCircle(nvg_,sx,sy,sz*0.7)
        nvgFillColor(nvg_,nvgRGBA(60,200,240,math.floor(glow*25))); nvgFill(nvg_)
        -- 贴图
        if objImgs_.fragment and objImgs_.fragment~=0 then
            nvgBeginPath(nvg_); nvgRect(nvg_,sx-sz/2,sy-sz/2,sz,sz)
            nvgFillPaint(nvg_,nvgImagePattern(nvg_,sx-sz/2,sy-sz/2,sz,sz,0,objImgs_.fragment,glow))
            nvgFill(nvg_)
        end
    end end
    -- 可互动物(贴图渲染)
    for _,it in ipairs(interactables_) do if not it.used then
        local sx,sy=W2S(it.x,it.y)
        if it.type=="exit_door" then
            -- NEXT BUILD 门(贴图)
            local dw,dh=50,100; local glow=math.sin(blink_*3)*0.2+0.8
            if objImgs_.door and objImgs_.door~=0 then
                nvgBeginPath(nvg_); nvgRect(nvg_,sx-dw/2,sy-dh,dw,dh)
                nvgFillPaint(nvg_,nvgImagePattern(nvg_,sx-dw/2,sy-dh,dw,dh,0,objImgs_.door,glow))
                nvgFill(nvg_)
            end
            -- 互动提示
            if interactTarget_==it then
                nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,12)
                nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg_,nvgRGBA(130,250,230,240))
                nvgText(nvg_,sx,sy-dh-10,"进入下一个版本")
            end
        else
            -- 冲刺核心(贴图)
            local cFloat=math.sin(blink_*2)*4; local cy2=sy+cFloat
            local cSz=48; local cGlow=math.sin(blink_*3)*0.25+0.75
            if objImgs_.dashCore and objImgs_.dashCore~=0 then
                nvgBeginPath(nvg_); nvgRect(nvg_,sx-cSz/2,cy2-cSz/2,cSz,cSz)
                nvgFillPaint(nvg_,nvgImagePattern(nvg_,sx-cSz/2,cy2-cSz/2,cSz,cSz,0,objImgs_.dashCore,cGlow))
                nvgFill(nvg_)
            end
            -- 互动提示
            if interactTarget_==it then
                nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,12)
                nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_BOTTOM)
                nvgFillColor(nvg_,nvgRGBA(255,230,100,240)); nvgText(nvg_,sx,cy2-32,"[E] 提炼模块")
            end
        end
    end end
    -- 敌人(贴图渲染)
    for _,e in ipairs(enemies_) do if e.alive and e.node then
        local ep=e.node.position2D; local sx,sy=W2S(ep.x,ep.y)
        local fl=e.invT>0 and (math.floor(blink_*20)%2==0)
        if not fl then
            -- 选择帧(按敌人类型)
            local isCaster=(e.type=="semi_caster")
            local img
            if isCaster then
                img=objImgs_.casterIdle
                if e.invT>0 then img=objImgs_.casterHurt
                elseif e.atkState=="windup" or e.atkState=="attack" then img=objImgs_.casterCast end
            else
                img=objImgs_.enemyIdle
                if e.invT>0 then img=objImgs_.enemyHit
                elseif math.abs(e.body.linearVelocity.x)>0.5 then
                    img=(math.floor(blink_*5)%2==0) and objImgs_.enemyWalk1 or objImgs_.enemyWalk2
                end
            end
            local eSz=72 -- 敌人绘制尺寸
            -- 朝向: 近战看移动方向,施法器朝玩家
            local face=isCaster and (e.atkDir or 1) or e.moveDir
            local dir=(face>=0) and 1 or -1
            -- 精灵底部对齐碰撞圆底部(圆心下方PLAYER_R*PPU)
            local footOff=PLAYER_R*PPU -- 碰撞圆底部偏移=41px
            local sprTop=footOff-eSz   -- 精灵顶部Y(相对圆心)
            if img and img~=0 then
                nvgSave(nvg_)
                nvgTranslate(nvg_,sx,sy)
                if dir<0 then nvgScale(nvg_,-1,1) end
                nvgBeginPath(nvg_); nvgRect(nvg_,-eSz/2,sprTop,eSz,eSz)
                if isCaster then
                    -- 占位区分: 紫色 tint(待 e02 专属贴图就位后改回 nvgImagePattern)
                    nvgFillPaint(nvg_,nvgImagePatternTinted(nvg_,-eSz/2,sprTop,eSz,eSz,0,img,nvgRGBA(180,120,240,255)))
                else
                    nvgFillPaint(nvg_,nvgImagePattern(nvg_,-eSz/2,sprTop,eSz,eSz,0,img,1.0))
                end
                nvgFill(nvg_)
                nvgRestore(nvg_)
            end
            -- 施法器开火预警(头顶紫色蓄力环,给玩家躲避反应时间)
            if isCaster and e.atkState=="windup" then
                local prog=1-math.max(0,math.min(1,(e.atkTimer or 0)/Config.CASTER_WINDUP))
                nvgBeginPath(nvg_); nvgCircle(nvg_,sx,sy+sprTop-6,5+prog*5)
                nvgStrokeColor(nvg_,nvgRGBA(200,90,255,120+math.floor(prog*120))); nvgStrokeWidth(nvg_,2); nvgStroke(nvg_)
            end
            if e.type=="ghost" then
                local ga=125+math.floor(math.sin(blink_*4)*30)
                nvgBeginPath(nvg_); nvgCircle(nvg_,sx,sy-7,14); nvgRect(nvg_,sx-14,sy-7,28,12)
                nvgFillColor(nvg_,nvgRGBA(80,30,145,ga)); nvgFill(nvg_)
                nvgBeginPath(nvg_); nvgCircle(nvg_,sx-4,sy-7,3); nvgCircle(nvg_,sx+4,sy-7,3)
                nvgFillColor(nvg_,nvgRGBA(255,255,255,170)); nvgFill(nvg_) end
        end end end
    -- Boss 地面攻击预警
    for _,gw in ipairs(bossGroundWarn_) do
        local gwx,gwy=W2S(gw.x,gw.y)
        local pulse=math.floor(blink_*12)%2==0 and 200 or 120
        if gw.type=="circle" then
            -- 红色故障圈(召唤预警)
            nvgBeginPath(nvg_); nvgCircle(nvg_,gwx,gwy,22)
            nvgStrokeColor(nvg_,nvgRGBA(255,40,40,pulse)); nvgStrokeWidth(nvg_,2); nvgStroke(nvg_)
            nvgBeginPath(nvg_); nvgCircle(nvg_,gwx,gwy,12)
            nvgStrokeColor(nvg_,nvgRGBA(255,80,40,pulse-40)); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
        elseif gw.type=="crack" then
            -- 红色裂纹(淤泥预警)
            nvgBeginPath(nvg_)
            nvgMoveTo(nvg_,gwx-18,gwy); nvgLineTo(nvg_,gwx-5,gwy-6); nvgLineTo(nvg_,gwx+3,gwy+4); nvgLineTo(nvg_,gwx+18,gwy-2)
            nvgMoveTo(nvg_,gwx-8,gwy+3); nvgLineTo(nvg_,gwx+6,gwy+8)
            nvgStrokeColor(nvg_,nvgRGBA(255,60,30,pulse)); nvgStrokeWidth(nvg_,1.5); nvgStroke(nvg_)
        end
    end
    -- Boss「空手感之王」(贴图渲染) [DISABLED in v0.1]
    if Config.ENABLE_BOSS and bossNode_ and bossHP_>0 then
        local bp=bossNode_.position2D; local sx,sy=W2S(bp.x,bp.y)
        -- 故障抖动
        local glitchX=math.sin(blink_*12)*1.5
        local glitchY=math.cos(blink_*9)*0.8
        if bossWarnT_>0 then
            glitchX=glitchX+(math.random()-0.5)*8
            glitchY=glitchY+(math.random()-0.5)*5
        end
        sx=sx+glitchX; sy=sy+glitchY
        local fl=bossInvT_>0 and (math.floor(blink_*20)%2==0)
        if not fl then
            -- 选择Boss帧
            local bImg=(bossWarnT_>0) and objImgs_.bossAtk or objImgs_.bossIdle
            local bSz=140 -- Boss绘制尺寸
            -- 受击染红
            local tintR,tintG,tintB=255,255,255
            if bossInvT_>0 then tintR,tintG,tintB=255,80,80 end
            if bImg and bImg~=0 then
                nvgBeginPath(nvg_); nvgRect(nvg_,sx-bSz/2,sy-bSz*0.8,bSz,bSz)
                nvgFillPaint(nvg_,nvgImagePatternTinted(nvg_,sx-bSz/2,sy-bSz*0.8,bSz,bSz,0,bImg,nvgRGBA(tintR,tintG,tintB,255)))
                nvgFill(nvg_)
            end
            -- 漂浮UI碎片(围绕Boss旋转)
            local orbitR=50
            for ui=0,3 do
                local angle=blink_*0.8+ui*1.57
                local ux=sx+math.cos(angle)*orbitR
                local uy=sy-20+math.sin(angle)*orbitR*0.4
                local ua=120+math.floor(math.sin(blink_*2+ui)*40)
                if ui==0 then -- 血条碎片
                    nvgBeginPath(nvg_); nvgRect(nvg_,ux-12,uy,24,4)
                    nvgFillColor(nvg_,nvgRGBA(180,40,40,ua)); nvgFill(nvg_)
                elseif ui==1 then -- 卡牌
                    nvgBeginPath(nvg_); nvgRect(nvg_,ux-5,uy-7,10,14)
                    nvgFillColor(nvg_,nvgRGBA(60,60,100,ua)); nvgFill(nvg_)
                    nvgStrokeColor(nvg_,nvgRGBA(120,120,180,ua)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_)
                elseif ui==2 then -- 技能图标
                    nvgBeginPath(nvg_); nvgCircle(nvg_,ux,uy,5)
                    nvgFillColor(nvg_,nvgRGBA(80,150,200,ua)); nvgFill(nvg_)
                elseif ui==3 then -- 报错窗
                    nvgBeginPath(nvg_); nvgRect(nvg_,ux-7,uy-4,14,8)
                    nvgFillColor(nvg_,nvgRGBA(100,30,30,ua)); nvgFill(nvg_)
                end
            end
        end end
    -- 弹幕
    local function DP(list, isBlock) for _,p in ipairs(list) do if p.node then
        local pos=p.node.position2D; local sx,sy=W2S(pos.x,pos.y)
        if isBlock then
            -- Boss方块弹幕: 红色报错方块
            nvgBeginPath(nvg_); nvgRect(nvg_,sx-5,sy-5,10,10)
            nvgFillColor(nvg_,nvgRGBA(220,50,40,230)); nvgFill(nvg_)
            nvgStrokeColor(nvg_,nvgRGBA(255,120,80,150)); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
        else
            nvgBeginPath(nvg_); nvgCircle(nvg_,sx,sy,4); nvgFillColor(nvg_,nvgRGBA(255,100,0,210)); nvgFill(nvg_)
        end
    end end end
    DP(projs_, false); DP(bossProjs_, true)
    -- 玩家(帧动画精灵 + 装备附件 + 动作反馈)
    if playerNode_ then
        local pp=playerNode_.position2D; local sx,sy=W2S(pp.x,pp.y)
        local vis=invT_<=0 or (math.floor(blink_*10)%2==0)
        local vel=playerBody_.linearVelocity
        local dir=facingR_ and 1 or -1
        -- 帧选择(含下落区分)
        local img=nil
        local state="idle"
        local frameIdx=1  -- 帧索引(1-based, Lua数组)
        if dashing_ then
            state="dash"; frameIdx=math.floor(blink_*14)%8+1
            img=charImgs_.dash[frameIdx]
        elseif attacking_ then
            state="attack"; frameIdx=math.floor(atkT_/ATK_CD*8)%8+1
            img=charImgs_.attack[9-frameIdx]  -- 攻击从第1帧到最后帧
        elseif cleaning_ then
            state="clean"; frameIdx=math.floor(blink_*6)%8+1
            img=charImgs_.cast[frameIdx]
        elseif not onGround_ then
            state=(vel.y>0) and "jump" or "fall"
            frameIdx=(vel.y>0) and (math.floor(blink_*8)%4+1) or (math.floor(blink_*8)%4+5)
            img=charImgs_.jump[frameIdx]
        elseif math.abs(vel.x)>0.5 then
            state="run"; frameIdx=math.floor(blink_*12)%8+1
            img=charImgs_.run[frameIdx]
        else
            state="idle"; frameIdx=math.floor(blink_*5)%8+1
            img=charImgs_.idle[frameIdx]
        end
        -- 尺寸
        local drawW=120; local drawH=144
        if vis and img and img~=0 then
            -- 冲刺拖影(5帧淡青)
            if state=="dash" then
                for i=1,5 do
                    local tx=sx-dashDir_*i*16; local ta=60-i*11
                    nvgBeginPath(nvg_); nvgRect(nvg_,tx-drawW/2,sy-drawH/2-6,drawW,drawH)
                    nvgFillPaint(nvg_,nvgImagePatternTinted(nvg_,tx-drawW/2,sy-drawH/2-6,drawW,drawH,0,img,nvgRGBA(50,190,220,ta)))
                    nvgFill(nvg_)
                end
            end
            -- ================================================================
            -- 第4层: 玩家主体
            -- ================================================================
            -- 身体摆动(跑步时) + 清理罐晃动
            local sway=0; local canisterSway=0
            if state=="run" then
                sway=math.sin(blink_*10)*1.8
                canisterSway=math.sin(blink_*10+0.5)*2.5
            elseif state=="clean" then
                canisterSway=math.sin(blink_*6)*1.5
            end
            -- ===== 程序化弹性动画(单帧精灵也能"活";以下数值都可调) =====
            local t=blink_
            local bobY=0; local sxS=1; local syS=1; local lean=0
            if state=="idle" then            -- 待机: 上下浮动 + 呼吸(体积守恒)
                bobY=math.sin(t*2.2)*2.0; syS=1+math.sin(t*2.2)*0.03; sxS=1-math.sin(t*2.2)*0.03
            elseif state=="run" then         -- 跑动: 颠簸 + 起伏 + 前倾
                bobY=-math.abs(math.sin(t*12))*4.0; syS=1+math.sin(t*12)*0.05; sxS=1-math.sin(t*12)*0.05; lean=0.06
            elseif state=="jump" then        -- 上升: 纵向拉长
                local s=math.min((vel.y or 0)*0.018,0.20); syS=1+s; sxS=1-s*0.6
            elseif state=="fall" then        -- 下落: 拉长(配合微转)
                local s=math.min((-(vel.y or 0))*0.015,0.18); syS=1+s; sxS=1-s*0.5
            elseif state=="dash" then        -- 冲刺: 横向拉伸
                sxS=1.18; syS=0.86
            elseif state=="clean" then
                bobY=math.sin(t*6)*1.2
            end
            -- 落地压扁(landingT_:0~0.15,瞬间)
            if landingT_>0 then local k=landingT_/0.15; sxS=sxS*(1+k*0.22); syS=syS*(1-k*0.18) end
            -- 攻击放大顿挫(刚出手最强)
            if state=="attack" then
                local p=math.max(0,math.min(1,(atkT_-(ATK_CD-0.12))/0.12)); local punch=p*0.14
                sxS=sxS*(1+punch); syS=syS*(1+punch)
            end
            nvgSave(nvg_)
            nvgTranslate(nvg_,sx,sy+sway*0.3+bobY)
            if not facingR_ then nvgScale(nvg_,-1,1) end
            -- 朝向倾斜: 下落微转 / 跑步前倾
            local rot=(state=="fall") and 0.08 or ((state=="run") and lean or 0)
            if rot~=0 then nvgRotate(nvg_,rot) end
            -- 待机前倾
            if state=="idle" then nvgTranslate(nvg_,2,0) end
            -- 脚底环境光(画在挤压之前,留在地面不缩放)
            nvgBeginPath(nvg_); nvgEllipse(nvg_,0,drawH/2-10,drawW*0.4,8)
            nvgFillColor(nvg_,nvgRGBA(50,180,200,18)); nvgFill(nvg_)
            -- 挤压拉伸以"脚底"为支点(底边不动,头顶伸缩)
            nvgTranslate(nvg_,0,drawH/2); nvgScale(nvg_,sxS,syS); nvgTranslate(nvg_,0,-drawH/2)
            -- 受伤闪色
            local tintR,tintG,tintB,tintA=255,255,255,255
            if invT_>0 then
                local f=math.floor(blink_*12)%3
                if f==0 then tintR,tintG,tintB=255,70,70
                elseif f==1 then tintR,tintG,tintB=255,255,255; tintA=180 end
            end
            -- 精灵渲染(独立帧图片)
            nvgBeginPath(nvg_); nvgRect(nvg_,-drawW/2,-drawH/2,drawW,drawH)
            nvgFillPaint(nvg_,nvgImagePatternTinted(nvg_,-drawW/2,-drawH/2,drawW,drawH,0,img,nvgRGBA(tintR,tintG,tintB,tintA)))
            nvgFill(nvg_)
            -- (装备已包含在精灵图中,不再单独绘制)
            nvgRestore(nvg_)
            -- 清理时:工具接触地面 + 粒子吸附
            if state=="clean" and cleanTarget_ then
                local cx,cy=W2S(cleanTarget_.x,cleanTarget_.y)
                -- 吸附线(从淤泥到角色)
                for li=0,2 do
                    local lx=cx+(math.random()-0.5)*20
                    local ly=cy+(math.random()-0.5)*10
                    nvgBeginPath(nvg_); nvgMoveTo(nvg_,lx,ly); nvgLineTo(nvg_,sx+dir*20,sy+10)
                    nvgStrokeColor(nvg_,nvgRGBA(80,200,210,40+math.random(30))); nvgStrokeWidth(nvg_,0.8); nvgStroke(nvg_)
                end
            end
            -- 攻击弧线
            if state=="attack" then
                local arcProg=1-atkT_/ATK_CD
                local arcA=math.floor((1-arcProg)*240)
                nvgBeginPath(nvg_)
                nvgMoveTo(nvg_,sx+dir*20,sy-28); nvgLineTo(nvg_,sx+dir*50,sy-8)
                nvgLineTo(nvg_,sx+dir*44,sy+14); nvgLineTo(nvg_,sx+dir*16,sy+8)
                nvgStrokeColor(nvg_,nvgRGBA(140,250,200,arcA)); nvgStrokeWidth(nvg_,3); nvgStroke(nvg_)
                nvgBeginPath(nvg_); nvgMoveTo(nvg_,sx+dir*24,sy-24); nvgLineTo(nvg_,sx+dir*48,sy-4)
                nvgStrokeColor(nvg_,nvgRGBA(200,255,220,math.floor(arcA*0.5))); nvgStrokeWidth(nvg_,1.5); nvgStroke(nvg_)
            end
            -- 落地效果
            if landingT_>0 then
                local la=math.floor(landingT_*250)
                nvgBeginPath(nvg_); nvgRect(nvg_,sx-22,sy+drawH/2-6,44,3)
                nvgFillColor(nvg_,nvgRGBA(80,200,210,la)); nvgFill(nvg_)
            end
        end
        -- 清理提示
        if cleanTarget_ and not cleaning_ and not showConfirm_ then
            nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,10); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_BOTTOM)
            nvgFillColor(nvg_,nvgRGBA(180,100,240,170)); nvgText(nvg_,sx,sy-drawH/2-8,"[长按清理]") end
    end
    -- ===== 粒子效果(打击火花/落地尘/清理爆发/冲刺) =====
    for _,p in ipairs(vfx_) do
        local sx,sy=W2S(p.x,p.y)
        local fade=1-p.life/p.maxLife
        local a=math.floor(fade*220)
        local sz=p.size*fade
        nvgBeginPath(nvg_); nvgCircle(nvg_,sx,sy,sz)
        nvgFillColor(nvg_,nvgRGBA(p.r,p.g,p.b,a)); nvgFill(nvg_)
    end
    -- ===== 环境浮游粒子(空气感/漂浮代码碎屑) =====
    for i=0,11 do
        local fx=math.fmod((i*83+blink_*12+cameraNode_.position.x*15),W+80)-40
        local fy=H*0.12+math.sin(blink_*0.4+i*2.1)*H*0.25
        local fa=math.floor(math.sin(blink_*0.6+i*1.3)*10)+16
        local fs=1+math.sin(i*0.7)*0.4
        nvgBeginPath(nvg_); nvgCircle(nvg_,fx,fy,fs)
        nvgFillColor(nvg_,nvgRGBA(80,120,100,fa)); nvgFill(nvg_)
    end
    -- 房间墙文字
    for _,rt in ipairs(roomTexts_) do local sx,sy=W2S(rt.wx,rt.wy)
        nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,rt.size or 13)
        nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg_,nvgRGBA(rt.color[1],rt.color[2],rt.color[3],rt.color[4]))
        nvgText(nvg_,sx,sy,rt.text) end
    -- 浮动文本
    for _,ft in ipairs(floatTexts_) do
        local fade=1; if ft.timer>ft.duration-1 then fade=ft.duration-ft.timer end
        local sx,sy=W2S(ft.x,ft.y); sy=sy-ft.timer*6
        nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,12); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg_,nvgRGBA(ft.color[1],ft.color[2],ft.color[3],math.floor((ft.color[4] or 220)*math.max(0,fade))))
        nvgText(nvg_,sx,sy,ft.text) end
    -- 确认框
    if showConfirm_ then
        nvgBeginPath(nvg_); nvgRect(nvg_,W/2-170,H/2-40,340,80)
        nvgFillColor(nvg_,nvgRGBA(15,15,25,240)); nvgFill(nvg_)
        nvgStrokeColor(nvg_,nvgRGBA(100,200,255,180)); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
        nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
        nvgFontSize(nvg_,13); nvgFillColor(nvg_,nvgRGBA(200,200,200,255))
        nvgText(nvg_,W/2,H/2-15,"检测到可提炼模块。是否提炼？")
        nvgFontSize(nvg_,11); nvgFillColor(nvg_,nvgRGBA(100,200,255,230))
        nvgText(nvg_,W/2,H/2+12,"[E/Enter] 确认     [Esc] 取消")
    end
end

function DrawHUD()
    nvgFontFace(nvg_,"px")

    -- ===== 左上: 生命 + 碎片 =====
    nvgTextAlign(nvg_,NVG_ALIGN_LEFT|NVG_ALIGN_TOP)
    -- HP图标+数字
    nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(180,180,180,160))
    nvgText(nvg_,16,10,"生命值")
    for i=1,MAX_HP do
        local ix=16+(i-1)*22; local iy=24
        nvgBeginPath(nvg_); nvgRoundedRect(nvg_,ix,iy+3,15,13,2); nvgRect(nvg_,ix+4,iy,7,4)
        if i<=hp_ then nvgFillColor(nvg_,nvgRGBA(80,220,200,220))
        else nvgFillColor(nvg_,nvgRGBA(40,40,40,140)) end
        nvgFill(nvg_)
        if i<=hp_ then nvgStrokeColor(nvg_,nvgRGBA(100,240,210,120)); nvgStrokeWidth(nvg_,0.8); nvgStroke(nvg_) end
    end
    -- 碎片数
    nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(150,150,150,150))
    nvgText(nvg_,16,44,"模块碎片")
    nvgFontSize(nvg_,12); nvgFillColor(nvg_,nvgRGBA(80,200,240,200))
    nvgText(nvg_,70,44,tostring(fragments_))

    -- ===== 顶部中间: STAGE + 任务目标 =====
    nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_TOP)
    nvgFontSize(nvg_,11); nvgFillColor(nvg_,nvgRGBA(160,160,160,180))
    nvgText(nvg_,W/2,8,"STAGE-00"..curRoom_)
    nvgFontSize(nvg_,13); nvgFillColor(nvg_,nvgRGBA(180,210,180,200))
    local rname=(roomDefs_[curRoom_] and roomDefs_[curRoom_].name) or ""
    nvgText(nvg_,W/2,22,rname)
    -- 任务目标条
    if gameState_==ST_PLAY then
        nvgBeginPath(nvg_); nvgRoundedRect(nvg_,W/2-180,38,360,20,3)
        nvgFillColor(nvg_,nvgRGBA(8,8,14,160)); nvgFill(nvg_)
        nvgStrokeColor(nvg_,nvgRGBA(60,100,90,60)); nvgStrokeWidth(nvg_,0.5); nvgStroke(nvg_)
        nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(160,200,180,180))
        nvgText(nvg_,W/2,48,"清理代码淤泥，夺取模块碎片，前往 NEXT BUILD 门")
    end



    -- ===== 教程提示(底部中间,参考图位置) =====
    if tutTimer_>0 then
        local fade=math.min(1, tutTimer_/0.5)
        nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
        -- 背景面板
        local tw=280; local th=36
        nvgBeginPath(nvg_); nvgRoundedRect(nvg_,W/2-tw/2,H-th-65,tw,th,4)
        nvgFillColor(nvg_,nvgRGBA(8,8,16,math.floor(fade*200))); nvgFill(nvg_)
        nvgStrokeColor(nvg_,nvgRGBA(80,180,160,math.floor(fade*80))); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
        -- 图标
        nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(240,200,60,math.floor(fade*200)))
        nvgTextAlign(nvg_,NVG_ALIGN_LEFT|NVG_ALIGN_MIDDLE)
        nvgText(nvg_,W/2-tw/2+10,H-th/2-65,"!")
        -- 文字
        nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
        nvgFontSize(nvg_,12); nvgFillColor(nvg_,nvgRGBA(200,240,220,math.floor(fade*230)))
        nvgText(nvg_,W/2+5,H-th/2-65,tutText_)
    end

    -- ===== 清理环形进度(覆盖在清理按钮位置) =====
    if cleaning_ and vClean_ then
        -- 清理环对齐到清理按钮的实际位置(设计坐标 -193,-95,与 CreateControls 一致)
        -- 用 CoordSys 统一换算,避免之前魔法数算错(175≠193)导致环和按钮错位
        local cleanBtnX,cleanBtnY=CoordSys.buttonToScreen(-193,-95,HA_RIGHT,VA_BOTTOM)
        local prog=cleanProg_/CLEAR_TIME
        local ringR=32
        -- 底环(暗)
        nvgBeginPath(nvg_); nvgArc(nvg_,cleanBtnX,cleanBtnY,ringR,-math.pi/2,math.pi*1.5,NVG_CW)
        nvgStrokeColor(nvg_,nvgRGBA(40,20,60,80)); nvgStrokeWidth(nvg_,3); nvgStroke(nvg_)
        -- 进度环(青色)
        if prog>0 then
            nvgBeginPath(nvg_); nvgArc(nvg_,cleanBtnX,cleanBtnY,ringR,-math.pi/2,-math.pi/2+prog*math.pi*2,NVG_CW)
            nvgStrokeColor(nvg_,nvgRGBA(80,230,210,200)); nvgStrokeWidth(nvg_,3.5); nvgStroke(nvg_)
        end
        -- 完成闪光
        if prog>=0.95 then
            nvgBeginPath(nvg_); nvgCircle(nvg_,cleanBtnX,cleanBtnY,ringR+4)
            nvgFillColor(nvg_,nvgRGBA(80,240,220,math.floor(math.sin(blink_*10)*30)+30)); nvgFill(nvg_)
        end
    end

    -- ===== 屏幕闪光 =====
    if screenFlash_>0 then
        nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H)
        nvgFillColor(nvg_,nvgRGBA(150,240,255,math.floor(screenFlash_*100))); nvgFill(nvg_)
    end

    -- ===== Debug碰撞显示 [F1] =====
    if debugDraw_ then
        nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,9)
        nvgTextAlign(nvg_,NVG_ALIGN_LEFT|NVG_ALIGN_TOP)
        nvgFillColor(nvg_,nvgRGBA(0,255,0,200))
        nvgText(nvg_,5,H-20,"DEBUG [F1]")
        -- 平台顶部参考线 y=740
        local platLineY = H * Config.PLATFORM_TOP_DESIGN_Y / 1080
        nvgBeginPath(nvg_); nvgMoveTo(nvg_,0,platLineY); nvgLineTo(nvg_,W,platLineY)
        nvgStrokeColor(nvg_,nvgRGBA(0,200,200,80)); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
        -- 操作区参考线 y=820
        local opLineY = H * Config.OPERATION_ZONE_Y / 1080
        nvgBeginPath(nvg_); nvgMoveTo(nvg_,0,opLineY); nvgLineTo(nvg_,W,opLineY)
        nvgStrokeColor(nvg_,nvgRGBA(200,200,0,80)); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
        -- 玩家碰撞盒(绿色矩形)
        if playerNode_ then
            local pp=playerNode_.position2D; local px,py=W2S(pp.x,pp.y)
            local bw=Config.PLAYER_BOX_W*PPU; local bh=Config.PLAYER_BOX_H*PPU
            nvgBeginPath(nvg_); nvgRect(nvg_,px-bw/2,py-bh,bw,bh)
            nvgStrokeColor(nvg_,nvgRGBA(0,255,0,180)); nvgStrokeWidth(nvg_,1.5); nvgStroke(nvg_)
            -- foot sensor(青色)
            local fw=Config.PLAYER_FOOT_W*PPU; local fh=Config.PLAYER_FOOT_H*PPU
            nvgBeginPath(nvg_); nvgRect(nvg_,px-fw/2,py,fw,fh)
            nvgStrokeColor(nvg_,nvgRGBA(0,200,200,180)); nvgStrokeWidth(nvg_,1); nvgStroke(nvg_)
            -- 攻击盒(黄色,仅攻击时显示)
            if attacking_ then
                local atkW=ATK_RANGE*PPU; local atkH=1.0*PPU
                local atkX=px+atkDir_*atkW/2
                nvgBeginPath(nvg_); nvgRect(nvg_,atkX-atkW/2,py-atkH*0.6,atkW,atkH)
                nvgStrokeColor(nvg_,nvgRGBA(255,255,0,200)); nvgStrokeWidth(nvg_,2); nvgStroke(nvg_)
            end
        end
        -- 敌人碰撞盒(红色矩形) + 攻击盒(橙色)
        for _,e in ipairs(enemies_) do if e.alive and e.node then
            local ep=e.node.position2D; local ex,ey=W2S(ep.x,ep.y)
            local ew=Config.ENEMY_WIDTH*PPU; local eh=Config.ENEMY_HEIGHT*PPU
            nvgBeginPath(nvg_); nvgRect(nvg_,ex-ew/2,ey-eh,ew,eh)
            nvgStrokeColor(nvg_,nvgRGBA(255,60,60,180)); nvgStrokeWidth(nvg_,1.5); nvgStroke(nvg_)
            -- 敌人攻击盒(前摇/攻击时显示)
            if e.atkState=="windup" or e.atkState=="attack" then
                local aDir=e.atkDir; local aRange=Config.ENEMY_ATK_HITBOX*PPU
                local ax=ex+aDir*aRange/2
                nvgBeginPath(nvg_); nvgRect(nvg_,ax-aRange/2,ey-eh*0.7,aRange,eh*0.6)
                local aCol=(e.atkState=="attack") and nvgRGBA(255,100,0,200) or nvgRGBA(255,50,50,120)
                nvgStrokeColor(nvg_,aCol); nvgStrokeWidth(nvg_,1.5); nvgStroke(nvg_)
            end
        end end
    end

    -- ===== 按钮矢量图标(NanoVG手绘,对齐VirtualControls坐标) =====
    if gameState_==ST_PLAY or gameState_==ST_BOSS then
        -- 复制VirtualControls短边缩放逻辑
        local vcScale=math.min(W,H)/1080
        local vcOffX=(W-1920*vcScale)/2
        local vcOffY=(H-1080*vcScale)/2
        local function BtnScr(posX,posY,aH,aV)
            local dx,dy=posX,posY
            local sR=(W-vcOffX)/vcScale; local sB=(H-vcOffY)/vcScale
            local sL=-vcOffX/vcScale; local sT=-vcOffY/vcScale
            if aH==HA_RIGHT then dx=sR+posX elseif aH==HA_LEFT then dx=sL+posX else dx=960+posX end
            if aV==VA_BOTTOM then dy=sB+posY elseif aV==VA_TOP then dy=sT+posY else dy=540+posY end
            return dx*vcScale+vcOffX, dy*vcScale+vcOffY
        end
        local gap=138; local btnY=-95
        local s=vcScale
        -- 是否按下(优先持续按住,退化到边沿)
        local function press(v) return v and (v.isTouchPressed or v.isPressed) end
        -- 玻璃按钮本体: 暗玻璃底 + 强调色外环 + 顶部高光 + 按下发光
        local function glassBody(cx,cy,r,acc,pressed,dim)
            local ar,ag,ab=acc[1],acc[2],acc[3]; local baseA=dim and 100 or 160
            if pressed then
                nvgBeginPath(nvg_); nvgCircle(nvg_,cx,cy,r+7*s)
                nvgFillColor(nvg_,nvgRGBA(ar,ag,ab,55)); nvgFill(nvg_)
            end
            nvgBeginPath(nvg_); nvgCircle(nvg_,cx,cy,r)
            nvgFillPaint(nvg_,nvgLinearGradient(nvg_,cx,cy-r,cx,cy+r,nvgRGBA(36,42,54,pressed and 225 or baseA+45),nvgRGBA(10,13,20,pressed and 235 or baseA+20)))
            nvgFill(nvg_)
            nvgBeginPath(nvg_); nvgCircle(nvg_,cx,cy,r)
            nvgStrokeColor(nvg_,nvgRGBA(ar,ag,ab,dim and 70 or (pressed and 245 or 145)))
            nvgStrokeWidth(nvg_,(pressed and 2.6 or 1.6)*s); nvgStroke(nvg_)
            nvgBeginPath(nvg_); nvgArc(nvg_,cx,cy,r-2.5*s,math.pi*1.18,math.pi*1.82,NVG_CW)
            nvgStrokeColor(nvg_,nvgRGBA(255,255,255,pressed and 70 or 26)); nvgStrokeWidth(nvg_,1.3*s); nvgStroke(nvg_)
        end
        local function glyphTxt(cx,cy,r,acc,txt,pressed,dim)
            nvgFontFace(nvg_,"px"); nvgFontSize(nvg_,r*0.95); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg_,nvgRGBA(acc[1],acc[2],acc[3],dim and 120 or (pressed and 255 or 225)))
            nvgText(nvg_,cx,cy,txt)
        end

        -- 摇杆: 底盘 + 跟手的摇杆头
        local jcx,jcy=BtnScr(180,-160,HA_LEFT,VA_BOTTOM)
        local jr=120*s; local kr=46*s
        nvgBeginPath(nvg_); nvgCircle(nvg_,jcx,jcy,jr)
        nvgFillColor(nvg_,nvgRGBA(18,24,32,70)); nvgFill(nvg_)
        nvgStrokeColor(nvg_,nvgRGBA(80,200,220,50)); nvgStrokeWidth(nvg_,1.4*s); nvgStroke(nvg_)
        local jax=(vJoy_ and vJoy_.x or 0)
        local kx=jcx+jax*(jr-kr); local jact=vJoy_ and (vJoy_.isTouchPressed or math.abs(jax)>0.06)
        nvgBeginPath(nvg_); nvgCircle(nvg_,kx,jcy,kr)
        nvgFillPaint(nvg_,nvgLinearGradient(nvg_,kx,jcy-kr,kx,jcy+kr,nvgRGBA(42,52,64,205),nvgRGBA(14,18,26,215))); nvgFill(nvg_)
        nvgStrokeColor(nvg_,nvgRGBA(90,210,225,jact and 230 or 110)); nvgStrokeWidth(nvg_,1.8*s); nvgStroke(nvg_)

        -- 攻击 / 跳 / 清 / 冲
        local cx,cy=BtnScr(-gap*3-55,btnY,HA_RIGHT,VA_BOTTOM)
        glassBody(cx,cy,60*s,{255,110,70},press(vAtk_)); glyphTxt(cx,cy,60*s,{255,150,110},"击",press(vAtk_))
        cx,cy=BtnScr(-gap*2-55,btnY,HA_RIGHT,VA_BOTTOM)
        glassBody(cx,cy,68*s,{90,200,255},press(vJump_)); glyphTxt(cx,cy,68*s,{150,220,255},"跳",press(vJump_))
        cx,cy=BtnScr(-gap*1-55,btnY,HA_RIGHT,VA_BOTTOM)
        glassBody(cx,cy,58*s,{180,110,245},press(vClean_)); glyphTxt(cx,cy,58*s,{210,160,250},"清",press(vClean_))
        cx,cy=BtnScr(-55,btnY,HA_RIGHT,VA_BOTTOM)
        local dDim=not hasDash_
        glassBody(cx,cy,58*s,{90,225,235},press(vDash_),dDim)
        if hasDash_ and dashCD_>0 and DASH_CD>0 then  -- 冷却暗弧(顺时针扫光)
            local p=math.min(1,dashCD_/DASH_CD)
            nvgBeginPath(nvg_); nvgArc(nvg_,cx,cy,58*s*0.7,-math.pi/2,-math.pi/2+p*math.pi*2,NVG_CW)
            nvgStrokeColor(nvg_,nvgRGBA(8,11,16,150)); nvgStrokeWidth(nvg_,58*s*0.62); nvgStroke(nvg_)
        end
        glyphTxt(cx,cy,58*s,{150,235,240},"冲",press(vDash_),dDim)

        -- 互动E: 有目标时高亮,无目标时变暗
        cx,cy=BtnScr(-gap*3-55,btnY-130,HA_RIGHT,VA_BOTTOM)
        local iDim=not (interactTarget_ or showConfirm_)
        glassBody(cx,cy,42*s,{235,215,90},press(vInteract_),iDim); glyphTxt(cx,cy,42*s,{245,225,120},"E",press(vInteract_),iDim)

        -- 暂停(双竖条) / 档案(三横线)
        cx,cy=BtnScr(-40,40,HA_RIGHT,VA_TOP)
        glassBody(cx,cy,26*s,{170,170,185},press(vPause_))
        nvgBeginPath(nvg_); nvgRect(nvg_,cx-5*s,cy-7*s,3.2*s,14*s); nvgRect(nvg_,cx+1.8*s,cy-7*s,3.2*s,14*s)
        nvgFillColor(nvg_,nvgRGBA(205,210,220,press(vPause_) and 255 or 205)); nvgFill(nvg_)
        cx,cy=BtnScr(-100,40,HA_RIGHT,VA_TOP)
        glassBody(cx,cy,26*s,{170,170,185},press(vArchive_))
        for li=-1,1 do
            nvgBeginPath(nvg_); nvgRect(nvg_,cx-7*s,cy+li*5*s-1*s,14*s,2.2*s)
            nvgFillColor(nvg_,nvgRGBA(205,210,220,press(vArchive_) and 255 or 205)); nvgFill(nvg_)
        end
    end
end

function DrawPause()
    -- 毛玻璃遮罩
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H)
    nvgFillColor(nvg_,nvgRGBA(4,6,12,210)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    -- 面板背景(居中圆角卡片)
    local pw,ph=280,220; local px,py=W/2-pw/2,H/2-ph/2
    nvgBeginPath(nvg_); nvgRoundedRect(nvg_,px,py,pw,ph,12)
    nvgFillColor(nvg_,nvgRGBA(15,18,28,240)); nvgFill(nvg_)
    -- 面板顶部渐变条
    nvgBeginPath(nvg_); nvgRoundedRect(nvg_,px,py,pw,4,2)
    nvgFillPaint(nvg_,nvgLinearGradient(nvg_,px,py,px+pw,py,nvgRGBA(80,200,220,200),nvgRGBA(160,80,220,200)))
    nvgFill(nvg_)
    -- 标题
    nvgFontSize(nvg_,20); nvgFillColor(nvg_,nvgRGBA(220,230,240,255))
    nvgText(nvg_,W/2,py+32,"已暂停")
    -- 菜单项
    local items={"继续游戏","设置","重新开始"}
    local menuY=py+70
    for i,item in ipairs(items) do
        local iy=menuY+(i-1)*42
        local hovered=(math.floor(blink_*1.5)%3==i-1) -- 简单闪烁提示
        nvgFontSize(nvg_,15)
        if i==1 then nvgFillColor(nvg_,nvgRGBA(100,220,200,240))
        elseif i==2 then nvgFillColor(nvg_,nvgRGBA(180,180,200,220))
        else nvgFillColor(nvg_,nvgRGBA(200,100,100,200)) end
        nvgText(nvg_,W/2,iy,item)
    end
    -- 操作提示
    nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(90,100,110,160))
    nvgText(nvg_,W/2,py+ph-18,"[Esc/||] 继续  |  [S] 设置  |  [R] 重开")
end

function DrawSettings()
    -- 遮罩
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H)
    nvgFillColor(nvg_,nvgRGBA(4,6,12,220)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    -- 设置面板
    local pw,ph=320,260; local px,py=W/2-pw/2,H/2-ph/2
    nvgBeginPath(nvg_); nvgRoundedRect(nvg_,px,py,pw,ph,12)
    nvgFillColor(nvg_,nvgRGBA(15,18,28,240)); nvgFill(nvg_)
    -- 顶部渐变条
    nvgBeginPath(nvg_); nvgRoundedRect(nvg_,px,py,pw,4,2)
    nvgFillPaint(nvg_,nvgLinearGradient(nvg_,px,py,px+pw,py,nvgRGBA(220,160,50,200),nvgRGBA(220,80,80,200)))
    nvgFill(nvg_)
    -- 标题
    nvgFontSize(nvg_,18); nvgFillColor(nvg_,nvgRGBA(220,220,230,255))
    nvgText(nvg_,W/2,py+30,"设置")
    -- 设置项列表
    local labels={"音乐音量","音效音量","振动反馈","按钮大小","按钮透明度"}
    local startY=py+65
    for i,key in ipairs(SETTING_ITEMS) do
        local iy=startY+(i-1)*38
        local selected=(i==settingSel_)
        -- 高亮条
        if selected then
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,px+12,iy-13,pw-24,28,6)
            nvgFillColor(nvg_,nvgRGBA(40,60,80,150)); nvgFill(nvg_)
        end
        -- 标签
        nvgTextAlign(nvg_,NVG_ALIGN_LEFT|NVG_ALIGN_MIDDLE)
        nvgFontSize(nvg_,12)
        nvgFillColor(nvg_,selected and nvgRGBA(100,220,210,255) or nvgRGBA(160,160,170,200))
        nvgText(nvg_,px+24,iy,labels[i])
        -- 值
        nvgTextAlign(nvg_,NVG_ALIGN_RIGHT|NVG_ALIGN_MIDDLE)
        if key=="vibration" then
            local txt=settings_.vibration and "开启" or "关闭"
            nvgFillColor(nvg_,settings_.vibration and nvgRGBA(80,220,120,240) or nvgRGBA(180,80,80,220))
            nvgText(nvg_,px+pw-24,iy,txt)
        else
            local val=settings_[key]
            -- 进度条
            local barW=80; local barX=px+pw-24-barW; local barY=iy-4
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,barX,barY,barW,8,3)
            nvgFillColor(nvg_,nvgRGBA(25,30,40,200)); nvgFill(nvg_)
            -- 归一化(btnScale 0.8~1.4 → 0~1)
            local norm=val
            if key=="btnScale" then norm=(val-0.8)/0.6
            elseif key=="btnOpacity" then norm=(val-0.3)/0.6 end
            nvgBeginPath(nvg_); nvgRoundedRect(nvg_,barX,barY,barW*norm,8,3)
            local barColor=selected and nvgRGBA(80,200,210,230) or nvgRGBA(60,140,150,180)
            nvgFillColor(nvg_,barColor); nvgFill(nvg_)
            -- 百分比文字
            nvgFillColor(nvg_,nvgRGBA(200,200,210,200)); nvgFontSize(nvg_,10)
            nvgText(nvg_,px+pw-24,iy,string.format("%d%%",math.floor(norm*100)))
        end
    end
    -- 底部提示
    nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(90,100,110,150))
    nvgText(nvg_,W/2,py+ph-16,"↑↓ 选择  |  ←→ 调节  |  [Esc/||] 返回")
end

function DrawDeath()
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(0,0,0,180)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    nvgFontSize(nvg_,22); nvgFillColor(nvg_,nvgRGBA(200,50,50,255))
    nvgText(nvg_,W/2,H/2-20,"运行失败。")
    nvgFontSize(nvg_,14); nvgFillColor(nvg_,nvgRGBA(140,140,140,200))
    nvgText(nvg_,W/2,H/2+10,"正在载入上一个版本……")
    if deathT_>1.5 then local a=math.floor(math.abs(math.sin(blink_*2))*200)
        nvgFontSize(nvg_,14); nvgFillColor(nvg_,nvgRGBA(255,255,255,a))
        nvgText(nvg_,W/2,H/2+45,"[ ENTER ]") end
end

function DrawEnding()
    -- 黑底
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(5,5,8,255)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)

    if endPhase_==0 then
        -- Phase0: 纯黑屏(2秒静默)
    elseif endPhase_==1 then
        -- Phase1: 项目信息
        nvgFontSize(nvg_,14); nvgFillColor(nvg_,nvgRGBA(150,150,150,200))
        nvgText(nvg_,W/2,H/2-30,"项目名：HollowLike_Final_v7")
        nvgText(nvg_,W/2,H/2-5,"创建者：你")
        nvgFillColor(nvg_,nvgRGBA(200,80,80,220))
        nvgText(nvg_,W/2,H/2+20,"状态：已放弃")
    elseif endPhase_==2 then
        -- Phase2: 归档文本
        local lines={"失真档案 001 已归档。","","异常类型：未理解的原型。","处理结果：仍在运行。"}
        for i=1,math.min(endLine_,#lines) do
            local line=lines[i] or ""
            local fade=(i==endLine_) and math.min(1,endLineT_/0.5) or 1
            nvgFontSize(nvg_,15); nvgFillColor(nvg_,nvgRGBA(180,180,180,math.floor(fade*220)))
            nvgText(nvg_,W/2,H/2-40+i*28,line)
        end
    end

    -- 跳过提示(phase1以后才显示)
    if endPhase_>=1 then
        nvgFontSize(nvg_,9); nvgFillColor(nvg_,nvgRGBA(50,50,50,120))
        nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_BOTTOM)
        nvgText(nvg_,W/2,H-12,"点击继续")
    end
end

function DrawMenu()
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(8,6,12,255)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    -- 统计
    nvgFontSize(nvg_,12); nvgFillColor(nvg_,nvgRGBA(100,200,255,180))
    nvgText(nvg_,W/2,H/2-60,"模块碎片: "..fragments_)
    local pct=totalSludge_>0 and math.floor(sludgeCleared_/totalSludge_*100) or 0
    nvgFillColor(nvg_,nvgRGBA(200,100,255,180))
    nvgText(nvg_,W/2,H/2-40,"清理完成率: "..pct.."%")
    -- 按钮
    local a=math.floor(math.abs(math.sin(blink_*2))*80)+175
    nvgFontSize(nvg_,17); nvgFillColor(nvg_,nvgRGBA(255,255,255,a))
    nvgText(nvg_,W/2,H/2+5,"[1] 重新开始")
    nvgFontSize(nvg_,14); nvgFillColor(nvg_,nvgRGBA(150,200,200,200))
    nvgText(nvg_,W/2,H/2+40,"[2] 查看档案")
    nvgFontSize(nvg_,12); nvgFillColor(nvg_,nvgRGBA(80,80,80,150))
    nvgText(nvg_,W/2,H/2+70,"[退出] 关闭窗口")
end

function DrawArchive()
    nvgBeginPath(nvg_); nvgRect(nvg_,0,0,W,H); nvgFillColor(nvg_,nvgRGBA(8,6,12,255)); nvgFill(nvg_)
    nvgFontFace(nvg_,"px"); nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_MIDDLE)
    nvgFontSize(nvg_,18); nvgFillColor(nvg_,nvgRGBA(200,50,50,240))
    nvgText(nvg_,W/2,H/2-70,"失真档案 001：残机城")
    nvgFontSize(nvg_,13); nvgFillColor(nvg_,nvgRGBA(170,170,170,200))
    nvgText(nvg_,W/2,H/2-25,"这里收容的是被快速生成、快速兴奋、快速放弃的游戏原型。")
    nvgText(nvg_,W/2,H/2+5,"它们没有真正完成。")
    nvgText(nvg_,W/2,H/2+35,"但它们仍在地下运行。")
    nvgFontSize(nvg_,10); nvgFillColor(nvg_,nvgRGBA(80,80,80,140))
    nvgTextAlign(nvg_,NVG_ALIGN_CENTER|NVG_ALIGN_BOTTOM)
    nvgText(nvg_,W/2,H-20,"点击任意按钮返回")
end
