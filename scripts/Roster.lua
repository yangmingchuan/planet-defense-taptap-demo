local Roster = {}

Roster.order = { "archer", "mage", "healer", "bombardier", "stormcaller", "rail_sniper", "blade_dancer", "alchemist", "gravity_engineer" }
Roster.extra = {
    bombardier = { name = "爆破炮手", color = { 255, 158, 82 }, attack = {16,38,68}, cooldown = {2.3,2.1,1.9}, range = 490, skill = "晨星重炮", desc = "固定落点炮击，范围物理伤害", ultimate = 125, radius = 95, cap = 4, damageType = "physical" },
    stormcaller = { name = "链雷术士", color = {255,224,80}, attack = {8,19,34}, cooldown = {1.5,1.3,1.15}, range = 470, skill = "雷网过载", desc = "电流跳跃，依次打击不同敌人", ultimate = 75, radius = 155, cap = 3, damageType = "magic" },
    rail_sniper = { name = "破甲狙击手", color = {255,146,163}, attack = {24,58,105}, cooldown = {2.8,2.6,2.4}, range = 600, skill = "星轨穿甲", desc = "优先锁定高甲敌人，穿甲射击", ultimate = 190, radius = 28, cap = 3, damageType = "physical" },
    blade_dancer = { name = "回旋刃卫", color = {129,230,162}, attack = {10,24,44}, cooldown = {1.6,1.4,1.25}, range = 430, skill = "月轮风暴", desc = "月刃往返，沿路径命中敌人", ultimate = 80, radius = 24, cap = 3, damageType = "physical" },
    alchemist = { name = "酸蚀炼金师", color = {194,238,83}, attack = {4,10,18}, cooldown = {1.8,1.6,1.4}, range = 440, skill = "酸雨试剂", desc = "药瓶持续酸蚀，三级附加减甲", ultimate = 18, radius = 75, cap = 3, damageType = "magic" },
    gravity_engineer = { name = "引力工程师", color = {82,230,205}, attack = {7,16,28}, cooldown = {2,1.8,1.6}, range = 460, skill = "轨道汇聚", desc = "引力钉减速，三级周期聚怪", ultimate = 55, radius = 100, cap = 3, damageType = "magic" },
}

function Roster.Copy(team)
    local result = {}
    for _, id in ipairs(team) do result[#result + 1] = id end
    return result
end

function Roster.Contains(team, id)
    for i, value in ipairs(team) do if value == id then return i end end
end

function Roster.Valid(team)
    if type(team) ~= "table" or #team < 1 or #team > 3 then return false end
    local seen = {}
    for _, id in ipairs(team) do
        if not Roster.Contains(Roster.order, id) or seen[id] then return false end
        seen[id] = true
    end
    return true
end

return Roster
