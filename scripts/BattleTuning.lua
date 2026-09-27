return {
    startingSilver = 500,
    maxMonsters = 80,
    volleyInterval = 0.08,
    rangedRangeBonus = 240,
    waveCount = function(wave) return wave==10 and 65 or 24+wave*4 end,
    packSize = function(wave) return wave>=6 and 4 or 3 end,
    packInterval = function(wave) return math.max(0.38,0.75-wave*0.03) end,
    swarmHealth = 0.42,
    swarmDamage = 0.10,
    swarmSilver = 4,
}
