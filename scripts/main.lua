require "LuaScripts/Utilities/Sample"

local Roster = require("Roster")
local CombatFX = require("CombatFX")
local BattleAudio = require("BattleAudio")
local BattleTuning = require("BattleTuning")
local BattleDebug = require("BattleDebug")
local selectedSquad = { "archer", "mage", "healer" }

local DESIGN_W = 942
local DESIGN_H = 1670
local MAX_WAVES = 10
local MONSTER_ANIMATION_FRAMES = 6
local DEFENDER_ATTACK_FRAMES = 6

local nvgContext = nil
local fontId = -1
local images = {}
local imageMeta = {}
local imagePaths = {}
local loadQueue, loadCursor = {}, 1
local focused = true
local layoutAge = 1
local appliedFps = nil

local game = nil
local layout = nil
local drag = nil
local mouse = { x = 0, y = 0 }
local toast = { text = "", time = 0 }

local defenderTypes = {
    archer = {
        name = "弓箭手",
        color = { 122, 224, 95 },
        attack = { 9, 22, 42 },
        cooldown = { 1.15, 0.95, 0.78 },
        range = 500,
    },
    healer = {
        name = "奶妈",
        color = { 255, 210, 108 },
        cooldown = { 4.0, 3.5, 3.0 },
        range = 460,
    },
    mage = {
        name = "法师",
        color = { 105, 210, 255 },
        attack = { 8, 17, 30 },
        cooldown = { 1.55, 1.35, 1.12 },
        range = 500,
        slow = { 0.20, 0.30, 0.40 },
    },
}

for id, definition in pairs(Roster.extra) do defenderTypes[id] = definition end

local monsterTypes = {
    basic = { name = "小怪兽", hp = 55, speed = 58, defense = 0, damage = 1, silver = 12, color = { 80, 190, 100 }, walkFrameTime = 0.125, attackDuration = 0.85 },
    agile = { name = "敏捷怪兽", hp = 38, speed = 95, defense = 0, damage = 1, silver = 14, color = { 90, 235, 210 }, walkFrameTime = 0.083, attackDuration = 0.65 },
    tank = { name = "肉怪兽", hp = 165, speed = 38, defense = 0, damage = 2, silver = 30, color = { 180, 120, 210 }, walkFrameTime = 0.167, attackDuration = 1.15 },
    armored = { name = "甲壳怪兽", hp = 135, speed = 30, defense = 12, damage = 1, silver = 34, color = { 210, 175, 88 }, walkFrameTime = 0.250, attackDuration = 1.30 },
    boss = { name = "星核破坏者", hp = 480, speed = 26, defense = 3, damage = 2, silver = 120, color = { 210, 95, 70 }, walkFrameTime = 0.180, attackDuration = 1.40 },
}

local events = {
    {
        id = "attack_up",
        title = "全员攻击 +1",
        desc = "所有防守兵攻击属性提升 1 点",
        apply = function()
            game.bonuses.attackFlat = game.bonuses.attackFlat + 1
        end,
    },
    {
        id = "arrow_explosion",
        title = "爆裂箭头",
        desc = "弓箭手攻击有概率爆炸",
        apply = function()
            game.bonuses.archerExplosion = game.bonuses.archerExplosion + 0.16
        end,
    },
    {
        id = "arrow_pierce",
        title = "贯穿星矢",
        desc = "弓箭手对直线怪潮额外造成伤害",
        apply = function()
            game.bonuses.archerPierce = game.bonuses.archerPierce + 1
        end,
    },
    {
        id = "attack_speed",
        title = "急速校准",
        desc = "所有防守兵攻速提升",
        apply = function()
            game.bonuses.attackSpeed = game.bonuses.attackSpeed + 0.10
        end,
    },
    {
        id = "healer_speed",
        title = "急速祝福",
        desc = "奶妈祝福额外提升攻速",
        apply = function()
            game.bonuses.healerSpeed = game.bonuses.healerSpeed + 0.12
        end,
    },
    {
        id = "healer_attack",
        title = "战意祝福",
        desc = "奶妈祝福额外提升攻击力",
        apply = function()
            game.bonuses.healerAttack = game.bonuses.healerAttack + 0.12
        end,
    },
    {
        id = "frost_damage",
        title = "冰核增幅",
        desc = "法师技能伤害提升",
        apply = function()
            game.bonuses.mageDamage = game.bonuses.mageDamage + 0.18
        end,
    },
    {
        id = "frost_area",
        title = "扩散寒环",
        desc = "法师范围攻击半径提升",
        apply = function()
            game.bonuses.mageArea = game.bonuses.mageArea + 35
        end,
    },
    {
        id = "deep_freeze",
        title = "深冻禁锢",
        desc = "法师有概率短时间冻住怪兽",
        apply = function()
            game.bonuses.freezeChance = game.bonuses.freezeChance + 0.14
        end,
    },
    {
        id = "wall_fortify",
        title = "城墙加固",
        desc = "城墙最大血量与当前血量提升",
        apply = function()
            game.wallMax = game.wallMax + 4
            game.wallHp = math.min(game.wallMax, game.wallHp + 4)
        end,
    },
}

local slotDefs = {
    { x = 79, y = 1210 }, { x = 79, y = 1284 },
    { x = 197, y = 1282 }, { x = 306, y = 1282 }, { x = 414, y = 1282 },
    { x = 529, y = 1282 }, { x = 640, y = 1282 }, { x = 752, y = 1282 },
    { x = 860, y = 1210 }, { x = 860, y = 1284 },
}

function Start()
    math.randomseed(os.time())
    BattleDebug.Init()
    focused = true
    appliedFps = nil

    local graphics = GetGraphics()
    graphics:SetMode(450, 800)
    graphics.windowTitle = "星球防线"

    SampleStart()
    SampleInitMouseMode(MM_FREE)
    ConfigureFrameRate(30)
    if GetEngine then
        GetEngine():SetMaxInactiveFps(10)
        GetEngine():SetPauseMinimized(true)
    end

    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    fontId = nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf")
    LoadImages()
    ResetGame("home")

    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("KeyDown", "HandleKeyDown")
    SubscribeToEvent("InputFocus", "HandleInputFocus")

    print("星球防线核心战斗页已启动")
end

function Stop()
    if UnsubscribeFromAllEvents then UnsubscribeFromAllEvents() end
    BattleAudio.Shutdown()
    if nvgContext ~= nil then
        for _, entry in pairs(imagePaths) do
            local handle = entry.handle
            if handle ~= nil and handle ~= 0 then
                nvgDeleteImage(nvgContext, handle)
            end
        end
        nvgDelete(nvgContext)
        nvgContext = nil
    end
    images, imageMeta, imagePaths, loadQueue = {}, {}, {}, {}
    loadCursor, appliedFps = 1, nil
end

function LoadImage(id, path)
    if images[id] then return end
    local cached = imagePaths[path]
    if cached then
        images[id], imageMeta[id] = cached.handle, cached.meta
        return
    end
    local handle = nvgCreateImage(nvgContext, path, 0)
    if handle ~= nil and handle ~= 0 then
        images[id] = handle
        local w, h = nvgImageSize(nvgContext, handle)
        imageMeta[id] = { w = w or 1, h = h or 1 }
        imagePaths[path] = {handle=handle,meta=imageMeta[id]}
    else
        print("WARN: image load failed: " .. path)
    end
end

function LoadImages()
    LoadImage("home_background", "assets/image/home/home-background-v2.png")
    LoadImage("commander", "assets/image/home/commander-v1.png")
    for id in pairs(Roster.extra) do
        LoadImage(id .. "_standing", "assets/image/defenders/" .. id .. "/standing-v1.png")
    end
    for _, icon in ipairs({ "castle", "shield", "bot", "orbit", "swords", "snowflake", "heart", "lock-keyhole", "volume-2", "volume-x" }) do
        for _, tone in ipairs({ "light", "dark", "gold" }) do
            LoadImage("icon_" .. icon .. "_" .. tone, "assets/image/home/icons/" .. icon .. "-" .. tone .. ".png")
        end
    end

    local map = {
        archer = "archer",
        healer = "healer",
        mage = "frost-mage",
    }
    for id, folder in pairs(map) do
        for level = 1, 3 do
            LoadImage(id .. level, "assets/image/defenders/" .. folder .. "/level-" .. level .. ".png")
        end
    end
end

