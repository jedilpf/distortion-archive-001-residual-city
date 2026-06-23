-- config.lua: 游戏全局配置
local Config = {}

-- 版本
Config.VERSION = "0.1.3"

-- 显示(运行时由Start()填入实际值)
Config.W = 1
Config.H = 1
Config.DPR = 1

-- 核心参数
Config.PPU = 108
Config.GRAVITY = 30.0
Config.MOVE_SPEED = 6.2
Config.JUMP_SPEED = 13.0
Config.PLAYER_R = 0.38
Config.DASH_SPEED = 16.0
Config.DASH_DUR = 0.18
Config.DASH_CD = 0.8
Config.ATK_RANGE = 1.3
Config.ATK_DMG = 1
Config.ATK_CD = 0.22
Config.KNOCKBACK = 7.0
Config.MAX_HP = 3
Config.INV_TIME = 1.0
Config.CLEAR_TIME = 1.8
Config.COYOTE_TIME = 0.15
Config.HITSTOP_DUR = 0.07
Config.ROOM_W = 12
Config.TOTAL_ROOMS = 1

-- 物理层
Config.CAT_GROUND = 1
Config.CAT_PLAYER = 2
Config.CAT_SENSOR = 4
Config.CAT_ENEMY = 8

-- 游戏状态枚举
Config.ST_TITLE = 1
Config.ST_OPENING = 2
Config.ST_PLAY = 3
Config.ST_DEAD = 4
Config.ST_BOSS = 5
Config.ST_BOSS_INTRO = 6
Config.ST_ENDING = 7
Config.ST_MENU = 8
Config.ST_ARCHIVE = 9
Config.ST_PAUSE = 10
Config.ST_SETTINGS = 11

-- Boss开关(v0.1禁用,v1.0启用)
Config.ENABLE_BOSS = false

-- 关卡设计参数
Config.GY = -1.2          -- 主地面Y
Config.PH = 1.0           -- 平台厚度
Config.PLATFORM_TOP_DESIGN_Y = 740  -- 设计坐标中平台顶部位置
Config.OPERATION_ZONE_Y = 820       -- 底部操作区起始

-- 设置默认值
Config.DEFAULT_SETTINGS = {
    musicVol = 0.7,
    sfxVol = 1.0,
    vibration = true,
    btnScale = 1.0,
    btnOpacity = 0.55,
}

return Config
