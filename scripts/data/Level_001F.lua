-- data/Level_001F.lua: 旧项目(R-06,终点/Boss房)
-- isBoss=true: 当 Config.ENABLE_BOSS 开启时触发 Boss 战;
-- 关闭时(当前默认)作为结局前的演出走廊,走到出口即进入结局。
local Config = require("config")

local Level = {}

local GY = Config.GY
local PH = Config.PH

Level.name = "旧项目"
Level.roomWidth = 12
Level.isBoss = true

Level.platforms = {
    {x=0, y=GY, w=12, h=PH},
    {x=8.5, y=GY+2.2, w=1.8, h=0.4},
}

Level.enemies = {}
Level.sludges = {}
Level.hazards = {}

Level.interactables = {
    {x=10.6, y=GY+PH, type="exit_door"},
}

Level.hasExit = true

Level.wallTexts = {
    {text="这是那个仍在运行的旧项目。", wx=2, wy=2.4, color={120,160,160,140}, size=11},
    {text="它什么都有。", wx=5, wy=2.0, color={100,100,120,120}, size=9},
    {text="只是不好玩。", wx=7.5, wy=2.0, color={150,90,90,130}, size=9},
}

Level.debris = {
    {type="halfui",x=4,y=3.0}, {type="popup",x=9,y=3.0},
}

return Level