function QueueBattleResources()
    loadQueue, loadCursor = {}, 1
    local function enqueue(id,path)
        if not images[id] then loadQueue[#loadQueue+1]={id=id,path=path} end
    end
    enqueue("background", "assets/image/scene/battle-background-v6.png")
    -- Mage uses a stable sprite; level II pairs reuse level I attack frames.
    for _,id in ipairs(game.squad) do
        if id=="archer" or id=="healer" then
            for _,level in ipairs({1,3}) do
                for frame=1,DEFENDER_ATTACK_FRAMES do
                    enqueue(id.."_attack_"..level.."_"..frame,
                        string.format("assets/image/defenders/%s/attack/level-%d-%02d.png",id,level,frame))
                end
            end
        end
    end
    for _, id in ipairs({ "basic", "agile", "tank", "armored" }) do
        enqueue("monster_" .. id, "assets/image/monsters/" .. id .. "/portrait-v1.png")
        for frame = 1, MONSTER_ANIMATION_FRAMES do
            enqueue("monster_" .. id .. "_walk_" .. frame, string.format("assets/image/monsters/%s/walk/%02d.png", id, frame))
            enqueue("monster_" .. id .. "_attack_" .. frame, string.format("assets/image/monsters/%s/attack/%02d.png", id, frame))
        end
    end
    enqueue("monster_boss", "assets/image/monsters/tank/portrait-v1.png")
    for _,name in ipairs({"shot","hit","frost","ultimate","music"}) do
        if not BattleAudio.attempted[name] then loadQueue[#loadQueue+1]={sound=name} end
    end
    game.loadingBattle = #loadQueue>0
end

function ProcessBattleResources()
    -- Bound uploads per update; do not decode every animation in the Start callback.
    for _=1,2 do
        local job=loadQueue[loadCursor]
        if not job then break end
        if job.sound then BattleAudio.Init(); BattleAudio.Prepare(job.sound)
        else LoadImage(job.id,job.path) end
        loadCursor=loadCursor+1
    end
    if loadCursor>#loadQueue then
        game.loadingBattle=false
        loadQueue,loadCursor={},1
    end
end

function ConfigureFrameRate(fps)
    if appliedFps==fps then return end
    if GetEngine then GetEngine():SetMaxFps(fps) end
    appliedFps=fps
end

function HandleInputFocus(_,eventData)
    focused=eventData:GetBool("Focus") and not eventData:GetBool("Minimized")
    if not focused then BattleAudio.Stop(); drag=nil end
    layoutAge=1
    BattleDebug.Reset()
    ConfigureFrameRate(focused and (game and game.state=="playing" and 60 or 30) or 10)
end

function ResetGame(initialState)
    BattleAudio.Stop()
    BattleDebug.Reset()
    drag = nil
    loadQueue,loadCursor={},1
    layoutAge=1
    game = {
        state = initialState or "home",
        loadingBattle = false,
        homeTab = "home",
        homeGuard = 1,
        homeLevel = 3,
        squad = Roster.Copy(selectedSquad),
        rolePower = {},
        acidZones = {},
        silver = BattleTuning.startingSilver,
        combatFx = CombatFX.New(),
        combo = 0,
        comboTime = 0,
        summonCost = 20,
        eventCost = 60,
        wave = 0,
        waveTimer = 0.8,
        spawnRemaining = 0,
        spawnTimer = 0,
        monsters = {},
        defenders = {},
        projectiles = {},
        floats = {},
        particles = {},
        iceBlasts = {},
        ultimateQueue = {},
        eventChoices = nil,
        selectedDefender = nil,
        wallMax = 60,
        wallHp = 60,
        coreHp = 20,
        kills = 0,
        time = 0,
        bonuses = {
            attackFlat = 0,
            attackSpeed = 0,
            archerExplosion = 0,
            archerPierce = 0,
            healerSpeed = 0,
            healerAttack = 0,
            mageDamage = 0,
            mageArea = 0,
            freezeChance = 0,
        },
    }

    for i, def in ipairs(slotDefs) do
        game.defenders[i] = nil
    end
end

function StartBattle()
    if not Roster.Valid(selectedSquad) then
        ShowToast("请选择 1 至 3 种守卫出征")
        return
    end
    ResetGame("playing")
    if nvgContext then QueueBattleResources() end
end

function ToggleSquad(kind)
    if game.state ~= "home" or not Roster.Contains(Roster.order, kind) then return end
    local index = Roster.Contains(selectedSquad, kind)
    if index then
        table.remove(selectedSquad, index)
    elseif #selectedSquad < 3 then
        selectedSquad[#selectedSquad + 1] = kind
    else
        ShowToast("队伍已满，请先撤下一名守卫")
        return
    end
    game.squad = Roster.Copy(selectedSquad)
end

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    ConfigureFrameRate(focused and (game.state=="playing" and not game.loadingBattle and 60 or 30) or 10)
    if not focused then return end
    local debugStart=game.state~="home" and BattleDebug.BeginUpdate(dt) or nil
    layoutAge=layoutAge+dt
    if game.loadingBattle then ProcessBattleResources(); BattleDebug.EndUpdate(debugStart); return end
    if dt > 0.05 then dt = 0.05 end
    game.time = game.time + dt
    toast.time = math.max(0, toast.time - dt)
    BattleAudio.Update(dt,game.state == "playing")
    game.comboTime = math.max(0,game.comboTime-dt)
    if game.comboTime == 0 then game.combo = 0 end

    if game.state == "playing" then
        UpdateWave(dt)
        UpdateMonsters(dt)
        UpdateDefenders(dt)
        UpdateProjectiles(dt)
        UpdateExtraStatuses(dt)
        UpdateEffects(dt)
        CheckEndState()
    else
        UpdateEffects(dt)
    end
    BattleDebug.EndUpdate(debugStart)
end

function UpdateWave(dt)
    if game.spawnRemaining <= 0 and #game.monsters == 0 then
        game.waveTimer = game.waveTimer - dt
        if game.waveTimer <= 0 then
            if game.wave >= MAX_WAVES then
                game.state = "victory"
                return
            end
            StartNextWave()
        end
    end

    if game.spawnRemaining > 0 and #game.monsters < BattleTuning.maxMonsters then
        game.spawnTimer = game.spawnTimer - dt
        if game.spawnTimer <= 0 then
            game.spawnTimer = BattleTuning.packInterval(game.wave)
            local count = math.min(BattleTuning.packSize(game.wave),game.spawnRemaining,BattleTuning.maxMonsters-#game.monsters)
            for _=1,count do
                SpawnMonsterForWave()
                game.spawnRemaining = game.spawnRemaining - 1
            end
        end
    end
end

function StartNextWave()
    game.wave = game.wave + 1
    game.spawnRemaining = BattleTuning.waveCount(game.wave)
    game.spawnTimer = 0.1
    game.silver = game.silver + 20
    AddFloat(180, 1420, "+20 波次奖励", { 255, 230, 120 })
    if game.wave == 4 or game.wave == 8 then
        ShowToast("事件书籍可刷新强化，需要 " .. game.eventCost .. " 银币")
    end
end

function SpawnMonsterForWave()
    local id = "basic"
    if game.wave == 10 and game.spawnRemaining == 1 then
        id = "boss"
    elseif game.wave >= 7 and math.random() < 0.12 then
        id = "armored"
    elseif game.wave >= 5 and math.random() < 0.15 then
        id = "tank"
    elseif game.wave >= 3 and math.random() < 0.35 then
        id = "agile"
    end

    local src = monsterTypes[id]
    local x = 155 + math.random() * 630
    local swarm = id == "basic" or id == "agile"
    local hp = (src.hp + game.wave * (id == "boss" and 10 or 5)) * (swarm and BattleTuning.swarmHealth or 1)
    table.insert(game.monsters, {
        id = id,
        x = x,
        y = 240 + math.random()*100,
        hp = hp,
        maxHp = hp,
        speed = src.speed,
        defense = src.defense,
        damage = swarm and BattleTuning.swarmDamage or src.damage,
        silver = swarm and BattleTuning.swarmSilver or src.silver,
        swarm = swarm,
        slowTime = 0,
        slowRatio = 0,
        freezeTime = 0,
        attackTimer = 0,
        radius = id == "boss" and 46 or 28,
        animState = "walk",
        animTime = math.random() * src.walkFrameTime * MONSTER_ANIMATION_FRAMES,
        attackApplied = false,
        dead = false,
    })
end

function UpdateMonsters(dt)
    local wallY = 1185
    for i = #game.monsters, 1, -1 do
        local m = game.monsters[i]
        m.hitFlash = math.max(0,(m.hitFlash or 0)-dt)
        if m.freezeTime > 0 then
            m.freezeTime = m.freezeTime - dt
        elseif m.y < wallY then
            if m.animState ~= "walk" then
                m.animState = "walk"
                m.animTime = 0
            end
            m.animTime = m.animTime + dt
            local slow = m.slowTime > 0 and m.slowRatio or 0
            m.y = m.y + m.speed * (1 - slow) * dt
            m.slowTime = math.max(0, m.slowTime - dt)
        else
            local duration = monsterTypes[m.id].attackDuration
            if m.animState ~= "attack" then
                m.animState = "attack"
                m.animTime = 0
                m.attackApplied = false
            end
            m.animTime = m.animTime + dt
            if not m.attackApplied and m.animTime >= duration * 0.58 then
                m.attackApplied = true
                ApplyMonsterAttack(m, wallY)
                if m.dead then
                    table.remove(game.monsters, i)
                end
            end
            if not m.dead and m.animTime >= duration then
                m.animTime = m.animTime - duration
                m.attackApplied = false
            end
        end
    end
end

function ApplyMonsterAttack(m, wallY)
    game.wallHp = game.wallHp - m.damage
    AddFloat(m.x, wallY - 20, "-" .. m.damage, { 255, 90, 80 })
    SpawnParticle(m.x, wallY, 30 + m.damage * 3, { 255, 105, 75 })
    if game.wallHp <= 0 then
        game.coreHp = game.coreHp - m.damage
        m.dead = true
        AddFloat(470, 1340, "星核 -" .. m.damage, { 255, 80, 80 })
    end
end

function UpdateDefenders(dt)
    for i, d in pairs(game.defenders) do
        d.overdriveTime = math.max(0,(d.overdriveTime or 0)-dt)
        d.mergeTime = math.max(0, (d.mergeTime or 0) - dt)
        d.ultimateFlash = math.max(0, (d.ultimateFlash or 0) - dt)
        if d ~= dragDefender() then
            d.buffTime = math.max(0, (d.buffTime or 0) - dt)
            if d.buffTime <= 0 then
                d.buffAttack = 0
                d.buffSpeed = 0
                d.buffSource = nil
            end
            if d.action ~= nil then
                UpdateDefenderAction(i, d, dt)
            else
                d.cooldown = math.max(0, d.cooldown - dt)
                if d.cooldown <= 0 then
                    BeginDefenderAction(i, d)
                end
            end
        end
    end
end

function BeginDefenderAction(slotIndex, d)
    local speedBonus = 1 + game.bonuses.attackSpeed + (d.buffSpeed or 0) + ((d.overdriveTime or 0)>0 and 1 or 0)
    local interval = defenderTypes[d.kind].cooldown[d.level] / speedBonus
    local target = nil
    local action = d.kind

    if d.kind == "healer" then
        target = FindBestBuffTarget(slotIndex)
        if target == nil and game.wallHp >= game.wallMax then
            d.cooldown = 0.35
            return
        end
    else
        target = FindTarget(d)
        if target == nil then
            d.cooldown = 0.12
            return
        end
    end

    d.action = action
    d.actionTime = 0
    d.actionDuration = math.min(0.65, math.max(0.32, interval * 0.72))
    d.actionInterval = interval
    d.actionReleased = false
    d.actionTarget = target
end

function UpdateDefenderAction(slotIndex, d, dt)
    d.actionTime = d.actionTime + dt
    local progress = math.min(1, d.actionTime / d.actionDuration)
    if not d.actionReleased and progress >= 0.62 then
        d.actionReleased = true
        ReleaseDefenderAction(slotIndex, d)
    end
    if progress >= 1 then
        d.cooldown = math.max(0.05, d.actionInterval - d.actionDuration)
        d.action = nil
        d.actionTarget = nil
    end
end

function ReleaseDefenderAction(slotIndex, d)
    local start = slotDefs[slotIndex]
    if Roster.extra[d.kind] then
        ReleaseExtraAttack(d, false)
        return
    end
    if d.kind == "healer" then
        if d.actionTarget ~= nil and IsDefenderActive(d.actionTarget) then
            CreateProjectile("blessing", start.x, start.y - 35, d.actionTarget, {
                level = d.level,
                duration = 4.0 + d.level * 0.6,
                attack = 0.10 + game.bonuses.healerAttack,
                speed = 0.10 + game.bonuses.healerSpeed,
                owner = d,
            })
        elseif game.wallHp < game.wallMax then
            game.wallHp = math.min(game.wallMax, game.wallHp + 1)
            AddFloat(start.x, start.y - 45, "修墙 +1", { 120, 255, 160 })
            SpawnParticle(start.x, start.y, 48, { 120, 255, 160 })
        end
        return
    end

    local target = d.actionTarget
    if not IsMonsterAlive(target) then return end
    local shots = d.level == 3 and 3 or 2
    if #game.projectiles>160 then shots=1 end
    BattleAudio.Play("shot")
    CombatFX.Emit(game.combatFx,"hit",start.x,start.y-45,38,defenderTypes[d.kind].color)

    if d.kind == "archer" then
        local dmg = defenderTypes.archer.attack[d.level] + game.bonuses.attackFlat
        dmg = dmg * (1 + (d.buffAttack or 0))
        for shot=1,shots do
        CreateProjectile("arrow", start.x+(shot-(shots+1)/2)*8, start.y - 35, target, {
            damage = dmg/shots,
            share = 1/shots,
            explosion = game.bonuses.archerExplosion > 0 and math.random() < game.bonuses.archerExplosion,
            pierce = d.level == 3 or game.bonuses.archerPierce > 0,
            owner = d,
        })
        game.projectiles[#game.projectiles].delay=(shot-1)*BattleTuning.volleyInterval
        end
    elseif d.kind == "mage" then
        local dmg = (defenderTypes.mage.attack[d.level] + game.bonuses.attackFlat) * (1 + game.bonuses.mageDamage) * (1+(d.buffAttack or 0))
        for shot=1,shots do
        CreateProjectile("frost", start.x+(shot-(shots+1)/2)*12, start.y - 35, target, {
            damage = dmg/shots,
            share = 1/shots,
            level = d.level,
            slowTime = 1.6 + d.level * 0.25,
            slowRatio = math.min(0.75, defenderTypes.mage.slow[d.level] + 0.05),
            freeze = math.random() < game.bonuses.freezeChance,
            owner = d,
        })
        game.projectiles[#game.projectiles].delay=(shot-1)*BattleTuning.volleyInterval
        end
    end
end

function FindTarget(d)
    local best = nil
    local bestY = -99999
    local sx = slotDefs[d.slot].x
    local sy = slotDefs[d.slot].y
    local range = defenderTypes[d.kind].range + BattleTuning.rangedRangeBonus
    for _, m in ipairs(game.monsters) do
        local dx = m.x - sx
        local dy = m.y - sy
        local preferred = m.y > bestY
        if d.kind == "rail_sniper" and best then
            preferred = m.defense > best.defense or (m.defense == best.defense and m.y > bestY)
        end
        if not m.dead and dx * dx + dy * dy <= range * range and preferred then
            best = m
            bestY = m.y
        end
    end
    return best
end

function FindBestBuffTarget(excludeSlot)
    local best = nil
    local bestScore = -1
    for i, d in pairs(game.defenders) do
        if i ~= excludeSlot and d.kind ~= "healer" then
            local score = d.level * 10 + (d.kind == "archer" and 4 or 0)
            if score > bestScore then
                best = d
                bestScore = score
            end
        end
    end
    return best
end

function DamageMonster(m, amount, damageType, owner, armorIgnore, share)
    if m == nil or m.dead then return false end
    local defense = math.max(0, m.defense - ((m.corrosionLeft or 0) > 0 and (m.corrosion or 0) or 0))
    share = share or 1
    local final = math.max(share, amount - (damageType == "physical" and defense * (1 - (armorIgnore or 0)) or defense * 0.5) * share)
    m.hp = m.hp - final
    local c = owner and defenderTypes[owner.kind].color or {255,205,100}
    CombatFX.Emit(game.combatFx,"hit",m.x,m.y-12,28,c)
    m.hitFlash = 0.12
    if owner and (owner.level==3 or final>=25) and (m.damageTextTime or 0)<=game.time then
        AddFloat(m.x,m.y-38,tostring(math.floor(final+0.5)),c)
        m.damageTextTime=game.time+0.18
    end
    if m.hp <= 0 then
        KillMonster(m, owner)
        return true
    end
    return false
end

function AreaDamage(x, y, radius, amount, owner, share)
    for i = #game.monsters, 1, -1 do
        local m = game.monsters[i]
        local dx, dy = m.x - x, m.y - y
        if dx * dx + dy * dy <= radius * radius then
            DamageMonster(m, amount, "magic", owner, 0, share)
        end
    end
    SpawnParticle(x, y, radius, { 255, 160, 70 })
end

function AreaSlow(x, y, radius, amount, owner, share)
    for i = #game.monsters, 1, -1 do
        local m = game.monsters[i]
        local dx, dy = m.x - x, m.y - y
        if dx * dx + dy * dy <= radius * radius then
            DamageMonster(m, amount, "magic", owner, 0, share)
            if not m.dead then
                m.slowTime = math.max(m.slowTime, 1.2)
                m.slowRatio = math.max(m.slowRatio, 0.35)
            end
        end
    end
    SpawnParticle(x, y, radius, { 90, 220, 255 })
end

function GainRage(defender, amount)
    if defender == nil or defender.level ~= 3 or not IsDefenderActive(defender) then return end
    local before = defender.rage or 0
    defender.rage = math.min(100, before + amount)
    if before < 100 and defender.rage >= 100 then
        table.insert(game.ultimateQueue, defender)
        defender.ultimateFlash = 1.2
        local slot = slotDefs[defender.slot]
        AddFloat(slot.x, slot.y - 70, "终极就绪", { 255, 220, 100 })
        SpawnParticle(slot.x, slot.y - 20, 76, { 255, 220, 100 })
    end
end

function GetReadyUltimate()
    while #game.ultimateQueue > 0 do
        local queued = game.ultimateQueue[1]
        if IsDefenderActive(queued) and queued.level == 3 and (queued.rage or 0) >= 100 then
            return queued
        end
        table.remove(game.ultimateQueue, 1)
    end
    for _, defender in pairs(game.defenders) do
        if defender.level == 3 and (defender.rage or 0) >= 100 then
            return defender
        end
    end
    return nil
end

function GetHighestRageDefender()
    local best = nil
    for _, defender in pairs(game.defenders) do
        if defender.level == 3 and (best == nil or defender.rage > best.rage) then
            best = defender
        end
    end
    return best
end

function UltimateName(kind)
    if Roster.extra[kind] then return Roster.extra[kind].skill end
    if kind == "archer" then return "星辉重箭" end
    if kind == "mage" then return "绝对零域" end
    return "生命超载"
end

function CastReadyUltimate()
    local defender = GetReadyUltimate()
    if defender == nil then
        ShowToast("三级角色击杀怪兽可积攒怒气")
        return
    end

    local target = defender.kind == "healer" and nil or FindTarget(defender)
    if defender.kind ~= "healer" and target == nil then
        ShowToast("没有可锁定的怪兽")
        return
    end
    local acidReservations = #game.acidZones
    for _, p in ipairs(game.projectiles) do
        if p.extra and p.kind == "alchemist" and p.ultimate then acidReservations = acidReservations + 1 end
    end
    if defender.kind == "alchemist" and acidReservations >= 2 then
        ShowToast("场上最多同时存在两个酸雾区")
        return
    end

    defender.rage = 0
    BattleAudio.Play("ultimate")
    if defender.kind=="archer" or defender.kind=="bombardier" or defender.kind=="rail_sniper" then
        defender.overdriveTime = 4
    end
    defender.ultimateFlash = 0.8
    if game.ultimateQueue[1] == defender then table.remove(game.ultimateQueue, 1) end
    local start = slotDefs[defender.slot]
    if Roster.extra[defender.kind] then
        defender.actionTarget = target
        ReleaseExtraAttack(defender, true)
        AddFloat(start.x, start.y - 76, UltimateName(defender.kind), defenderTypes[defender.kind].color)
    elseif defender.kind == "archer" then
        CreateProjectile("star_arrow", start.x, start.y - 35, target, {
            damage = 150,
            owner = defender,
        })
        AddFloat(start.x, start.y - 76, "星辉重箭", { 255, 220, 95 })
    elseif defender.kind == "mage" then
        CastFrostUltimate(defender, target.x, target.y)
    else
        game.wallHp = math.min(game.wallMax, game.wallHp + 8)
        for _, ally in pairs(game.defenders) do
            ally.buffTime = math.max(ally.buffTime or 0, 7.0)
            ally.buffAttack = math.max(ally.buffAttack or 0, 0.25)
            ally.buffSpeed = math.max(ally.buffSpeed or 0, 0.25)
            ally.buffSource = defender
            local slot = slotDefs[ally.slot]
            SpawnParticle(slot.x, slot.y - 15, 62, { 155, 255, 105 })
        end
        AddFloat(start.x, start.y - 76, "生命超载", { 160, 255, 120 })
        SpawnParticle(start.x, start.y - 20, 118, { 160, 255, 120 })
    end
end

function CastFrostUltimate(defender, x, y)
    local radius = 205 + game.bonuses.mageArea
    table.insert(game.iceBlasts, { x = x, y = y, radius = radius, life = 1.05, maxLife = 1.05 })
    for i = #game.monsters, 1, -1 do
        local monster = game.monsters[i]
        local dx, dy = monster.x - x, monster.y - y
        if dx * dx + dy * dy <= radius * radius then
            DamageMonster(monster, 68, "magic", defender)
            if not monster.dead then
                monster.slowTime = math.max(monster.slowTime, 3.2)
                monster.slowRatio = math.max(monster.slowRatio, 0.82)
                monster.freezeTime = monster.id == "boss" and 0.75 or 1.8
            end
        end
    end
    AddFloat(x, y - 58, "绝对零域", { 175, 245, 255 })
    SpawnParticle(x, y, radius * 0.62, { 125, 235, 255 })
end

function KillMonster(monster, owner)
    if monster == nil or monster.dead then return end
    monster.dead = true
    game.combo,game.comboTime = game.combo+1,2.5
    CombatFX.Emit(game.combatFx,"burst",monster.x,monster.y,48,{255,200,85})
    for i = #game.monsters, 1, -1 do
        if game.monsters[i] == monster then
            table.remove(game.monsters, i)
            game.silver = game.silver + monster.silver
            game.kills = game.kills + 1
            GainRage(owner, monster.id == "boss" and 50 or (monster.swarm and 10 or 25))
            if owner ~= nil and owner.buffSource ~= nil then
                GainRage(owner.buffSource, monster.id == "boss" and 20 or 10)
            end
            AddFloat(monster.x, monster.y - 25, "+" .. monster.silver, { 255, 230, 120 })
            SpawnParticle(monster.x, monster.y, 45, { 255, 230, 120 })
            return
        end
    end
end

function UpdateProjectiles(dt)
    for i = #game.projectiles, 1, -1 do
        local p = game.projectiles[i]
        if (p.delay or 0)>0 then
            p.delay=math.max(0,p.delay-dt)
        else
        if p.extra then
            if UpdateExtraProjectile(p, dt) then table.remove(game.projectiles, i) end
        else
        local tx, ty = GetProjectileTargetPosition(p)
        if tx == nil then
            table.remove(game.projectiles, i)
        else
            local dx, dy = tx - p.x, ty - p.y
            local distance = math.sqrt(dx * dx + dy * dy)
            local step = p.speed * dt
            p.prevX, p.prevY = p.x, p.y
            if distance <= math.max(4, step) then
                p.x, p.y = tx, ty
                ResolveProjectile(p)
                table.remove(game.projectiles, i)
            elseif distance > 0 then
                p.x = p.x + dx / distance * step
                p.y = p.y + dy / distance * step
            end
        end
        end
        end
    end
end

function NearbyEnemies(x, y, radius, cap)
    local result = {}
    for _, m in ipairs(game.monsters) do
        local distance = (m.x - x)^2 + (m.y - y)^2
        if not m.dead and distance <= radius^2 then result[#result + 1] = { monster = m, distance = distance } end
    end
    table.sort(result, function(a, b) return a.distance < b.distance end)
    local limited = {}
    for i = 1, math.min(cap, #result) do limited[i] = result[i].monster end
    return limited
end

function ReleaseExtraAttack(d, ultimate)
    local target = d.actionTarget
    if not IsMonsterAlive(target) then target = FindTarget(d) end
    if not target then return end
    local config, start = defenderTypes[d.kind], slotDefs[d.slot]
    local damage = ultimate and config.ultimate or (config.attack[d.level] + game.bonuses.attackFlat)
        * (1 + (d.buffAttack or 0)) * (1 + (game.rolePower[d.kind] or 0) * 0.1)
    local dx, dy = target.x - start.x, target.y - (start.y - 35)
    local distance = math.max(1, math.sqrt(dx * dx + dy * dy))
    local duration = d.kind == "rail_sniper" and distance / 1500 or 0.45
    if d.kind == "stormcaller" then duration = 0.08 end
    if d.kind == "blade_dancer" then duration = 0.36 end
    local shots = d.kind=="bombardier" and not ultimate and d.level or 1
    if #game.projectiles>160 then shots=1 end
    BattleAudio.Play("shot")
    CombatFX.Emit(game.combatFx,"hit",start.x,start.y-45,ultimate and 75 or 38,config.color)
    for shot=1,shots do
    local p = { extra = true, kind = d.kind, x = start.x, y = start.y - 35, prevX = start.x,
        prevY = start.y - 35, startX = start.x, startY = start.y - 35,
        endX = target.x, endY = target.y, target = target, elapsed = 0, duration = duration,
        owner = d, level = d.level, damage = damage/shots, share=1/shots, delay=(shot-1)*0.1, ultimate = ultimate, visited = {}, count = 0 }
    if d.kind == "rail_sniper" and ultimate then
        p.endX, p.endY = p.startX + dx / distance * 700, p.startY + dy / distance * 700
        p.duration = 700 / 1500
    end
    game.projectiles[#game.projectiles + 1] = p
    end
end

function ExtraDamage(p, m, multiplier, ignore)
    local owner = p.owner
    -- A projectile fired at level II must not grant level III rage after a merge.
    if owner and owner.level ~= p.level then owner = nil end
    DamageMonster(m, p.damage * (multiplier or 1), defenderTypes[p.kind].damageType, owner, ignore, p.share)
end

function PullEnemies(p, x, y, radius, cap, amount)
    for _, m in ipairs(NearbyEnemies(x, y, radius, cap)) do
        if m.id ~= "boss" and m.y < 1185 and (m.pullCooldown or 0) <= 0 then
            local dx, dy = x - m.x, math.max(0, y - m.y)
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance > 0 then
                m.pull = { dx = dx / distance * math.min(amount, distance), dy = dy / distance * math.min(amount, distance), left = 0.25 }
                m.pullCooldown = 0.8
            end
        end
    end
end

function ExtraImpact(p)
    local config = defenderTypes[p.kind]
    local radius = p.ultimate and 170 or config.radius
    local cap = p.ultimate and 6 or config.cap
    CombatFX.Emit(game.combatFx,"burst",p.endX,p.endY,radius,config.color)
    BattleAudio.Play(p.kind=="bombardier" and "hit" or "frost")
    if p.kind == "bombardier" then
        for i, m in ipairs(NearbyEnemies(p.endX, p.endY, radius, cap)) do ExtraDamage(p, m, p.ultimate and 1 or (i == 1 and 1 or 0.55)) end
    elseif p.kind == "alchemist" then
        if p.ultimate then
            if #game.acidZones < 2 then game.acidZones[#game.acidZones + 1] = { x=p.endX, y=p.endY, left=3, tick=1, payload=p } end
        else
            for _, m in ipairs(NearbyEnemies(p.endX, p.endY, radius, cap)) do
                ExtraDamage(p, m)
                local tickDamage = ({2,5,9})[p.level]
                if not m.acid or tickDamage > m.acid.damage then
                    m.acid = { left=3, tick=m.acid and m.acid.tick or 1, damage=tickDamage, owner=p.owner }
                elseif tickDamage == m.acid.damage then
                    m.acid.left = 3
                    if not IsDefenderActive(m.acid.owner) then m.acid.owner = p.owner end
                end
                if p.level == 3 then m.corrosion = math.max(m.corrosion or 0, 3); m.corrosionLeft = 3 end
            end
        end
    elseif p.kind == "gravity_engineer" then
        local targets = p.ultimate and NearbyEnemies(p.endX, p.endY, 180, 6) or {p.target}
        for _, m in ipairs(targets) do
            if IsMonsterAlive(m) then
                ExtraDamage(p, m)
                m.slowTime = math.max(m.slowTime, p.ultimate and (m.id == "boss" and 0.6 or 1.5) or 0.6)
                m.slowRatio = math.max(m.slowRatio, p.ultimate and 0.4 or 0.25)
            end
        end
        if p.ultimate then PullEnemies(p, p.endX, p.endY, 180, 6, 70)
        elseif IsDefenderActive(p.owner) and p.level == 3 and IsMonsterAlive(p.target) then
            p.owner.gravityHits = (p.owner.gravityHits or 0) + 1
            if p.owner.gravityHits % 3 == 0 then PullEnemies(p, p.endX, p.endY, 100, 3, 35) end
        end
    end
    SpawnParticle(p.endX, p.endY, radius, config.color)
end

function UpdateExtraProjectile(p, dt)
    if (p.kind == "gravity_engineer" and not p.ultimate) or p.kind == "stormcaller" or (p.kind == "rail_sniper" and not p.ultimate) then
        if IsMonsterAlive(p.target) then p.endX,p.endY = p.target.x,p.target.y end
    end
    p.elapsed = p.elapsed + dt
    local t = math.min(1, p.elapsed / p.duration)
    p.prevX, p.prevY = p.x, p.y
    p.x, p.y = p.startX + (p.endX - p.startX) * t, p.startY + (p.endY - p.startY) * t
    local pathAttack = p.kind == "blade_dancer" or (p.kind == "rail_sniper" and p.ultimate)
    if pathAttack then
        local dx, dy = p.x - p.prevX, p.y - p.prevY
        local candidates = {}
        for _, m in ipairs(game.monsters) do
            local u = math.max(0, math.min(1, ((m.x-p.prevX)*dx+(m.y-p.prevY)*dy) / math.max(0.001,dx*dx+dy*dy)))
            if not p.visited[m] and (m.x-p.prevX-u*dx)^2+(m.y-p.prevY-u*dy)^2 <= 32^2 then
                candidates[#candidates+1] = {m=m,u=u}
            end
        end
        table.sort(candidates,function(a,b) return a.u<b.u end)
        for _, hit in ipairs(candidates) do
            if p.count < (p.ultimate and 3 or (p.level == 1 and 2 or 3)) then
                p.visited[hit.m], p.count = true, p.count + 1
                local multiplier = p.returning and 0.5 or 1
                if p.kind == "rail_sniper" then multiplier = ({1,0.5,0.25})[p.count] end
                ExtraDamage(p,hit.m,multiplier,p.kind == "rail_sniper" and 0.5 or 0)
                SpawnParticle(hit.m.x,hit.m.y,25,defenderTypes[p.kind].color)
            end
        end
    end
    if t < 1 then return false end
    if p.kind=="rail_sniper" or p.kind=="stormcaller" then
        CombatFX.Emit(game.combatFx,"beam",p.startX,p.startY,p.ultimate and 20 or 10,defenderTypes[p.kind].color,p.endX,p.endY)
        BattleAudio.Play("shot")
    end
    if p.kind == "blade_dancer" and not p.returning then
        p.returning, p.elapsed, p.count, p.visited = true, 0, 0, {}
        p.startX,p.endX,p.startY,p.endY = p.endX,p.startX,p.endY,p.startY
        return false
    elseif p.kind == "stormcaller" then
        if IsMonsterAlive(p.target) then ExtraDamage(p,p.target); p.visited[p.target]=true end
            p.count = p.count + 1
        SpawnParticle(p.endX,p.endY,28,defenderTypes[p.kind].color)
        local cap = p.ultimate and 6 or (p.level == 1 and 2 or 3)
        if p.count < cap then
            for _, m in ipairs(NearbyEnemies(p.endX,p.endY,p.ultimate and 220 or 155,1000)) do
                if not p.visited[m] then
                    p.startX,p.startY,p.target,p.elapsed = p.endX,p.endY,m,0
                    p.endX,p.endY = m.x,m.y
                    if not p.ultimate then p.damage = p.damage * 0.65 end
                    return false
                end
            end
        end
    elseif p.kind == "rail_sniper" and not p.ultimate then
        if IsMonsterAlive(p.target) then ExtraDamage(p,p.target,1,0.25); SpawnParticle(p.target.x,p.target.y,25,defenderTypes[p.kind].color) end
    elseif not pathAttack then ExtraImpact(p) end
    return true
end

function UpdateExtraStatuses(dt)
    for i = #game.monsters, 1, -1 do
        local m = game.monsters[i]
        m.corrosionLeft = math.max(0, (m.corrosionLeft or 0) - dt)
        m.pullCooldown = math.max(0, (m.pullCooldown or 0) - dt)
        m.acidZoneCooldown = math.max(0, (m.acidZoneCooldown or 0) - dt)
        if m.pull and m.y < 1185 then
            local step = math.min(dt,m.pull.left)
            m.x = math.max(100,math.min(842,m.x+m.pull.dx*step/0.25))
            m.y = math.min(1185,m.y+m.pull.dy*step/0.25)
            m.pull.left = m.pull.left-step
            if m.pull.left <= 0.0001 then m.pull=nil end
        end
        if m.acid then
            local a = m.acid
            a.left,a.tick = a.left-dt,a.tick-dt
            if a.tick <= 0.0001 then DamageMonster(m,a.damage,"magic",a.owner); a.tick=a.tick+1 end
            if a.left <= 0.0001 then m.acid=nil end
        end
    end
    local hit = {}
    for i = #game.acidZones, 1, -1 do
        local zone = game.acidZones[i]
        zone.left,zone.tick = zone.left-dt,zone.tick-dt
        if zone.tick <= 0.0001 then
            for _, m in ipairs(NearbyEnemies(zone.x,zone.y,160,5)) do
                if not hit[m] and (m.acidZoneCooldown or 0) <= 0.0001 then
                    ExtraDamage(zone.payload,m); hit[m]=true; m.acidZoneCooldown=1
                end
                m.corrosion,m.corrosionLeft = 5,3
            end
            SpawnParticle(zone.x,zone.y,160,defenderTypes.alchemist.color)
            zone.tick=zone.tick+1
        end
        if zone.left <= 0.0001 then table.remove(game.acidZones,i) end
    end
end

function CreateProjectile(kind, x, y, target, payload)
    local speed = kind == "star_arrow" and 1320 or (kind == "arrow" and 850 or (kind == "frost" and 650 or 560))
    table.insert(game.projectiles, {
        kind = kind,
        x = x,
        y = y,
        prevX = x,
        prevY = y,
        originX = x,
        originY = y,
        target = target,
        payload = payload or {},
        speed = speed,
    })
end

function GetProjectileTargetPosition(p)
    if p.kind == "blessing" then
        if not IsDefenderActive(p.target) then return nil, nil end
        local slot = slotDefs[p.target.slot]
        return slot.x, slot.y - 22
    end
    if not IsMonsterAlive(p.target) then return nil, nil end
    return p.target.x, p.target.y
end

function IsMonsterAlive(target)
    if target == nil or target.dead then return false end
    for _, m in ipairs(game.monsters) do
        if m == target then return true end
    end
    return false
end

function IsDefenderActive(target)
    if target == nil then return false end
    for _, d in pairs(game.defenders) do
        if d == target then return true end
    end
    return false
end

function ResolveProjectile(p)
    local payload = p.payload
    if p.kind == "blessing" then
        local target = p.target
        if IsDefenderActive(target) then
            target.buffTime = payload.duration
            target.buffAttack = payload.attack
            target.buffSpeed = payload.speed
            target.buffSource = payload.owner
            local slot = slotDefs[target.slot]
            AddFloat(slot.x, slot.y - 52, "祝福", { 255, 230, 120 })
            SpawnParticle(slot.x, slot.y - 15, 58, { 155, 255, 105 })
        end
        return
    end

    local target = p.target
    if not IsMonsterAlive(target) then return end
    local x, y = target.x, target.y
    if p.kind == "star_arrow" then
        CombatFX.Emit(game.combatFx,"beam",p.originX,p.originY,16,{255,220,90},x,y)
        CombatFX.Emit(game.combatFx,"burst",x,y,155,{255,170,80})
        BattleAudio.Play("hit")
        DamageMonster(target, payload.damage, "physical", payload.owner)
        AreaDamage(x, y, 155, payload.damage * 0.55, payload.owner)
        SpawnParticle(x, y, 155, { 255, 205, 85 })
    elseif p.kind == "arrow" then
        DamageMonster(target, payload.damage, "physical", payload.owner,0,payload.share)
        if payload.explosion then
            AreaDamage(x, y, 75, payload.damage * 0.45, payload.owner, payload.share)
        end
        if payload.pierce then
            AreaDamage(x, y - 90, 55, payload.damage * 0.35, payload.owner, payload.share)
        end
        SpawnParticle(x, y, payload.explosion and 75 or 24, payload.explosion and { 255, 160, 70 } or { 170, 255, 120 })
    elseif p.kind == "frost" then
        DamageMonster(target, payload.damage, "magic", payload.owner,0,payload.share)
        BattleAudio.Play("frost")
        if IsMonsterAlive(target) then
            target.slowTime = payload.slowTime
            target.slowRatio = payload.slowRatio
            if payload.freeze then
                target.freezeTime = target.id == "boss" and 0.35 or 0.9
                AddFloat(x, y - 30, "冻结", { 150, 230, 255 })
            end
        end
        if payload.level == 3 then
            AreaSlow(x, y, 75 + game.bonuses.mageArea, payload.damage * 0.40, payload.owner, payload.share)
        else
            SpawnParticle(x, y, 36, { 90, 220, 255 })
        end
    end
end

function SpawnParticle(x, y, r, color)
    if #game.particles >= 64 then return end
    table.insert(game.particles, { x = x, y = y, r = r, color = color, life = 0.35, maxLife = 0.35 })
end

function AddFloat(x, y, text, color)
    if #game.floats >= 48 then return end
    table.insert(game.floats, { x = x, y = y, text = text, color = color, life = 1.0, maxLife = 1.0 })
end

function UpdateEffects(dt)
    CombatFX.Update(game.combatFx,dt)
    for i = #game.floats, 1, -1 do
        local f = game.floats[i]
        f.life = f.life - dt
        f.y = f.y - 42 * dt
        if f.life <= 0 then table.remove(game.floats, i) end
    end
    for i = #game.particles, 1, -1 do
        local p = game.particles[i]
        p.life = p.life - dt
        if p.life <= 0 then table.remove(game.particles, i) end
    end
    for i = #game.iceBlasts, 1, -1 do
        local blast = game.iceBlasts[i]
        blast.life = blast.life - dt
        if blast.life <= 0 then table.remove(game.iceBlasts, i) end
    end
end

function CheckEndState()
    if game.coreHp <= 0 then
        game.state = "defeat"
    end
end

function HandleMouseDown(eventType, eventData)
    local button = eventData:GetInt("Button")
    if button ~= MOUSEB_LEFT then return end
    BattleAudio.Unlock()

    local sx, sy = eventData:GetInt("X"), eventData:GetInt("Y")
    local x, y = ScreenToDesign(sx, sy)
    if game.state~="home" and BattleDebug.Hit(layout.debugBounds,sx,sy) then
        BattleDebug.Toggle()
        return
    end
    if game.loadingBattle then return end
    mouse.x, mouse.y = x, y
    if game.state ~= "home" and HitRect(x,y,layout.audioButton) then
        BattleAudio.Toggle()
        ShowToast(BattleAudio.muted and "战斗声音已关闭" or "战斗声音已开启")
        return
    end

    if game.eventChoices ~= nil then
        local picked = HitEventChoice(x, y)
        if picked ~= nil then
            ApplyEventChoice(picked)
        end
        return
    end

    if game.state == "home" then
        if HitRect(x, y, layout.homeHomeButton) then
            game.homeTab = "home"
        elseif HitRect(x, y, layout.homeGuardButton) then
            game.homeTab = "guards"
        elseif HitRect(x, y, layout.homeMechaButton) then
            game.homeTab = "mecha"
        elseif HitRect(x, y, layout.homeMapButton) then
            game.homeTab = "map"
        elseif HitRect(x, y, layout.homeStartButton) and game.homeTab == "home" then
            StartBattle()
        elseif game.homeTab == "guards" then
            if HitRect(x, y, layout.homeSquadToggle) then
                ToggleSquad(Roster.order[game.homeGuard])
                return
            end
            for i, r in ipairs(layout.homeGuardChoices) do
                if HitRect(x, y, r) then game.homeGuard = i end
            end
            for i, r in ipairs(layout.homeLevelChoices) do
                if HitRect(x, y, r) then game.homeLevel = i end
            end
        elseif game.homeTab == "map" and HitRect(x, y, layout.homeMapVisit) then
            game.homeTab = "home"
        end
        return
    end

    if game.state ~= "playing" then
        if HitRect(x, y, layout.resultHomeButton) then
            ResetGame("home")
        else
            StartBattle()
        end
        return
    end

    if HitRect(x, y, layout.bookButton) then
        OpenEventBook()
        return
    end
    if HitRect(x, y, layout.barracksButton) then
        SummonDefender()
        return
    end
    if HitRect(x, y, layout.lordButton) then
        CastReadyUltimate()
        return
    end

    local slot = FindDefenderAt(x, y)
    if slot ~= nil then
        drag = {
            slot = slot,
            defender = game.defenders[slot],
            x = x,
            y = y,
        }
    end
end

function HandleMouseMove(eventType, eventData)
    local sx, sy = eventData:GetInt("X"), eventData:GetInt("Y")
    local x, y = ScreenToDesign(sx, sy)
    mouse.x, mouse.y = x, y
    if drag ~= nil then
        drag.x, drag.y = x, y
    end
end

function HandleMouseUp(eventType, eventData)
    local button = eventData:GetInt("Button")
    if button ~= MOUSEB_LEFT or drag == nil then return end

    local sx, sy = eventData:GetInt("X"), eventData:GetInt("Y")
    local x, y = ScreenToDesign(sx, sy)
    local targetSlot = FindSlotAt(x, y)
    local sourceSlot = drag.slot
    local defender = drag.defender

    if targetSlot ~= nil and targetSlot ~= sourceSlot then
        local target = game.defenders[targetSlot]
        if target == nil then
            game.defenders[targetSlot] = defender
            game.defenders[sourceSlot] = nil
            defender.slot = targetSlot
        elseif target.level == defender.level and target.level < 3 then
            local nextKind = target.kind == defender.kind and target.kind or RandomDefenderKind()
            game.defenders[targetSlot] = CreateDefender(nextKind, target.level + 1, targetSlot)
            game.defenders[sourceSlot] = nil
            local targetDefender = game.defenders[targetSlot]
            targetDefender.mergeTime = 0.65
            SpawnParticle(slotDefs[sourceSlot].x, slotDefs[sourceSlot].y - 18, 44, { 120, 230, 255 })
            SpawnParticle(slotDefs[targetSlot].x, slotDefs[targetSlot].y - 18, 64, { 255, 220, 100 })
            AddFloat(slotDefs[targetSlot].x, slotDefs[targetSlot].y - 55, "合体 " .. (target.level + 1), { 255, 230, 120 })
            if target.level + 1 == 3 then
                OpenClassEvent(nextKind)
            end
        else
            ShowToast("需要同等级且低于 3 级")
        end
    end

    drag = nil
end

function HandleKeyDown(eventType, eventData)
    local key = eventData:GetInt("Key")
    if key == KEY_R then
        ResetGame()
    end
end

function SummonDefender()
    if game.silver < game.summonCost then
        ShowToast("银币不足，召唤需要 " .. game.summonCost)
        return
    end
    local empty = {}
    for i = 1, #slotDefs do
        if game.defenders[i] == nil then
            table.insert(empty, i)
        end
    end
    if #empty == 0 then
        ShowToast("防线满了，先合并升级")
        return
    end

    local slot = empty[math.random(1, #empty)]
    game.silver = game.silver - game.summonCost
    game.summonCost = game.summonCost + 8
    game.defenders[slot] = CreateDefender(RandomDefenderKind(), 1, slot)
    AddFloat(slotDefs[slot].x, slotDefs[slot].y - 55, "召唤", { 120, 255, 220 })
end

function OpenEventBook()
    if game.silver < game.eventCost then
        ShowToast("银币不足，事件需要 " .. game.eventCost)
        return
    end
    game.silver = game.silver - game.eventCost
    game.eventCost = game.eventCost + 40
    game.eventChoices = BuildEventChoices(nil)
end

function OpenClassEvent(kind)
    game.eventChoices = BuildEventChoices(kind)
end

function BuildEventChoices(kind)
    local pool = {}
    for _, e in ipairs(events) do
        local eligible = false
        for _, role in ipairs(game.squad) do
            if IsEventForKind(e.id, role) then eligible = true end
        end
        if eligible and (kind == nil or IsEventForKind(e.id, kind)) then
            table.insert(pool, e)
        end
    end
    for _, role in ipairs(game.squad) do
        if Roster.extra[role] and (not kind or kind == role) and (game.rolePower[role] or 0) < 3 then
            local id = role
            pool[#pool + 1] = { id = id .. "_power", title = defenderTypes[id].name .. "强化",
                desc = "本局该职业普通攻击伤害 +10%，最多三次",
                apply = function() game.rolePower[id] = (game.rolePower[id] or 0) + 1 end }
        end
    end

    local choices = {}
    local used = {}
    while #choices < 3 and #choices < #pool do
        local idx = math.random(1, #pool)
        if not used[idx] then
            used[idx] = true
            table.insert(choices, pool[idx])
        end
    end
    return choices
end

function IsEventForKind(id, kind)
    if kind == "archer" then
        return id == "arrow_explosion" or id == "arrow_pierce" or id == "attack_speed" or id == "attack_up"
    elseif kind == "healer" then
        return id == "healer_speed" or id == "healer_attack" or id == "wall_fortify" or id == "attack_speed"
    elseif kind == "mage" then
        return id == "frost_damage" or id == "frost_area" or id == "deep_freeze" or id == "attack_up"
    end
    return id == "attack_up" or id == "attack_speed" or id == "wall_fortify"
end

function ApplyEventChoice(index)
    local choice = game.eventChoices[index]
    if choice ~= nil then
        choice.apply()
        ShowToast("获得：" .. choice.title)
    end
    game.eventChoices = nil
end

function CreateDefender(kind, level, slot)
    return {
        kind = kind,
        level = level,
        slot = slot,
        cooldown = 0.2,
        action = nil,
        actionTime = 0,
        actionDuration = 0,
        actionInterval = 0,
        actionReleased = false,
        actionTarget = nil,
        buffTime = 0,
        buffAttack = 0,
        buffSpeed = 0,
        buffSource = nil,
        mergeTime = 0,
        rage = 0,
        ultimateFlash = 0,
    }
end

function RandomDefenderKind()
    return game.squad[math.random(1, #game.squad)]
end

function dragDefender()
    return drag and drag.defender or nil
end

function ShowToast(text)
    toast.text = text
    toast.time = 1.4
end

function GetHomeSafeInsets(height)
    local insets = { left = 0, top = 0, right = 0, bottom = 0 }
    if GetSafeAreaInsets then
        local rect = GetSafeAreaInsets(false)
        if rect then
            insets.left, insets.top = rect.min.x, rect.min.y
            insets.right, insets.bottom = rect.max.x, rect.max.y
        end
    end
    if sdk and sdk.GetNativeExitMenuRect then
        local menu = sdk:GetNativeExitMenuRect()
        if menu then insets.top = math.max(insets.top, menu.bottom * height) end
    end
    if insets.top > 0 then insets.top = insets.top + 8 end
    return insets
end

function RebuildLayout(width, height, safeOverride)
    local isHome = game and game.state == "home"
    local safe = safeOverride or (isHome and GetHomeSafeInsets(height) or { left = 0, top = 0, right = 0, bottom = 0 })
    local availableW = math.max(1, width - safe.left - safe.right)
    local availableH = math.max(1, height - safe.top - safe.bottom)
    local scale = math.min(availableW / DESIGN_W, availableH / DESIGN_H)
    local drawW = DESIGN_W * scale
    local drawH = DESIGN_H * scale
    local dx = safe.left + (availableW - drawW) * 0.5
    local dy = (height - drawH) * 0.5
    if isHome then dy = safe.top end
    local homeBottom = availableH / scale
    local homeLeft = (safe.left - dx) / scale
    local homeWidth = availableW / scale
    local debugSafe=isHome and safe or GetHomeSafeInsets(height)
    if not isHome then
        debugSafe.left=math.max(debugSafe.left,dx)
        debugSafe.right=math.max(debugSafe.right,width-dx-drawW)
        debugSafe.top=math.max(debugSafe.top,dy)
    end
    layout = {
        scale = scale,
        dx = dx,
        dy = dy,
        drawW = drawW,
        drawH = drawH,
        safeTop = safe.top,
        safeBottom = safe.bottom,
        safeLeft = safe.left,
        safeRight = safe.right,
        homeMode = isHome,
        debugBounds = BattleDebug.Bounds(width,height,debugSafe),
        audioButton = {x=20,y=300,w=90,h=90},
        bookButton = { x = 18, y = 1455, w = 245, h = 185 },
        lordButton = { x = 340, y = 1450, w = 260, h = 190 },
        barracksButton = { x = 680, y = 1455, w = 245, h = 185 },
        homeStartButton = { x = 181, y = homeBottom - 350, w = 580, h = 116 },
        homeStageY = homeBottom * 0.59,
        homeGuardChoices = {
        },
        homeSquadToggle = { x = 251, y = homeBottom - 270, w = 440, h = 78 },
        homeLevelChoices = {
            { x = 273, y = 416, w = 132, h = 66 },
            { x = 405, y = 416, w = 132, h = 66 },
            { x = 537, y = 416, w = 132, h = 66 },
        },
        homeMapVisit = { x = 181, y = homeBottom - 350, w = 580, h = 116 },
        homeHomeButton = { x = homeLeft, y = homeBottom - 160, w = homeWidth / 4, h = 160 },
        homeGuardButton = { x = homeLeft + homeWidth / 4, y = homeBottom - 160, w = homeWidth / 4, h = 160 },
        homeMechaButton = { x = homeLeft + homeWidth / 2, y = homeBottom - 160, w = homeWidth / 4, h = 160 },
        homeMapButton = { x = homeLeft + homeWidth * 3 / 4, y = homeBottom - 160, w = homeWidth / 4, h = 160 },
        viewportWidth = width,
        viewportHeight = height,
        resultHomeButton = { x = 321, y = 855, w = 300, h = 70 },
    }
    for i = 1, #Roster.order do
        layout.homeGuardChoices[i] = { x = 66 + ((i - 1) % 3) * 278,
            y = homeBottom - 782 + math.floor((i - 1) / 3) * 148, w = 254, h = 134 }
    end
    layoutAge=0
end

function EnsureLayout(width,height)
    local isHome=game and game.state=="home"
    if not layout or layout.viewportWidth~=width or layout.viewportHeight~=height or layout.homeMode~=isHome then
        RebuildLayout(width,height)
    elseif isHome and layoutAge>=0.5 then
        local safe=GetHomeSafeInsets(height)
        layoutAge=0
        if safe.top~=layout.safeTop or safe.bottom~=layout.safeBottom or safe.left~=layout.safeLeft or safe.right~=layout.safeRight then
            RebuildLayout(width,height,safe)
        end
    end
end

function ToScreen(x, y)
    return layout.dx + x * layout.scale, layout.dy + y * layout.scale
end

function ScreenToDesign(x, y)
    if layout == nil then
        local graphics = GetGraphics()
        RebuildLayout(graphics:GetWidth(), graphics:GetHeight())
    end
    return (x - layout.dx) / layout.scale, (y - layout.dy) / layout.scale
end

function HitRect(x, y, r)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

function FindSlotAt(x, y)
    for i, s in ipairs(slotDefs) do
        local dx = x - s.x
        local dy = y - s.y
        if dx * dx + dy * dy <= 42 * 42 then return i end
    end
    return nil
end

function FindDefenderAt(x, y)
    local slot = FindSlotAt(x, y)
    if slot ~= nil and game.defenders[slot] ~= nil then return slot end
    return nil
end

function HitEventChoice(x, y)
    for i = 1, 3 do
        local r = { x = 120, y = 520 + (i - 1) * 175, w = 700, h = 130 }
        if HitRect(x, y, r) then return i end
    end
    return nil
end

function HandleRender(eventType, eventData)
    if nvgContext == nil then return end
    local graphics = GetGraphics()
    local width = graphics:GetWidth()
    local height = graphics:GetHeight()
    EnsureLayout(width, height)
    local debugStart=focused and game.state~="home" and BattleDebug.BeginRender() or nil

    nvgBeginFrame(nvgContext, width, height, 1.0)
    DrawScene(nvgContext, width, height)
    nvgEndFrame(nvgContext)
    BattleDebug.EndRender(debugStart,game,graphics,imagePaths,BattleAudio,appliedFps)
end

function DrawScene(ctx, width, height)
    DrawBackground(ctx, width, height)
    if game.loadingBattle then
        local ratio=(loadCursor-1)/math.max(1,#loadQueue)
        DrawText(ctx,"正在准备战场",471,730,32,{235,245,250},NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
        DrawBar(ctx,271,790,400,20,ratio,{90,210,215},math.floor(ratio*100).."%")
        BattleDebug.Draw(ctx,fontId,layout.debugBounds)
        return
    end
    if game.state == "home" then
        DrawHome(ctx)
        DrawToast(ctx)
        return
    end
    DrawWorldHud(ctx)
    DrawMonsters(ctx)
    DrawDefenders(ctx)
    DrawProjectiles(ctx)
    DrawIceBlasts(ctx)
    DrawParticles(ctx)
    CombatFX.Draw(ctx,game.combatFx,ToScreen,layout.scale)
    DrawBottomHud(ctx)
    DrawFloats(ctx)
    DrawEventModal(ctx)
    DrawStateOverlay(ctx)
    DrawToast(ctx)
    BattleDebug.Draw(ctx,fontId,layout.debugBounds)
end

function DrawBackground(ctx, width, height)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(10, 15, 25, 255))
    nvgFill(ctx)

    local img = (game.state == "home" or game.loadingBattle) and images.home_background or images.background
    if img ~= nil then
        if game.state == "home" or game.loadingBattle then
            local meta = imageMeta.home_background
            local cover = math.max(width / meta.w, height / meta.h)
            local w, h = meta.w * cover, meta.h * cover
            nvgBeginPath(ctx)
            nvgRect(ctx, 0, 0, width, height)
            nvgFillPaint(ctx, nvgImagePattern(ctx, (width - w) / 2, (height - h) / 2, w, h, 0, img, 1))
            nvgFill(ctx)
            return
        end
        nvgBeginPath(ctx)
        nvgRect(ctx, layout.dx, layout.dy, layout.drawW, layout.drawH)
        nvgFillPaint(ctx, nvgImagePattern(ctx, layout.dx, layout.dy, layout.drawW, layout.drawH, 0, img, 1))
        nvgFill(ctx)
    end
end

function DrawHome(ctx)
    local footerHeight = game.homeTab == "guards" and 770 or (game.homeTab == "mecha" and 460 or 370)
    DrawHomeBand(ctx, layout.homeHomeButton.y - footerHeight, footerHeight, { 28, 65, 67, 230 })
    DrawHomeHeader(ctx)
    if game.homeTab == "home" then
        DrawHomeMission(ctx)
        DrawHomeSquad(ctx)
        DrawHomeStartButton(ctx)
    elseif game.homeTab == "guards" then
        DrawHomeGuardsPage(ctx)
    elseif game.homeTab == "mecha" then
        DrawHomeMechaPage(ctx)
    else
        DrawHomeMapPage(ctx)
    end
    DrawHomeNav(ctx)
end

function DrawHomeHeader(ctx)
    local top = layout.safeTop / layout.scale
    DrawHomeBand(ctx, -top, 132 + top, { 28, 65, 67, 250 })
    DrawHomeArt(ctx, "commander", 82, 62, 100)
    DrawText(ctx, "星球防线", 150, 53, 32, { 250, 253, 249 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawText(ctx, "边境前哨", 151, 92, 24, { 190, 221, 208 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawHomeIcon(ctx, "orbit", "gold", 748, 63, 40)
    DrawText(ctx, "第一扇区", 890, 48, 25, { 250, 232, 183 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawText(ctx, "1-1", 890, 84, 24, { 250, 253, 249 }, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
end

function DrawHomeBand(ctx, y, h, color)
    local _, sy = ToScreen(0, y)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, sy, layout.viewportWidth, h * layout.scale)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgFill(ctx)
end

function DrawHomeArt(ctx, id, x, y, size)
    local img, meta = images[id], imageMeta[id]
    if not img or not meta then return end
    local w, h = size, size
    if meta.w > meta.h then h = size * meta.h / meta.w else w = size * meta.w / meta.h end
    local sx, sy = ToScreen(x - w / 2, y - h / 2)
    nvgBeginPath(ctx)
    nvgRect(ctx, sx, sy, w * layout.scale, h * layout.scale)
    nvgFillPaint(ctx, nvgImagePattern(ctx, sx, sy, w * layout.scale, h * layout.scale, 0, img, 1))
    nvgFill(ctx)
end

function DrawHomeIcon(ctx, id, tone, x, y, size)
    DrawHomeArt(ctx, "icon_" .. id .. "_" .. tone, x, y, size)
end

function DrawHomeHeading(ctx, kicker, title)
    DrawText(ctx, kicker, 471, 226, 28, { 34, 74, 76 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, title, 471, 300, 52, { 24, 58, 62 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawHomeMission(ctx)
    DrawHomeHeading(ctx, "第一章  /  边境裂隙", "裂隙先锋")
    DrawText(ctx, "守住前哨，迎击十波异星潮", 471, 364, 28, { 35, 77, 77 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawHomeSquad(ctx)
    local y = layout.homeStageY
    local bob = math.sin(game.time * 1.8) * 4
    local names = {}
    for i, id in ipairs(game.squad) do
        DrawRosterArt(ctx, id, 3, 471 + (i - (#game.squad + 1) / 2) * 235, y - 45 + bob, 270)
        names[#names + 1] = defenderTypes[id].name
    end
    local infoY = layout.homeStartButton.y - 76
    DrawText(ctx, #names > 0 and table.concat(names, " · ") or "尚未选择出征守卫", 471, infoY - 42, 26, { 248, 250, 245 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, "10 波进攻    /    1 位首领", 471, infoY, 26, { 186, 216, 201 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawHomeGuardsPage(ctx)
    local id = Roster.order[game.homeGuard]
    local selected = defenderTypes[id]
    DrawText(ctx, "守卫图鉴", 65, 190, 28, {35,77,77}, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    DrawText(ctx, "出征 " .. #game.squad .. "/3", 877, 190, 28, {35,77,77}, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    DrawText(ctx, selected.name, 471, 277, 42, {28,63,65}, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local descriptions = { archer="箭矢精准打击，三级追加范围伤害", mage="冰弹减速敌人，三级追加溅射伤害", healer="祝福队友，无目标时修复城墙" }
    DrawText(ctx, selected.desc or descriptions[id], 471, 345, 25, {35,77,77}, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for i, r in ipairs(layout.homeLevelChoices) do
        DrawHomeChoice(ctx, r, game.homeLevel == i)
        DrawText(ctx, ({ "I", "II", "III" })[i], r.x + r.w / 2, r.y + r.h / 2, 27,
            game.homeLevel == i and { 255, 255, 250 } or { 28, 63, 65 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
    local gridY = layout.homeGuardChoices[1].y
    local y = (490 + gridY - 60) / 2
    local artSize = math.min(285, gridY - 570)
    if game.homeLevel == 2 then
        DrawRosterArt(ctx, id, 1, 390, y, artSize * 0.8)
        DrawRosterArt(ctx, id, 1, 552, y, artSize * 0.8)
    else
        DrawRosterArt(ctx, id, game.homeLevel, 471, y, artSize)
    end
    DrawText(ctx, "终极 · " .. UltimateName(id), 471, gridY - 37, 26, {255,227,176}, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for i, r in ipairs(layout.homeGuardChoices) do
        DrawHomeChoice(ctx, r, game.homeGuard == i)
        local role = Roster.order[i]
        DrawRosterArt(ctx, role, 3, r.x + 52, r.y + 56, 91)
        DrawText(ctx, defenderTypes[role].name, r.x + 164, r.y + 47, 23,
            game.homeGuard == i and { 255, 255, 250 } or { 28, 63, 65 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        DrawText(ctx, Roster.Contains(game.squad, role) and "已出征" or "待命", r.x + 164, r.y + 89, 22,
            game.homeGuard == i and {255,227,176} or {65,92,86}, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
    local toggle = layout.homeSquadToggle
    DrawHomeChoice(ctx, toggle, true)
    DrawHomeIcon(ctx,"shield","gold",toggle.x+58,toggle.y+toggle.h/2,34)
    DrawText(ctx,Roster.Contains(game.squad,id) and "撤下守卫" or "加入出征",toggle.x+toggle.w/2+15,toggle.y+toggle.h/2,30,{255,235,183},NVG_ALIGN_CENTER+NVG_ALIGN_MIDDLE)
end

function DrawRosterArt(ctx, kind, level, x, y, size)
    if not Roster.extra[kind] then DrawHomeArt(ctx, kind .. level, x, y, size); return end
    local sx,sy = ToScreen(x,y)
    DrawExtraSprite(ctx,kind,sx,sy+size*layout.scale*0.42,size*layout.scale)
end

function DrawExtraSprite(ctx, kind, sx, sy, size)
    local img = images[kind .. "_standing"]
    if not img then return end
    -- All six sprites share the exported 128,234 foot anchor on a 256px canvas.
    local left,top = sx-size/2,sy-size*234/256
    nvgBeginPath(ctx)
    nvgRect(ctx,left,top,size,size)
    nvgFillPaint(ctx,nvgImagePattern(ctx,left,top,size,size,0,img,1))
    nvgFill(ctx)
end

function DrawHomeChoice(ctx, r, selected)
    local x, y = ToScreen(r.x, r.y)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, r.w * layout.scale, r.h * layout.scale, 8 * layout.scale)
    nvgFillColor(ctx, selected and nvgRGBA(35, 82, 77, 250) or nvgRGBA(243, 248, 244, 230))
    nvgFill(ctx)
end

function DrawHomeMechaPage(ctx)
    DrawHomeHeading(ctx, "领主机甲", "前哨守望者")
    DrawText(ctx, "原型机  /  待激活", 471, 364, 25, { 35, 77, 77 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawHomeArt(ctx, "commander", 471, layout.homeStageY - 140, 490)
    local y = layout.homeStartButton.y - 140
    for i, entry in ipairs({ { "shield", "城墙装甲" }, { "swords", "开局攻击" }, { "heart", "职业增幅" } }) do
        local x = 241 + (i - 1) * 230
        DrawHomeIcon(ctx, entry[1], "light", x, y - 70, 48)
        DrawText(ctx, entry[2], x, y - 15, 28, { 250, 252, 248 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
    DrawHomeIcon(ctx, "lock-keyhole", "gold", 471, layout.homeStartButton.y + 3, 36)
    DrawText(ctx, "成长系统尚未开放", 471, layout.homeStartButton.y + 56, 28, { 255, 226, 166 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawHomeMapPage(ctx)
    DrawHomeHeading(ctx, "星图航线", "第一扇区")
    DrawText(ctx, "边境裂隙", 471, 364, 25, { 35, 77, 77 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local y = layout.homeStageY
    local nodes = { { 340, y + 45, "1-1", "裂隙先锋" }, { 615, y - 210, "1-2", "失落浮岛" }, { 380, y - 455, "1-3", "星门守卫" } }
    nvgBeginPath(ctx)
    local sx, sy = ToScreen(nodes[1][1], nodes[1][2])
    nvgMoveTo(ctx, sx, sy)
    for i = 2, 3 do
        sx, sy = ToScreen(nodes[i][1], nodes[i][2])
        nvgLineTo(ctx, sx, sy)
    end
    nvgStrokeWidth(ctx, 6 * layout.scale)
    nvgStrokeColor(ctx, nvgRGBA(52, 100, 95, 190))
    nvgStroke(ctx)
    for i, p in ipairs(nodes) do
        DrawHomeRouteNode(ctx, p[1], p[2], p[3], p[4], i == 1)
    end
    DrawHomeAction(ctx, layout.homeMapVisit, "前往防线", "1-1  裂隙先锋")
end

function DrawHomeRouteNode(ctx, x, y, code, name, active)
    local sx, sy = ToScreen(x, y)
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy, 61 * layout.scale)
    nvgFillColor(ctx, active and nvgRGBA(226, 104, 78, 255) or nvgRGBA(234, 242, 234, 255))
    nvgFill(ctx)
    nvgStrokeWidth(ctx, 5 * layout.scale)
    nvgStrokeColor(ctx, nvgRGBA(38, 76, 72, 255))
    nvgStroke(ctx)
    DrawHomeIcon(ctx, active and "castle" or "lock-keyhole", active and "light" or "dark", x, y, 54)
    DrawHomeMapLabel(ctx, code .. "  " .. name, x, y + 91, 28)
    DrawHomeMapLabel(ctx, active and "10 波进攻" or "尚未开放", x, y + 130, 24)
end

function DrawHomeMapLabel(ctx, text, x, y, size)
    -- A light outline keeps map labels legible across terrain colors.
    for _, offset in ipairs({ { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }) do
        DrawText(ctx, text, x + offset[1], y + offset[2], size, { 245, 250, 238 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
    DrawText(ctx, text, x, y, size, { 24, 58, 62 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawHomeStartButton(ctx)
    DrawHomeAction(ctx, layout.homeStartButton, "开始防守", "1-1  裂隙先锋")
end

function DrawHomeAction(ctx, r, title, subtitle)
    local sx, sy = ToScreen(r.x, r.y)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy + 9 * layout.scale, r.w * layout.scale, r.h * layout.scale, 16 * layout.scale)
    nvgFillColor(ctx, nvgRGBA(113, 52, 43, 255))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy, r.w * layout.scale, r.h * layout.scale, 16 * layout.scale)
    nvgFillColor(ctx, nvgRGBA(235, 117, 82, 255))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(255, 191, 140, 255))
    nvgStrokeWidth(ctx, 3 * layout.scale)
    nvgStroke(ctx)
    DrawHomeIcon(ctx, "swords", "light", r.x + 83, r.y + 55, 48)
    DrawText(ctx, title, r.x + r.w * 0.5 + 20, r.y + 43, 36, { 255, 254, 243 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, subtitle, r.x + r.w * 0.5 + 20, r.y + 85, 26, { 255, 244, 227 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawHomeNav(ctx)
    DrawHomeBand(ctx, layout.homeHomeButton.y, 160 + layout.safeBottom / layout.scale, { 241, 246, 239, 255 })
    DrawHomeNavItem(ctx, layout.homeHomeButton, "home", "防线", "castle")
    DrawHomeNavItem(ctx, layout.homeGuardButton, "guards", "守卫", "shield")
    DrawHomeNavItem(ctx, layout.homeMechaButton, "mecha", "机甲", "bot")
    DrawHomeNavItem(ctx, layout.homeMapButton, "map", "星图", "orbit")
end

function DrawHomeNavItem(ctx, r, id, label, icon)
    local active = game.homeTab == id
    if active then
        local sx, sy = ToScreen(r.x + r.w * 0.5 - 47, r.y)
        nvgBeginPath(ctx)
        nvgRect(ctx, sx, sy, 94 * layout.scale, 7 * layout.scale)
        nvgFillColor(ctx, nvgRGBA(225, 105, 79, 255))
        nvgFill(ctx)
    end
    DrawHomeIcon(ctx, icon, "dark", r.x + r.w * 0.5, r.y + 53, active and 55 or 48)
    DrawText(ctx, label, r.x + r.w * 0.5, r.y + 110, 30, active and { 176, 67, 50 } or { 65, 92, 86 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawWorldHud(ctx)
    local r=layout.audioButton
    DrawHomeChoice(ctx,r,true)
    DrawHomeIcon(ctx,BattleAudio.muted and "volume-x" or "volume-2","light",r.x+r.w/2,r.y+r.h/2,46)
    if game.combo>=3 and game.comboTime>0 then
        DrawText(ctx,tostring(game.combo).." 连击",820,410,34,{255,225,100},NVG_ALIGN_RIGHT+NVG_ALIGN_MIDDLE)
    end
    DrawBar(ctx, 210, 1356, 520, 22, game.wallHp / game.wallMax, { 75, 210, 255 }, "城墙")
    DrawBar(ctx, 250, 1390, 440, 18, game.coreHp / 20, { 95, 255, 120 }, "星核")
end

function DrawBottomHud(ctx)
    DrawPill(ctx, 26, 1408, 238, 52, "银币 " .. game.silver, { 35, 42, 55, 210 }, { 255, 225, 130 })
    DrawPill(ctx, 28, 1473, 236, 46, "事件 " .. game.eventCost, { 20, 70, 90, 185 }, { 120, 235, 255 })
    DrawPill(ctx, 682, 1473, 232, 46, "召唤 " .. game.summonCost, { 20, 70, 90, 185 }, { 120, 235, 255 })
    local ready = GetReadyUltimate()
    local charging = GetHighestRageDefender()
    if ready ~= nil then
        DrawPill(ctx, 336, 1432, 270, 42, "终极: " .. UltimateName(ready.kind), { 110, 54, 22, 230 }, { 255, 230, 110 })
    elseif charging ~= nil then
        DrawPill(ctx, 336, 1432, 270, 42, "怒气 " .. math.floor(charging.rage) .. "/100", { 35, 72, 94, 210 }, { 160, 235, 255 })
    else
        DrawPill(ctx, 336, 1432, 270, 42, "终极: 三级击杀充能", { 35, 42, 55, 185 }, { 170, 200, 220 })
    end
    DrawPill(ctx, 342, 1482, 258, 40, "第 " .. game.wave .. "/" .. MAX_WAVES .. " 波", { 35, 42, 55, 185 }, { 255, 255, 255 })
end

function DrawBar(ctx, x, y, w, h, ratio, color, label)
    ratio = math.max(0, math.min(1, ratio))
    local sx, sy = ToScreen(x, y)
    local sw, sh = w * layout.scale, h * layout.scale
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy, sw, sh, sh * 0.5)
    nvgFillColor(ctx, nvgRGBA(20, 24, 35, 185))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy, sw * ratio, sh, sh * 0.5)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], 230))
    nvgFill(ctx)
    DrawText(ctx, label, x + w * 0.5, y + h * 0.5, 16, { 255, 255, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawPill(ctx, x, y, w, h, text, bg, fg)
    local sx, sy = ToScreen(x, y)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy, w * layout.scale, h * layout.scale, 12 * layout.scale)
    nvgFillColor(ctx, nvgRGBA(bg[1], bg[2], bg[3], bg[4]))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(120, 220, 255, 95))
    nvgStrokeWidth(ctx, 1.5 * layout.scale)
    nvgStroke(ctx)
    DrawText(ctx, text, x + w * 0.5, y + h * 0.5, 18, fg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawDefenders(ctx)
    for i, d in pairs(game.defenders) do
        if drag == nil or drag.defender ~= d then
            DrawDefender(ctx, d, slotDefs[i].x, slotDefs[i].y)
        end
    end
    if drag ~= nil then
        DrawDefender(ctx, drag.defender, drag.x, drag.y)
    end
end

function DrawDefender(ctx, d, x, y)
    local sx, sy = ToScreen(x, y)
    local size = (72 + d.level * 8) * layout.scale
    local img = images[d.kind .. d.level]
    local actionProgress = 0
    if d.action ~= nil and d.actionDuration > 0 then
        actionProgress = math.min(0.999, d.actionTime / d.actionDuration)
        if d.kind ~= "mage" and d.level ~= 2 then
            local frame = math.min(DEFENDER_ATTACK_FRAMES, math.floor(actionProgress * DEFENDER_ATTACK_FRAMES) + 1)
            img = images[d.kind .. "_attack_" .. d.level .. "_" .. frame] or img
        elseif d.kind == "mage" then
            local pulse = math.sin(actionProgress * math.pi)
            size = size * (1 + pulse * 0.035)
            sy = sy - pulse * 3 * layout.scale
        end
    end

    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy, 38 * layout.scale)
    local c = defenderTypes[d.kind].color
    nvgFillColor(ctx, nvgRGBA(c[1], c[2], c[3], d.buffTime > 0 and 120 or 70))
    nvgFill(ctx)

    if Roster.extra[d.kind] then
        if d.level == 2 then
            DrawExtraSprite(ctx,d.kind,sx-18*layout.scale,sy+12*layout.scale,size*0.78)
            DrawExtraSprite(ctx,d.kind,sx+18*layout.scale,sy+12*layout.scale,size*0.78)
        else DrawExtraSprite(ctx,d.kind,sx,sy+12*layout.scale,size) end
        if d.action then
            local pulse = math.sin(actionProgress * math.pi)
            nvgBeginPath(ctx)
            nvgCircle(ctx,sx,sy-size*0.42,(5+10*pulse)*layout.scale)
            nvgStrokeColor(ctx,nvgRGBA(c[1],c[2],c[3],math.floor(210*pulse)))
            nvgStrokeWidth(ctx,2*layout.scale)
            nvgStroke(ctx)
        end
    elseif d.level == 2 then
        DrawLevelTwoPair(ctx, d, sx, sy, size, actionProgress)
    elseif img ~= nil then
        DrawDefenderSprite(ctx, img, sx, sy, size)
    else
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy - 15 * layout.scale, 24 * layout.scale)
        nvgFillColor(ctx, nvgRGBA(c[1], c[2], c[3], 255))
        nvgFill(ctx)
    end

    if d.kind == "mage" and d.action ~= nil then
        DrawMageCastEffect(ctx, sx, sy, actionProgress, d.level)
    end

    if d.level == 3 then
        DrawEliteRing(ctx, sx, sy, d.mergeTime)
        DrawRageMeter(ctx, d, sx, sy)
    end
    if d.mergeTime > 0 then
        DrawMergeAura(ctx, sx, sy, d.mergeTime)
    end

    local levelLabel = d.level == 1 and "I" or (d.level == 2 and "II" or "III")
    DrawText(ctx, levelLabel, x + 34, y - 34, 15, { 255, 240, 150 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
end

function DrawRageMeter(ctx, d, sx, sy)
    local ratio = math.max(0, math.min(1, (d.rage or 0) / 100))
    local w = 62 * layout.scale
    local h = 6 * layout.scale
    local x = sx - w * 0.5
    local y = sy + 37 * layout.scale
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w, h, h * 0.5)
    nvgFillColor(ctx, nvgRGBA(17, 24, 38, 220))
    nvgFill(ctx)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, x, y, w * ratio, h, h * 0.5)
    nvgFillColor(ctx, nvgRGBA(255, 188, 70, 245))
    nvgFill(ctx)
    if ratio >= 1 then
        local pulse = 0.65 + math.sin(game.time * 12) * 0.35
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy - 38 * layout.scale, (8 + pulse * 5) * layout.scale)
        nvgFillColor(ctx, nvgRGBA(255, 220, 100, 190))
        nvgFill(ctx)
    end
end

function DrawDefenderSprite(ctx, img, sx, sy, size)
    nvgBeginPath(ctx)
    nvgRect(ctx, sx - size * 0.5, sy - size * 0.72, size, size)
    nvgFillPaint(ctx, nvgImagePattern(ctx, sx - size * 0.5, sy - size * 0.72, size, size, 0, img, 1))
    nvgFill(ctx)
end

function DrawLevelTwoPair(ctx, d, sx, sy, size, actionProgress)
    local leftImage = images[d.kind .. "1"]
    local rightImage = leftImage
    local pairSize = size * 0.76
    local offset = 18 * layout.scale
    if d.action ~= nil and d.kind ~= "mage" then
        local frame = math.min(DEFENDER_ATTACK_FRAMES, math.floor(actionProgress * DEFENDER_ATTACK_FRAMES) + 1)
        local delayedFrame = math.min(DEFENDER_ATTACK_FRAMES, (frame % DEFENDER_ATTACK_FRAMES) + 1)
        leftImage = images[d.kind .. "_attack_1_" .. frame] or leftImage
        rightImage = images[d.kind .. "_attack_1_" .. delayedFrame] or rightImage
    end
    DrawDefenderSprite(ctx, leftImage, sx - offset, sy + 2 * layout.scale, pairSize)
    DrawDefenderSprite(ctx, rightImage, sx + offset, sy - 3 * layout.scale, pairSize)
end

function DrawEliteRing(ctx, sx, sy, mergeTime)
    local pulse = mergeTime > 0 and 1 or (0.72 + math.sin(os.clock() * 3.2) * 0.12)
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy + 8 * layout.scale, 40 * layout.scale * pulse)
    nvgStrokeColor(ctx, nvgRGBA(255, 218, 90, 175))
    nvgStrokeWidth(ctx, 2 * layout.scale)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy + 8 * layout.scale, 31 * layout.scale * pulse)
    nvgStrokeColor(ctx, nvgRGBA(120, 235, 255, 110))
    nvgStrokeWidth(ctx, 1.2 * layout.scale)
    nvgStroke(ctx)
end

function DrawMergeAura(ctx, sx, sy, remaining)
    local progress = 1 - remaining / 0.65
    local radius = (24 + progress * 42) * layout.scale
    local alpha = math.floor((1 - progress) * 210)
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy - 8 * layout.scale, radius)
    nvgStrokeColor(ctx, nvgRGBA(255, 238, 125, alpha))
    nvgStrokeWidth(ctx, (3 - progress * 1.5) * layout.scale)
    nvgStroke(ctx)
end

function DrawMageCastEffect(ctx, sx, sy, progress, level)
    local pulse = math.sin(progress * math.pi)
    local radius = (20 + level * 4 + pulse * 10) * layout.scale
    local alpha = math.floor(80 + pulse * 150)
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy - 12 * layout.scale, radius)
    nvgStrokeColor(ctx, nvgRGBA(130, 225, 255, alpha))
    nvgStrokeWidth(ctx, (1.5 + level * 0.5) * layout.scale)
    nvgStroke(ctx)
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy - (38 + pulse * 8) * layout.scale, (4 + level) * layout.scale)
    nvgFillColor(ctx, nvgRGBA(205, 250, 255, alpha))
    nvgFill(ctx)
end

function DrawMonsters(ctx)
    for _, m in ipairs(game.monsters) do
        local sx, sy = ToScreen(m.x, m.y)
        local size = m.radius * 2.3 * layout.scale
        local img = images["monster_" .. m.id]
        if m.id ~= "boss" then
            local frame = 1
            if m.animState == "attack" then
                local duration = monsterTypes[m.id].attackDuration
                local progress = math.min(0.999, m.animTime / duration)
                frame = math.min(MONSTER_ANIMATION_FRAMES, math.floor(progress * MONSTER_ANIMATION_FRAMES) + 1)
            else
                frame = math.floor(m.animTime / monsterTypes[m.id].walkFrameTime) % MONSTER_ANIMATION_FRAMES + 1
            end
            img = images["monster_" .. m.id .. "_" .. m.animState .. "_" .. frame] or img
        end
        if img ~= nil then
            nvgBeginPath(ctx)
            nvgRect(ctx, sx - size * 0.5, sy - size * 0.75, size, size)
            if (m.hitFlash or 0)>0 and nvgImagePatternTinted then
                nvgFillPaint(ctx,nvgImagePatternTinted(ctx,sx-size*0.5,sy-size*0.75,size,size,0,img,nvgRGBA(255,165,120,255)))
            else
                nvgFillPaint(ctx, nvgImagePattern(ctx, sx - size * 0.5, sy - size * 0.75, size, size, 0, img, 1))
            end
            nvgFill(ctx)
        else
            local c = monsterTypes[m.id].color
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, m.radius * layout.scale)
            nvgFillColor(ctx, nvgRGBA(c[1], c[2], c[3], 235))
            nvgFill(ctx)
        end

        if m.freezeTime > 0 then
            DrawFrozenShell(ctx, sx, sy, m.radius)
        end

        if m.hp<m.maxHp or m.id=="boss" then
        local hpRatio = math.max(0, m.hp / m.maxHp)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, sx - 28 * layout.scale, sy - 48 * layout.scale, 56 * layout.scale, 6 * layout.scale, 3 * layout.scale)
        nvgFillColor(ctx, nvgRGBA(20, 20, 25, 180))
        nvgFill(ctx)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, sx - 28 * layout.scale, sy - 48 * layout.scale, 56 * hpRatio * layout.scale, 6 * layout.scale, 3 * layout.scale)
        nvgFillColor(ctx, nvgRGBA(255, 90, 80, 230))
        nvgFill(ctx)
        end
    end
end

function DrawExtraProjectile(ctx,p,sx,sy)
    local c = defenderTypes[p.kind].color
    local scale = layout.scale
    local t = math.min(1,p.elapsed/p.duration)
    if p.kind == "bombardier" or p.kind == "alchemist" then
        sy = sy - math.sin(t*math.pi)*75*scale
        for tail=1,4 do
            local oldT=math.max(0,t-tail*0.05)
            local x,y=ToScreen(p.startX+(p.endX-p.startX)*oldT,p.startY+(p.endY-p.startY)*oldT)
            y=y-math.sin(oldT*math.pi)*75*scale
            nvgBeginPath(ctx); nvgCircle(ctx,x,y,(8-tail)*scale)
            nvgFillColor(ctx,nvgRGBA(c[1],c[2],c[3],100-tail*18)); nvgFill(ctx)
        end
        local tx,ty = ToScreen(p.endX,p.endY)
        nvgBeginPath(ctx); nvgCircle(ctx,tx,ty,(p.ultimate and 35 or 18)*scale)
        nvgStrokeColor(ctx,nvgRGBA(c[1],c[2],c[3],135)); nvgStrokeWidth(ctx,2*scale); nvgStroke(ctx)
    end
    if p.kind == "rail_sniper" then
        local x,y = ToScreen(p.startX,p.startY)
        nvgBeginPath(ctx); nvgMoveTo(ctx,x,y); nvgLineTo(ctx,sx,sy)
        nvgStrokeColor(ctx,nvgRGBA(c[1],c[2],c[3],65)); nvgStrokeWidth(ctx,(p.ultimate and 24 or 12)*scale); nvgStroke(ctx)
        nvgBeginPath(ctx); nvgMoveTo(ctx,x,y); nvgLineTo(ctx,sx,sy)
        nvgStrokeColor(ctx,nvgRGBA(c[1],c[2],c[3],230)); nvgStrokeWidth(ctx,(p.ultimate and 10 or 5)*scale); nvgStroke(ctx)
        nvgBeginPath(ctx); nvgMoveTo(ctx,x,y); nvgLineTo(ctx,sx,sy)
        nvgStrokeColor(ctx,nvgRGBA(255,250,240,250)); nvgStrokeWidth(ctx,2*scale); nvgStroke(ctx)
        return
    elseif p.kind == "stormcaller" then
        local x,y = ToScreen(p.startX,p.startY)
        nvgBeginPath(ctx); nvgMoveTo(ctx,x,y)
        for i=1,5 do nvgLineTo(ctx,x+(sx-x)*i/6+(i%2==0 and -9 or 9)*scale,y+(sy-y)*i/6) end
        nvgLineTo(ctx,sx,sy)
    elseif p.kind == "blade_dancer" then
        local r = (p.ultimate and 21 or 12)*scale
        nvgBeginPath(ctx)
        for i=0,8 do
            local a = p.elapsed*20+i*math.pi/6
            local x,y = sx+math.cos(a)*r,sy+math.sin(a)*r
            if i==0 then nvgMoveTo(ctx,x,y) else nvgLineTo(ctx,x,y) end
        end
    else
        local px,py = ToScreen(p.prevX,p.prevY)
        nvgBeginPath(ctx); nvgMoveTo(ctx,px,py); nvgLineTo(ctx,sx,sy)
    end
    nvgStrokeColor(ctx,nvgRGBA(c[1],c[2],c[3],240)); nvgStrokeWidth(ctx,(p.ultimate and 6 or 3)*scale); nvgStroke(ctx)
    if p.kind ~= "blade_dancer" then
        nvgBeginPath(ctx); nvgCircle(ctx,sx,sy,(p.ultimate and 11 or 6)*scale)
        nvgFillColor(ctx,nvgRGBA(c[1],c[2],c[3],255)); nvgFill(ctx)
    end
end

function DrawProjectiles(ctx)
    for _, zone in ipairs(game.acidZones) do
        local x,y = ToScreen(zone.x,zone.y)
        nvgBeginPath(ctx); nvgCircle(ctx,x,y,160*layout.scale)
        nvgFillColor(ctx,nvgRGBA(194,238,83,28)); nvgFill(ctx)
        nvgStrokeColor(ctx,nvgRGBA(194,238,83,135)); nvgStrokeWidth(ctx,2*layout.scale); nvgStroke(ctx)
    end
    for _, p in ipairs(game.projectiles) do
        if (p.delay or 0)<=0 then
        local sx, sy = ToScreen(p.x, p.y)
        local psx, psy = ToScreen(p.prevX, p.prevY)
        local dx, dy = sx - psx, sy - psy
        local length = math.max(0.001, math.sqrt(dx * dx + dy * dy))
        local ux, uy = dx / length, dy / length

        if p.extra then
            DrawExtraProjectile(ctx,p,sx,sy)
        elseif p.kind == "star_arrow" then
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - ux * 74 * layout.scale, sy - uy * 74 * layout.scale)
            nvgLineTo(ctx, sx, sy)
            nvgStrokeColor(ctx, nvgRGBA(255, 185, 55, 120))
            nvgStrokeWidth(ctx, 15 * layout.scale)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - ux * 62 * layout.scale, sy - uy * 62 * layout.scale)
            nvgLineTo(ctx, sx, sy)
            nvgStrokeColor(ctx, nvgRGBA(255, 240, 160, 255))
            nvgStrokeWidth(ctx, 7 * layout.scale)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 10 * layout.scale)
            nvgFillColor(ctx, nvgRGBA(255, 250, 205, 255))
            nvgFill(ctx)
        elseif p.kind == "arrow" then
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - ux * 24 * layout.scale, sy - uy * 24 * layout.scale)
            nvgLineTo(ctx, sx, sy)
            nvgStrokeColor(ctx, nvgRGBA(255, 225, 105, 245))
            nvgStrokeWidth(ctx, 3 * layout.scale)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 4.5 * layout.scale)
            nvgFillColor(ctx, nvgRGBA(255, 245, 175, 255))
            nvgFill(ctx)
        elseif p.kind == "frost" then
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - ux * 30 * layout.scale, sy - uy * 30 * layout.scale)
            nvgLineTo(ctx, sx, sy)
            nvgStrokeColor(ctx, nvgRGBA(80, 205, 255, 165))
            nvgStrokeWidth(ctx, 7 * layout.scale)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 8 * layout.scale)
            nvgFillColor(ctx, nvgRGBA(175, 245, 255, 245))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(75, 165, 255, 255))
            nvgStrokeWidth(ctx, 2 * layout.scale)
            nvgStroke(ctx)
        else
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx - ux * 22 * layout.scale, sy - uy * 22 * layout.scale)
            nvgLineTo(ctx, sx, sy)
            nvgStrokeColor(ctx, nvgRGBA(145, 255, 115, 145))
            nvgStrokeWidth(ctx, 6 * layout.scale)
            nvgStroke(ctx)
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, 7 * layout.scale)
            nvgFillColor(ctx, nvgRGBA(225, 255, 145, 245))
            nvgFill(ctx)
        end
        end
    end
end

function DrawIceBlasts(ctx)
    for _, blast in ipairs(game.iceBlasts) do
        local progress = 1 - blast.life / blast.maxLife
        local sx, sy = ToScreen(blast.x, blast.y)
        local radius = (18 + blast.radius * progress) * layout.scale
        local alpha = math.floor(190 * (1 - progress))
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy, radius)
        nvgFillColor(ctx, nvgRGBA(105, 225, 255, math.floor(alpha * 0.24)))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(185, 250, 255, alpha))
        nvgStrokeWidth(ctx, (5 - progress * 3) * layout.scale)
        nvgStroke(ctx)
        for shard = 0, 5 do
            local angle = shard * math.pi / 3 + progress * 0.35
            local ux, uy = math.cos(angle), math.sin(angle)
            local px, py = -uy, ux
            local inner = radius * 0.42
            local outer = radius * 0.96
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, sx + ux * outer, sy + uy * outer)
            nvgLineTo(ctx, sx + ux * inner + px * 10 * layout.scale, sy + uy * inner + py * 10 * layout.scale)
            nvgLineTo(ctx, sx + ux * inner - px * 10 * layout.scale, sy + uy * inner - py * 10 * layout.scale)
            nvgFillColor(ctx, nvgRGBA(190, 250, 255, math.floor(alpha * 0.78)))
            nvgFill(ctx)
        end
    end
end

function DrawFrozenShell(ctx, sx, sy, radius)
    local r = (radius + 10) * layout.scale
    nvgBeginPath(ctx)
    nvgCircle(ctx, sx, sy - 5 * layout.scale, r)
    nvgFillColor(ctx, nvgRGBA(100, 220, 255, 72))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(185, 250, 255, 220))
    nvgStrokeWidth(ctx, 2 * layout.scale)
    nvgStroke(ctx)
    for shard = 0, 3 do
        local angle = shard * math.pi * 0.5 + game.time * 0.7
        local ux, uy = math.cos(angle), math.sin(angle)
        local px, py = -uy, ux
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, sx + ux * r * 1.18, sy - 5 * layout.scale + uy * r * 1.18)
        nvgLineTo(ctx, sx + ux * r * 0.48 + px * 8 * layout.scale, sy - 5 * layout.scale + uy * r * 0.48 + py * 8 * layout.scale)
        nvgLineTo(ctx, sx + ux * r * 0.48 - px * 8 * layout.scale, sy - 5 * layout.scale + uy * r * 0.48 - py * 8 * layout.scale)
        nvgFillColor(ctx, nvgRGBA(190, 250, 255, 190))
        nvgFill(ctx)
    end
end

function DrawParticles(ctx)
    for _, p in ipairs(game.particles) do
        local a = math.floor(180 * (p.life / p.maxLife))
        local sx, sy = ToScreen(p.x, p.y)
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy, p.r * (1 - p.life / p.maxLife + 0.2) * layout.scale)
        nvgStrokeColor(ctx, nvgRGBA(p.color[1], p.color[2], p.color[3], a))
        nvgStrokeWidth(ctx, 3 * layout.scale)
        nvgStroke(ctx)
    end
end

function DrawFloats(ctx)
    for _, f in ipairs(game.floats) do
        local alpha = math.floor(255 * math.max(0, f.life / f.maxLife))
        DrawText(ctx, f.text, f.x, f.y, 22, { f.color[1], f.color[2], f.color[3], alpha }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    end
end

function DrawEventModal(ctx)
    if game.eventChoices == nil then return end
    local sx, sy = ToScreen(95, 460)
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, sx, sy, 752 * layout.scale, 620 * layout.scale, 24 * layout.scale)
    nvgFillColor(ctx, nvgRGBA(15, 22, 34, 235))
    nvgFill(ctx)
    nvgStrokeColor(ctx, nvgRGBA(120, 225, 255, 160))
    nvgStrokeWidth(ctx, 2 * layout.scale)
    nvgStroke(ctx)
    DrawText(ctx, "选择强化事件", 471, 505, 30, { 255, 255, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    for i, choice in ipairs(game.eventChoices) do
        local y = 520 + (i - 1) * 175
        local x = 120
        local rsx, rsy = ToScreen(x, y)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, rsx, rsy, 700 * layout.scale, 130 * layout.scale, 18 * layout.scale)
        nvgFillColor(ctx, nvgRGBA(28, 56, 78, 230))
        nvgFill(ctx)
        nvgStrokeColor(ctx, nvgRGBA(140, 240, 255, 130))
        nvgStrokeWidth(ctx, 1.5 * layout.scale)
        nvgStroke(ctx)
        DrawText(ctx, choice.title, x + 32, y + 38, 24, { 255, 235, 160 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
        DrawText(ctx, choice.desc, x + 32, y + 82, 18, { 220, 240, 255 }, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    end
end

function DrawStateOverlay(ctx)
    if game.state == "playing" then return end
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, GetGraphics():GetWidth(), GetGraphics():GetHeight())
    nvgFillColor(ctx, nvgRGBA(0, 0, 0, 150))
    nvgFill(ctx)
    local title = game.state == "victory" and "防守成功" or "星核失守"
    DrawText(ctx, title, 471, 680, 46, { 255, 255, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, "击杀 " .. game.kills .. "  余币 " .. game.silver, 471, 745, 22, { 220, 240, 255 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawText(ctx, "点击空白处再来一局", 471, 805, 22, { 255, 230, 140 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    DrawPill(ctx, 321, 855, 300, 70, "返回主页", { 24, 65, 85, 240 }, { 220, 250, 255 })
end

function DrawToast(ctx)
    if toast.time <= 0 then return end
    DrawPill(ctx, 230, 340, 482, 54, toast.text, { 20, 25, 35, 220 }, { 255, 240, 170 })
end

function DrawText(ctx, text, x, y, size, color, align)
    local sx, sy = ToScreen(x, y)
    if fontId ~= -1 then nvgFontFaceId(ctx, fontId) end
    nvgFontSize(ctx, size * layout.scale)
    nvgTextAlign(ctx, align)
    nvgFillColor(ctx, nvgRGBA(color[1], color[2], color[3], color[4] or 255))
    nvgText(ctx, sx, sy, text, nil)
end
