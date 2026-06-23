-- systems/CombatSystem.lua: 战斗判定系统
local Config = require("config")

local CombatSystem = {}

--- 执行主角近战攻击判定
---@param playerPos Vector2 玩家位置
---@param atkDir number 攻击方向(1=右,-1=左)
---@param enemies table 敌人列表
---@param callbacks table {onHit=fn, onKill=fn}
function CombatSystem.performAttack(playerPos, atkDir, enemies, callbacks)
    for _, e in ipairs(enemies) do
        if e.alive and e.node and e.invT <= 0 then
            local ep = e.node.position2D
            local dx = ep.x - playerPos.x
            local dy = math.abs(ep.y - playerPos.y)
            -- 水平方向判定: 面向方向ATK_RANGE内
            -- 垂直判定: 高度差1.0以内(站地打站地)
            if dx * atkDir > 0 and math.abs(dx) < Config.ATK_RANGE and dy < 1.0 then
                e.hp = e.hp - Config.ATK_DMG
                e.invT = 0.2
                -- 击退
                if e.body then
                    e.body.linearVelocity = Vector2(atkDir * Config.KNOCKBACK, 3)
                end
                if callbacks.onHit then callbacks.onHit(e) end
                if e.hp <= 0 then
                    e.alive = false
                    if e.node then e.node:Remove() end
                    if callbacks.onKill then callbacks.onKill(e) end
                end
            end
        end
    end
end

--- 敌人接触伤害检测
---@param playerPos Vector2 玩家位置
---@param enemies table 敌人列表
---@param contactRadius number 接触伤害半径
---@return boolean hit 是否被命中
function CombatSystem.checkEnemyContact(playerPos, enemies, contactRadius)
    for _, e in ipairs(enemies) do
        if e.alive and e.node then
            local ep = e.node.position2D
            local dist = math.sqrt((ep.x-playerPos.x)^2 + (ep.y-playerPos.y)^2)
            if dist < contactRadius then
                return true, e
            end
        end
    end
    return false, nil
end

return CombatSystem
