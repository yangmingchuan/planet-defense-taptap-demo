require "LuaScripts/Utilities/Sample"

local UI = require("urhox-libs/UI")

local DESIGN_W = 942
local DESIGN_H = 1670
local MAX_WAVES = 10
local MONSTER_ANIMATION_FRAMES = 6
local DEFENDER_ATTACK_FRAMES = 6

local nvgContext = nil
local fontId = -1
local images = {}
local imageMeta = {}

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

local monsterTypes = {
    basic = { name = "小怪兽", hp = 55, speed = 58, defense = 0, damage = 1, silver = 12, color = { 80, 190, 100 }, walkFrameTime = 0.125, attackDuration = 0.85 },
    agile = { name = "敏捷怪兽", hp = 38, speed = 95, defense = 0, damage = 1, silver = 14, color = { 90, 235, 210 }, walkFrameTime = 0.083, attackDuration = 0.65 },
    tank = { name = "肉怪兽", hp = 165, speed = 38, defense = 0, damage = 2, silver = 30, color = { 180, 120, 210 }, walkFrameTime = 0.167, attackDuration = 1.15 },
    armored = { name = "甲壳怪兽", hp = 135, speed = 30, defense = 12, damage = 1, silver = 34, color = { 210, 175, 88 }, walkFrameTime = 0.250, attackDuration = 1.30 },
    boss = { name = "星核破坏者", hp = 900, speed = 26, defense = 8, damage = 5, silver = 120, color = { 210, 95, 70 }, walkFrameTime = 0.180, attackDuration = 1.40 },
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

    local graphics = GetGraphics()
    graphics:SetMode(450, 800)
    graphics.windowTitle = "星球防线"

    SampleStart()
    SampleInitMouseMode(MM_FREE)

    nvgContext = nvgCreate(1)
    if nvgContext == nil then
        print("ERROR: Failed to create NanoVG context")
        return
    end

    fontId = nvgCreateFont(nvgContext, "sans", "Fonts/MiSans-Regular.ttf")
    LoadImages()
    ResetGame()

    SubscribeToEvent(nvgContext, "NanoVGRender", "HandleRender")
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("MouseButtonDown", "HandleMouseDown")
    SubscribeToEvent("MouseButtonUp", "HandleMouseUp")
    SubscribeToEvent("MouseMove", "HandleMouseMove")
    SubscribeToEvent("KeyDown", "HandleKeyDown")

    print("星球防线核心战斗页已启动")
end

function Stop()
    UI.Shutdown()
    if nvgContext ~= nil then
        for _, handle in pairs(images) do
            if handle ~= nil and handle ~= 0 then
                nvgDeleteImage(nvgContext, handle)
            end
        end
        nvgDelete(nvgContext)
        nvgContext = nil
    end
end

function LoadImage(id, path)
    local handle = nvgCreateImage(nvgContext, path, 0)
    if handle ~= nil and handle ~= 0 then
        images[id] = handle
        local w, h = nvgImageSize(nvgContext, handle)
        imageMeta[id] = { w = w or 1, h = h or 1 }
    else
        print("WARN: image load failed: " .. path)
    end
end

function LoadImages()
    LoadImage("background", "assets/image/scene/battle-background-v6.png")

    local map = {
        archer = "archer",
        healer = "healer",
        mage = "frost-mage",
    }
    for id, folder in pairs(map) do
        for level = 1, 3 do
            LoadImage(id .. level, "assets/image/defenders/" .. folder .. "/level-" .. level .. ".png")
            for frame = 1, DEFENDER_ATTACK_FRAMES do
                local key = id .. "_attack_" .. level .. "_" .. frame
                local path = string.format("assets/image/defenders/%s/attack/level-%d-%02d.png", folder, level, frame)
                LoadImage(key, path)
            end
        end
    end

    for _, id in ipairs({ "basic", "agile", "tank", "armored" }) do
        LoadImage("monster_" .. id, "assets/image/monsters/" .. id .. "/portrait-v1.png")
        for frame = 1, MONSTER_ANIMATION_FRAMES do
            LoadImage("monster_" .. id .. "_walk_" .. frame, string.format("assets/image/monsters/%s/walk/%02d.png", id, frame))
            LoadImage("monster_" .. id .. "_attack_" .. frame, string.format("assets/image/monsters/%s/attack/%02d.png", id, frame))
        end
    end
end

function ResetGame()
    game = {
        state = "playing",
        silver = 80,
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
        eventChoices = nil,
        selectedDefender = nil,
        wallMax = 30,
        wallHp = 30,
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

function HandleUpdate(eventType, eventData)
    local dt = eventData:GetFloat("TimeStep")
    if dt > 0.05 then dt = 0.05 end
    game.time = game.time + dt
    toast.time = math.max(0, toast.time - dt)

    if game.state == "playing" then
        UpdateWave(dt)
        UpdateMonsters(dt)
        UpdateDefenders(dt)
        UpdateProjectiles(dt)
        UpdateEffects(dt)
        CheckEndState()
    else
        UpdateEffects(dt)
    end
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

    if game.spawnRemaining > 0 then
        game.spawnTimer = game.spawnTimer - dt
        if game.spawnTimer <= 0 then
            game.spawnTimer = math.max(0.35, 1.0 - game.wave * 0.04)
            SpawnMonsterForWave()
            game.spawnRemaining = game.spawnRemaining - 1
        end
    end
end

function StartNextWave()
    game.wave = game.wave + 1
    game.spawnRemaining = 4 + game.wave * 2
    game.spawnTimer = 0.1
    game.silver = game.silver + 20
    AddFloat(180, 1420, "+20 波次奖励", { 255, 230, 120 })
    if game.wave == 4 or game.wave == 8 then
        ShowToast("事件书籍可刷新强化，需要 " .. game.eventCost .. " 银币")
    end
end

function SpawnMonsterForWave()
    local id = "basic"
    if game.wave == 10 then
        id = "boss"
    elseif game.wave >= 7 and math.random() < 0.30 then
        id = "armored"
    elseif game.wave >= 5 and math.random() < 0.35 then
        id = "tank"
    elseif game.wave >= 3 and math.random() < 0.35 then
        id = "agile"
    end

    local src = monsterTypes[id]
    local x = 260 + math.random() * 420
    table.insert(game.monsters, {
        id = id,
        x = x,
        y = 250,
        hp = src.hp + game.wave * (id == "boss" and 28 or 5),
        maxHp = src.hp + game.wave * (id == "boss" and 28 or 5),
        speed = src.speed,
        defense = src.defense,
        damage = src.damage,
        silver = src.silver,
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
        if d ~= dragDefender() then
            d.buffTime = math.max(0, (d.buffTime or 0) - dt)
            if d.buffTime <= 0 then
                d.buffAttack = 0
                d.buffSpeed = 0
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
    local speedBonus = 1 + game.bonuses.attackSpeed + (d.buffSpeed or 0)
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
    if d.kind == "healer" then
        if d.actionTarget ~= nil and IsDefenderActive(d.actionTarget) then
            CreateProjectile("blessing", start.x, start.y - 35, d.actionTarget, {
                level = d.level,
                duration = 4.0 + d.level * 0.6,
                attack = 0.10 + game.bonuses.healerAttack,
                speed = 0.10 + game.bonuses.healerSpeed,
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

    if d.kind == "archer" then
        local dmg = defenderTypes.archer.attack[d.level] + game.bonuses.attackFlat
        dmg = dmg * (1 + (d.buffAttack or 0))
        CreateProjectile("arrow", start.x, start.y - 35, target, {
            damage = dmg,
            explosion = game.bonuses.archerExplosion > 0 and math.random() < game.bonuses.archerExplosion,
            pierce = d.level == 3 or game.bonuses.archerPierce > 0,
        })
    elseif d.kind == "mage" then
        local dmg = (defenderTypes.mage.attack[d.level] + game.bonuses.attackFlat) * (1 + game.bonuses.mageDamage)
        CreateProjectile("frost", start.x, start.y - 35, target, {
            damage = dmg,
            level = d.level,
            slowTime = 1.6 + d.level * 0.25,
            slowRatio = math.min(0.75, defenderTypes.mage.slow[d.level] + 0.05),
            freeze = math.random() < game.bonuses.freezeChance,
        })
    end
end

function FindTarget(d)
    local best = nil
    local bestY = -99999
    local sx = slotDefs[d.slot].x
    local sy = slotDefs[d.slot].y
    local range = defenderTypes[d.kind].range
    for _, m in ipairs(game.monsters) do
        local dx = m.x - sx
        local dy = m.y - sy
        if dx * dx + dy * dy <= range * range and m.y > bestY then
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

function DamageMonster(m, amount, damageType)
    if m == nil or m.dead then return false end
    local final = math.max(1, amount - (damageType == "physical" and m.defense or m.defense * 0.5))
    m.hp = m.hp - final
    if m.hp <= 0 then
        KillMonster(m)
        return true
    end
    return false
end

function AreaDamage(x, y, radius, amount)
    for i = #game.monsters, 1, -1 do
        local m = game.monsters[i]
        local dx, dy = m.x - x, m.y - y
        if dx * dx + dy * dy <= radius * radius then
            DamageMonster(m, amount, "magic")
        end
    end
    SpawnParticle(x, y, radius, { 255, 160, 70 })
end

function AreaSlow(x, y, radius, amount)
    for i = #game.monsters, 1, -1 do
        local m = game.monsters[i]
        local dx, dy = m.x - x, m.y - y
        if dx * dx + dy * dy <= radius * radius then
            DamageMonster(m, amount, "magic")
            if not m.dead then
                m.slowTime = math.max(m.slowTime, 1.2)
                m.slowRatio = math.max(m.slowRatio, 0.35)
            end
        end
    end
    SpawnParticle(x, y, radius, { 90, 220, 255 })
end

function KillMonster(monster)
    if monster == nil or monster.dead then return end
    monster.dead = true
    for i = #game.monsters, 1, -1 do
        if game.monsters[i] == monster then
            table.remove(game.monsters, i)
            game.silver = game.silver + monster.silver
            game.kills = game.kills + 1
            AddFloat(monster.x, monster.y - 25, "+" .. monster.silver, { 255, 230, 120 })
            SpawnParticle(monster.x, monster.y, 45, { 255, 230, 120 })
            return
        end
    end
end

function UpdateProjectiles(dt)
    for i = #game.projectiles, 1, -1 do
        local p = game.projectiles[i]
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

function CreateProjectile(kind, x, y, target, payload)
    local speed = kind == "arrow" and 1050 or (kind == "frost" and 720 or 560)
    table.insert(game.projectiles, {
        kind = kind,
        x = x,
        y = y,
        prevX = x,
        prevY = y,
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
            local slot = slotDefs[target.slot]
            AddFloat(slot.x, slot.y - 52, "祝福", { 255, 230, 120 })
            SpawnParticle(slot.x, slot.y - 15, 58, { 155, 255, 105 })
        end
        return
    end

    local target = p.target
    if not IsMonsterAlive(target) then return end
    local x, y = target.x, target.y
    if p.kind == "arrow" then
        DamageMonster(target, payload.damage, "physical")
        if payload.explosion then
            AreaDamage(x, y, 75, payload.damage * 0.45)
        end
        if payload.pierce then
            AreaDamage(x, y - 90, 55, payload.damage * 0.35)
        end
        SpawnParticle(x, y, payload.explosion and 75 or 24, payload.explosion and { 255, 160, 70 } or { 170, 255, 120 })
    elseif p.kind == "frost" then
        DamageMonster(target, payload.damage, "magic")
        if IsMonsterAlive(target) then
            target.slowTime = payload.slowTime
            target.slowRatio = payload.slowRatio
            if payload.freeze then
                target.freezeTime = target.id == "boss" and 0.35 or 0.9
                AddFloat(x, y - 30, "冻结", { 150, 230, 255 })
            end
        end
        if payload.level == 3 then
            AreaSlow(x, y, 75 + game.bonuses.mageArea, payload.damage * 0.40)
        else
            SpawnParticle(x, y, 36, { 90, 220, 255 })
        end
    end
end

function SpawnParticle(x, y, r, color)
    table.insert(game.particles, { x = x, y = y, r = r, color = color, life = 0.35, maxLife = 0.35 })
end

function AddFloat(x, y, text, color)
    table.insert(game.floats, { x = x, y = y, text = text, color = color, life = 1.0, maxLife = 1.0 })
end

function UpdateEffects(dt)
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
end

function CheckEndState()
    if game.coreHp <= 0 then
        game.state = "defeat"
    end
end

function HandleMouseDown(eventType, eventData)
    local button = eventData:GetInt("Button")
    if button ~= MOUSEB_LEFT then return end

    local sx, sy = eventData:GetInt("X"), eventData:GetInt("Y")
    local x, y = ScreenToDesign(sx, sy)
    mouse.x, mouse.y = x, y

    if game.eventChoices ~= nil then
        local picked = HitEventChoice(x, y)
        if picked ~= nil then
            ApplyEventChoice(picked)
        end
        return
    end

    if game.state ~= "playing" then
        ResetGame()
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
        if kind == nil or IsEventForKind(e.id, kind) then
            table.insert(pool, e)
        end
    end
    if #pool < 3 then pool = events end

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
    return true
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
    }
end

function RandomDefenderKind()
    local r = math.random()
    if r < 0.40 then return "archer" end
    if r < 0.75 then return "mage" end
    return "healer"
end

function dragDefender()
    return drag and drag.defender or nil
end

function ShowToast(text)
    toast.text = text
    toast.time = 1.4
end

function RebuildLayout(width, height)
    local scale = math.min(width / DESIGN_W, height / DESIGN_H)
    local drawW = DESIGN_W * scale
    local drawH = DESIGN_H * scale
    local dx = (width - drawW) * 0.5
    local dy = (height - drawH) * 0.5
    layout = {
        scale = scale,
        dx = dx,
        dy = dy,
        drawW = drawW,
        drawH = drawH,
        bookButton = { x = 18, y = 1455, w = 245, h = 185 },
        lordButton = { x = 340, y = 1450, w = 260, h = 190 },
        barracksButton = { x = 680, y = 1455, w = 245, h = 185 },
    }
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
    RebuildLayout(width, height)

    nvgBeginFrame(nvgContext, width, height, 1.0)
    DrawScene(nvgContext, width, height)
    nvgEndFrame(nvgContext)
end

function DrawScene(ctx, width, height)
    DrawBackground(ctx, width, height)
    DrawWorldHud(ctx)
    DrawMonsters(ctx)
    DrawDefenders(ctx)
    DrawProjectiles(ctx)
    DrawParticles(ctx)
    DrawBottomHud(ctx)
    DrawFloats(ctx)
    DrawEventModal(ctx)
    DrawStateOverlay(ctx)
    DrawToast(ctx)
end

function DrawBackground(ctx, width, height)
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, width, height)
    nvgFillColor(ctx, nvgRGBA(10, 15, 25, 255))
    nvgFill(ctx)

    local img = images.background
    if img ~= nil then
        nvgBeginPath(ctx)
        nvgRect(ctx, layout.dx, layout.dy, layout.drawW, layout.drawH)
        nvgFillPaint(ctx, nvgImagePattern(ctx, layout.dx, layout.dy, layout.drawW, layout.drawH, 0, img, 1))
        nvgFill(ctx)
    end
end

function DrawWorldHud(ctx)
    DrawBar(ctx, 210, 1356, 520, 22, game.wallHp / game.wallMax, { 75, 210, 255 }, "城墙")
    DrawBar(ctx, 250, 1390, 440, 18, game.coreHp / 20, { 95, 255, 120 }, "星核")
end

function DrawBottomHud(ctx)
    DrawPill(ctx, 26, 1408, 238, 52, "银币 " .. game.silver, { 35, 42, 55, 210 }, { 255, 225, 130 })
    DrawPill(ctx, 28, 1473, 236, 46, "事件 " .. game.eventCost, { 20, 70, 90, 185 }, { 120, 235, 255 })
    DrawPill(ctx, 682, 1473, 232, 46, "召唤 " .. game.summonCost, { 20, 70, 90, 185 }, { 120, 235, 255 })
    DrawPill(ctx, 336, 1432, 270, 42, "领主机甲", { 35, 42, 55, 185 }, { 220, 235, 255 })
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
        if d.kind ~= "mage" then
            local frame = math.min(DEFENDER_ATTACK_FRAMES, math.floor(actionProgress * DEFENDER_ATTACK_FRAMES) + 1)
            img = images[d.kind .. "_attack_" .. d.level .. "_" .. frame] or img
        else
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

    if img ~= nil then
        nvgBeginPath(ctx)
        nvgRect(ctx, sx - size * 0.5, sy - size * 0.72, size, size)
        nvgFillPaint(ctx, nvgImagePattern(ctx, sx - size * 0.5, sy - size * 0.72, size, size, 0, img, 1))
        nvgFill(ctx)
    else
        nvgBeginPath(ctx)
        nvgCircle(ctx, sx, sy - 15 * layout.scale, 24 * layout.scale)
        nvgFillColor(ctx, nvgRGBA(c[1], c[2], c[3], 255))
        nvgFill(ctx)
    end

    if d.kind == "mage" and d.action ~= nil then
        DrawMageCastEffect(ctx, sx, sy, actionProgress, d.level)
    end

    DrawText(ctx, tostring(d.level), x + 34, y - 34, 17, { 255, 240, 150 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
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
            nvgFillPaint(ctx, nvgImagePattern(ctx, sx - size * 0.5, sy - size * 0.75, size, size, 0, img, 1))
            nvgFill(ctx)
        else
            local c = monsterTypes[m.id].color
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy, m.radius * layout.scale)
            nvgFillColor(ctx, nvgRGBA(c[1], c[2], c[3], 235))
            nvgFill(ctx)
        end

        if m.freezeTime > 0 then
            nvgBeginPath(ctx)
            nvgCircle(ctx, sx, sy - 5 * layout.scale, (m.radius + 8) * layout.scale)
            nvgFillColor(ctx, nvgRGBA(100, 220, 255, 65))
            nvgFill(ctx)
            nvgStrokeColor(ctx, nvgRGBA(170, 245, 255, 210))
            nvgStrokeWidth(ctx, 2 * layout.scale)
            nvgStroke(ctx)
        end

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

function DrawProjectiles(ctx)
    for _, p in ipairs(game.projectiles) do
        local sx, sy = ToScreen(p.x, p.y)
        local psx, psy = ToScreen(p.prevX, p.prevY)
        local dx, dy = sx - psx, sy - psy
        local length = math.max(0.001, math.sqrt(dx * dx + dy * dy))
        local ux, uy = dx / length, dy / length

        if p.kind == "arrow" then
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
    DrawText(ctx, "点击任意位置再来一局", 471, 805, 22, { 255, 230, 140 }, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
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
