-- data/Level_001A.lua: 浅层街区关卡数据
local Config = require("config")

local Level = {}

Level.name = "浅层街区"
Level.roomWidth = 12

local GY = Config.GY
local PH = Config.PH
local PLAYER_R = Config.PLAYER_R

Level.platforms = {
    {x=0, y=GY, w=12, h=PH},
    {x=8.5, y=GY+2.2, w=1.8, h=0.4},
}

Level.enemies = {
    {type="semi_executor", x=5.5, y=GY+PH, hp=2},  -- 战斗区中间(屏幕~46%)
    {type="semi_executor", x=7.8, y=GY+PH, hp=2},  -- 战斗区右侧(屏幕~65%)
}

Level.sludges = {
    {x=5.2, y=GY+0.6, blocking=true},
}

Level.interactables = {
    {x=4, y=GY+PH+1.5, type="dash_core"},   -- 跳跃教学区上方
    {x=10.5, y=GY+PH, type="exit_door"},     -- 右侧终点区(屏幕~87%)
}

Level.hazards = {
    {x=7, y=GY+0.5, w=1.2, h=0.3, type="damage"},
}

Level.hasExit = true

Level.killText = {"模块残留：","攻击动画已生成。","命中反馈缺失。"}
Level.clearText = {"TODO：","以后再优化手感。"}

Level.wallTexts = {
    {text="警告：请勿运行废弃原型。", wx=1, wy=1.5, color={150,150,150,110}, size=8},
    {text="攻击系统：可运行。", wx=3.5, wy=2, color={80,120,80,100}, size=8},
    {text="TODO：以后再优化。", wx=5.5, wy=1.8, color={100,80,120,100}, size=8},
    {text="冲刺功能已接入。", wx=7.5, wy=1.8, color={80,150,150,100}, size=8},
    {text="NEXT BUILD →", wx=11, wy=2.5, color={80,200,180,140}, size=10},
}

Level.debris = {
    {type="hpbar",x=0.8,y=2.5}, {type="popup",x=4,y=2.5},
    {type="missing",x=6.5,y=2.5}, {type="halfui",x=9.5,y=2.8},
    {type="todo",x=2.5,y=3}, {type="hpbar",x=8,y=3.2},
}

return Level
