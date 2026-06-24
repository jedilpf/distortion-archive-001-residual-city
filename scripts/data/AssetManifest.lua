-- data/AssetManifest.lua: 资源路径清单
local Assets = {}

Assets.char = {
    -- v0.1.3B 稳定版：暂时冻结复杂8帧动画。
    -- 说明：当前任务是修碰撞/脚底原点，不是扩展动画系统。
    -- 为避免自动裁切帧、脚底锚点不一致、blink_全局取帧导致的乱跳，
    -- 这里保持数组结构兼容 main.lua，但每个动作8帧先指向同一张稳定单帧。
    idle = {}, run = {}, walk = {}, attack = {},
    dash = {}, jump = {}, cast = {}, hit = {},
    knockdown = {}, skillSlash = {},
}

local stableFrames = {
    idle = "image/char_idle1_20260621184424.png",
    run = "image/char_run1_20260621184411.png",
    walk = "image/char_run1_20260621184411.png",
    attack = "image/char_attack_20260621184410.png",
    dash = "image/char_dash_20260621184409.png",
    jump = "image/char_jump_20260621184416.png",
    cast = "image/char_clean_20260621184409.png",
    hit = "image/char_idle1_20260621184424.png",
    knockdown = "image/char_idle1_20260621184424.png",
    skillSlash = "image/char_attack_20260621184410.png",
}

for i=1,8 do
    Assets.char.idle[i] = stableFrames.idle
    Assets.char.run[i] = stableFrames.run
    Assets.char.walk[i] = stableFrames.walk
    Assets.char.attack[i] = stableFrames.attack
    Assets.char.dash[i] = stableFrames.dash
    Assets.char.jump[i] = stableFrames.jump
    Assets.char.cast[i] = stableFrames.cast
    Assets.char.hit[i] = stableFrames.hit
    Assets.char.knockdown[i] = stableFrames.knockdown
    Assets.char.skillSlash[i] = stableFrames.skillSlash
end

Assets.enemy = {
    idle = "image/e01_idle_20260623015723.png",
    walk1 = "image/e01_walk1_20260623015810.png",
    walk2 = "image/e01_walk2_20260623015919.png",
    hurt = "image/e01_hurt_20260623015801.png",
}

Assets.objects = {
    sludge = "image/obj_sludge_20260622060959.png",
    door = "image/obj_nextdoor_20260623020120.png",
    fragment = "image/obj_frag_20260622061034.png",
    dashCore = "image/obj_dashcore_20260622061006.png",
    platUpper = "image/platform_upper_20260623020533.png",
}

Assets.env = {
    bgFar = "image/bg_far.png",
    bgWall = "image/bg_wall.png",
    ground = "image/tile_ground.png",
    platform = "image/tile_platform.png",
    monitor = "image/deco_monitor.png",
    debris = "image/deco_debris.png",
    titleBg = "image/title_bg.png",
    sceneEnding = "image/scene_ending.png",
}

Assets.buttons = {
    attack = "image/btn_atk_20260621193438.png",
    jump = "image/btn_jmp_20260621193517.png",
    clean = "image/btn_cln_20260621193437.png",
    dash = "image/btn_dsh_20260621193531.png",
    pause = "image/btn_pse_20260621193524.png",
    settings = "image/btn_set_20260621193516.png",
}

Assets.audio = {
    bgm_explore = "audio/bgm_explore.ogg",
    bgm_boss = "audio/bgm_boss.ogg",
    bgm_ending = "audio/bgm_ending.ogg",
    sfx_attack = "audio/sfx/sfx_attack.ogg",
    sfx_clean = "audio/sfx/sfx_clean.ogg",
    sfx_dash = "audio/sfx/sfx_dash.ogg",
    sfx_enemy_hit = "audio/sfx/sfx_enemy_hit.ogg",
    sfx_fragment = "audio/sfx/sfx_fragment.ogg",
    sfx_hurt = "audio/sfx/sfx_hurt.ogg",
    sfx_proj = "audio/sfx/sfx_proj.ogg",
    sfx_boss_enter = "audio/sfx/sfx_boss_enter.ogg",
    sfx_boss_die = "audio/sfx/sfx_boss_die.ogg",
}

Assets.font = "Fonts/MiSans-Regular.ttf"

return Assets