# 新角色程序接入契约

版本：2026-09-27。状态：目标接口设计，以下配置与模块均未接入当前项目，不是可运行代码。

## 1. 当前落点

`scripts/main.lua` 中的 `defenderTypes`、`events`、`RandomDefenderKind`、`LoadImages`、`BeginDefenderAction`、`UpdateDefenderAction`、`ResolveProjectile`、`DamageMonster`、`KillMonster`、`GainRage`、`CastReadyUltimate`、`DrawDefender` 与首页图鉴是新增角色需要审计的边界。不能只补一张图片和一行名字。

先覆盖回归测试，再逐步抽出角色配置和行为处理。不要在现有 archer/mage/healer 的条件分支中偷偷复用新的roleId；稳定ID必须贯穿召唤、升级、事件、伤害归属、资源与图鉴。

## 2. 目标配置结构（示意）

```lua
-- Proposed schema only. No such loader is implemented yet.
return {
    schemaVersion = 1,
    designVersion = "0.1",
    id = "bombardier",
    displayName = "爆破炮手",
    enabled = false,
    tags = { "damage", "area", "physical" },
    attack = {
        behavior = "lob_area",
        damage = { 16, 38, 68 },
        cooldown = { 2.30, 2.10, 1.90 },
        range = 490,
        radius = { 70, 80, 95 },
        targetCap = { 3, 3, 4 },
        secondaryMultiplier = 0.55,
        animationDuration = 0.48,
        releaseTime = 0.20,
        flightTime = 0.45,
        snapshotAtRelease = true,
    },
    levels = { max = 3, pairUsesLevelOne = true },
    awakening = { scope = "run_role", unlockLevel = 3, maxChoices = 1 },
    ultimate = { behavior = "fixed_area", rageCost = 100, damage = 125, radius = 170, targetCap = 6 },
    assets = { manifest = "assets/image/defenders/bombardier/manifest.json" },
}
```

所有伤害/冷却数组长度必须为3；冷却>0；概率0..1；targetCap为正整数；引用资源必须存在；enabled=false禁止召唤。计划中的机甲永久乘数单独命名，不复用当局事件bonus。

## 3. 实例、命中与奖励

| 数据 | 必填字段/规则 |
|---|---|
| 守卫 | unitId、roleId、level、slotId、cooldown、action、rage |
| 攻击实例 | attackId、sourceUnitId、sourceRoleId、sourceLevel、snapshotStats、origin、releaseTime |
| 弹道/区域 | 固定落点或目标ID、当前/上一位置、生命周期、命中集合、最大命中数 |
| 命中事件 | attackId、phaseId、targetId、damageType、rawDamage、armorIgnore、状态列表 |
| 持续状态 | statusId、sourceUnitId、tickDamage、nextTickAt、expiresAt、stackPolicy |
| 死亡 | target.dead守卫、killSource、银币与怒气一次性发放 |

属性在出手时快照，后续合成/强化不放大已经飞出的攻击。击杀来源为致死伤害实例；同帧按稳定实例顺序处理，不取最近一次给目标施法的角色。

来源被合成移除后：既有攻击继续按原快照结算；银币正常发放；不再给已删除单位或新合成单位补怒。原单位仍存在且快照等级为III时才按规则积怒。二级双人只绑定一个unitId。

命中键按 `(attackId, phaseId, targetId)` 去重。回旋的去/回是两个phase；炮手主爆/余爆是两个phase；普通雷链整条只有一个phase、同目标只中一次。DoT tick使用独立序号，但死亡奖励仍全局去重。

## 4. 护甲、状态与执行顺序

候选统一计算：`有效护甲=max(0,基础护甲-当前最强腐蚀)`；物理伤害 `max(1,raw-有效护甲×(1-ignore))`；魔法伤害 `max(1,raw-有效护甲×0.5)`。狙击穿甲不是全队减甲；腐蚀结束恢复原护甲。内部允许小数、UI伤害显示取整，禁止每跳先截断后再乘系数。

减速取最强，不相加；各来源保留自己的到期时间，强减速到期后可回退到仍有效的弱减速。冻结按独立状态处理，不让普通减速覆盖冻结。普通酸蚀同目标一个有效来源，强度/刷新规则见炼金师档案。

目标tick顺序提案：推进行动与移动 → 生成已跨过出手阈值的攻击 → 路径/区域命中 → 到点DoT → 死亡清理与奖励 → 状态到期。跨帧检测 `previousTime < eventTime <= currentTime`，不依赖帧图索引恰好等于3。

引力位移不更改怪物目标、不重置拆墙计时；已拆墙者免疫位移。边界clamp在合法道路/城墙前区内，零距离不归一化。每只怪记录拉拽免疫结束时间，不因来源不同绕过。

## 5. 素材目录与清单

建议新增目录（尚未创建）：

```text
assets/image/defenders/<role-id>/
  manifest.json
  level-1.png
  level-3.png
  portrait.png
  cover.png
  idle/level-1-01.png ... level-3-04.png
  attack/level-1-01.png ... level-3-06.png
  ultimate/cast-01.png ... cast-06.png
  projectile/01.png
  impact/01.png ... 06.png
  events/<event-id>.png
```

manifest至少记录：版本、画布尺寸、脚底锚点、发射点、帧路径、各帧时长、releaseTime、透明通道、素材来源/许可证。`role-id`文件夹沿用稳定ID；不要显示名改一次就重命名全部资源。

首次只加载当局三职业的战斗帧；图鉴缩略图单独加载，封面按需加载并有卸载策略。现有LoadImages全加载不能直接扩到九职业。图集、批处理与对象池必须实现和测量后才可声称存在。

## 6. 性能与可读性预算

以下是待实测目标，不是现有性能结论：选定两台真实手机，记录型号/系统/分辨率；100怪、10守卫、连续技能运行60秒，目标P95帧时≤33.3ms，另观察120秒内内存是否持续增长。项目没有设备基线前不承诺60fps。

- 每条雷链最多6目标；新角色普通弹道全场软预算40，超过时减少残影而不删伤害事件。
- 回旋普通刃每单位最多2枚；全场最多2个炼金终极区域；控制区的预算由逻辑拒绝施法而不是默默丢伤害。
- 可见装饰粒子初始软预算120；超过先删烟尘、碎片、次级光，不删预警、弹道和打击边界。
- 多目标查询先遍历当前敌人集并记录耗时，压力不足时不引入复杂空间索引；热点确认后再按网格优化。
- 256×256 RGBA一帧解码约0.25MiB；36帧约9MiB/角色，六角色约54MiB，未含图集冗余、GPU副本、封面和特效。PNG压缩后大小不等于内存占用。实际帧数按manifest求和，不拿示例作总预算。
- 动画共享纹理，实例仅保存播放时间；不得为每个单位复制PNG或每次射击创建新纹理。

## 7. 必测用例

目标在起手/飞行/命中前死亡；守卫在飞行途中合成；满格召唤不扣钱；未加载角色不可抽出；范围主目标不双重伤害；跳链无循环；回旋跨帧碰撞；DoT刷新不漏tick；首领免疫位移；同帧多弹只奖励一次；觉醒仅首次且后续三级继承；事件满级过滤；无目标释放不扣怒；长屏与短屏武器不越格；暂停/恢复无补发一整批攻击。

测试数据与结论落在对应角色档案末尾。上线时同步主PRD的“已实现”状态，但保留历史设计版本，避免未来模型把草案参数当现行代码。
