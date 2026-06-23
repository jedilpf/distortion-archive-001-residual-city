-- entities/EnemyFactory.lua: 敌人创建工厂
local Config = require("config")

local EnemyFactory = {}

function EnemyFactory.create(scene, enemyData)
    local n = scene:CreateChild("Enemy")
    n:SetPosition2D(enemyData.x, enemyData.y)
    local b = n:CreateComponent("RigidBody2D")
    b.bodyType = BT_DYNAMIC
    b.fixedRotation = true
    b.gravityScale = (enemyData.type == "moth") and 0 or 1
    local sh = n:CreateComponent("CollisionCircle2D")
    sh.radius = Config.PLAYER_R
    sh.density = 1
    sh.friction = 0.2
    sh.categoryBits = Config.CAT_ENEMY
    sh.maskBits = Config.CAT_GROUND | Config.CAT_PLAYER
    return {
        type = enemyData.type,
        node = n,
        body = b,
        hp = enemyData.hp or 3,
        alive = true,
        invT = 0,
        moveDir = 1,
        moveT = 0,
        shootT = 0,
        baseX = enemyData.x,
        baseY = enemyData.y,
        floatT = 0,
    }
end

return EnemyFactory
