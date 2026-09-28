# 星球防线 MVP 技术 PRD

版本：2026-09-27。业务依据：`mvp-product-prd.md`。本文记录实际架构、实现约束与技术欠账，防止将设想当成已实现系统。

本轮 [战斗表现增量](combat-feel-prd.md) 新增 `BattleTuning.lua`、`CombatFX.lua`、`BattleAudio.lua`，分别管理怪潮数值、限额视觉效果和复用音效声源。伤害仍由main.lua命中逻辑负责；音频通过独立Scene持有声源，停止游戏时释放，ResourceCache路径省略assets前缀。

2026-09-28启动与帧负载修正见 [性能优化记录](performance-optimization-2026-09-28.md)：首页按需加载、分帧战斗资源、布局缓存、前后台帧率与模拟暂停。以下旧段落中关于“启动加载全部资源”和旧回归命令的表述，以增量记录及当前代码为准。

战斗右上角新增可开关的 [Debug红字面板](battle-debug.md)，用于实际试玩时观测渲染回调间隔、逻辑/提交耗时、实体数量及内存；各项指标的统计范围和N/A边界见该文档。

新增角色的目标架构在 [角色实现契约](characters/implementation-contract.md)，完整契约仍是设计目标。2026-09-27本地已接入 [九角色编队原型](characters/squad-prototype-prd.md)：`scripts/Roster.lua`管理角色配置和编队校验；`main.lua`管理编队快照、额外弹道、酸蚀/聚拢和NanoVG绘制；与目标契约的差异见增量文档。

## 1. 技术栈与入口

- TapTap Maker 单机 Lua 游戏，入口 `scripts/main.lua`，构建参数 `entry=main.lua`、`scriptsPath=scripts`。
- 当前通过 NanoVG 绘制背景、精灵、弹道、HUD；引擎 Update 事件推进逻辑，NanoVGRender 绘制。
- `urhox-libs/UI` 已引用，但本项目现有页面由 raw NanoVG 绘制；后续改造 UI 需按项目引擎指南，不应声称已使用完整组件系统。
- 当前无 Web 前端框架、3D 人物、后端服务、数据库、账号钱包或持久存档。
- 正式 SDK/API 以项目 `engine-docs/` 与 Maker 工具为准。

## 2. 文件定位

| 路径 | 职责 |
|---|---|
| scripts/main.lua | 数据配置、状态、输入、模拟、渲染全集 |
| assets/image/home/home-background-v2.png | 明亮浮空前哨大厅背景；v1 保留作历史资产 |
| assets/image/home/commander-v1.png | 带透明通道的领主机甲立绘 |
| assets/image/home/icons/ | Lucide 0.468.0 栅格图标与许可证，启动时加载 |
| assets/image/scene/battle-background-v6.png | 战斗地图背景 |
| assets/image/defenders/ | 三职业等级立绘、攻击帧与生成提示词 |
| assets/image/monsters/ | 普通/敏捷/肉盾/甲壳的头像和 walk/attack 序列 |
| docs/mvp-product-prd.md | 当前产品验收基线 |
| docs/zombie-garden-prd.md | 历史方案，非全部已实现 |
| tests/home-navigation.lua | 使用 Lua 解释器执行导航与视口回归检查 |
| tests/render-home.lua / tests/render-home-proof.cjs | 真实首页绘制调用转 SVG/PNG，仅布局校样，不是引擎截图 |
| tests/prepare-home-icons.cjs | 固定版本图标下载/栅格化，依赖 Node 与 sharp，仅开发时运行 |

## 3. 状态与导航契约

`game.state`: home → playing → victory/defeat → home 或 playing。
`game.homeTab`: home / guards / mecha / map，只在首页参与路由。
`game.homeGuard`: 1/2/3；`game.homeLevel`: 1/2/3，默认为 1 和 3；只影响图鉴展示，ResetGame 重置，无存档。

- `Start` 加载资源后 `ResetGame("home")`。
- `ResetGame` 初始化本局数据并清空拖拽引用；不承担持久账号存档。
- `StartBattle` 调用 `ResetGame("playing")`。
- `HandleMouseDown` 先处理事件模态框，再处理首页 Tab、结算、战斗控件；首页只有 home Tab 的开始按钮有效。
- 图鉴热区为 `homeGuardChoices` 与 `homeLevelChoices`；星图 `homeMapVisit` 只返回 home，不直接开战。锁定节点无交互。
- `DrawScene` 首页早返回，不渲染战斗 HUD。`HandleUpdate` 首页不推进波次和战斗。
- 结算返回入口：`layout.resultHomeButton`；回主页后旧敌人、弹道与拖拽均清空。

## 4. 视口与输入

设计分辨率 942×1670；`layout.scale = min(width/942,height/1670)`。

战斗：等比 contain，dx/dy 居中，保持既有地图和格子坐标。首页：dy=0，顶栏物理宽度覆盖视口，背景 cover 允许裁边；内容仍以设计坐标绘制。

首页底栏：逻辑 bottom=height/scale，left=-dx/scale，width=width/scale；各 Tab 是 width/4，y=bottom-160。保证最左到物理 x=0、最右到 width、最底到 height。

新版首页：舞台中心 y=bottom×0.59，主按钮 y=bottom-350；图鉴选择区 y=bottom-490。绘制和命中共用矩形，不使用独立魔数计算触摸热区。`DrawHomeArt` 按图片真实宽高等比绘制；首页轻微浮动只改变视觉，不参与战斗模拟。

`ToScreen` 与 `ScreenToDesign` 互为逆变换。所有 Tab 绘制和输入共享 `layout` 矩形。

首页安全区修正：`GetHomeSafeInsets` 读取 `GetSafeAreaInsets(false)` 的物理像素边距，使用 `sdk:GetNativeExitMenuRect().bottom * height` 合并平台胶囊下沿，再加8像素间隙。仅首页使用可用安全宽高计算 scale/dx/dy；背景、顶栏底色和底栏底色仍延伸至屏幕边缘。顶部内容下移、底部热区避开手势条；每次重建布局重新读取，支持模拟器切换。API 不存在时边距为0。战斗保持原设计坐标，不受首页安全区变换影响。

## 5. 战斗对象与执行顺序

`game` 持有 monsters、defenders（按格索引）、projectiles、particles、floats、iceBlasts、ultimateQueue、bonuses。

Update 顺序：波次 → 怪物 → 守卫 → 弹道 → 特效 → 失败检查。dt 最大截断 0.05；此策略可能在低帧率时令游戏变慢，不能称为固定时间步模拟。

- 波次：`StartNextWave`、`SpawnMonsterForWave`，数量读取BattleTuning。第十波65次投放，spawnRemaining=1才投Boss；80只上限后等待位置，不丢弃投放。
- 攻击：`BeginDefenderAction` 锁定目标，`UpdateDefenderAction` 在动画 62% 时释放，`ResolveProjectile` 命中结算。
- 怪物攻击在攻击动画 58% 处扣墙；冻结暂停移动与出手。
- 伤害：`DamageMonster` → `KillMonster`。dead 防止重复死亡；死亡立即移除、发银币、怒气、飘字。
- AoE 逆序遍历可被删除的敌人数组。普通弹道目标先死亡会被丢弃，目前无重寻敌。
- 合成：`HandleMouseUp`，目标格保留，来源格清空。同类稳定晋级、异类走 `RandomDefenderKind`。
- 祝福来源通过 `buffSource` 保留；弹道通过 `payload.owner` 保留击杀归属。
- 大招：`GainRage` 入队、`GetReadyUltimate` 清理失效项、`CastReadyUltimate` 消耗满怒；施法中的击杀可再积怒，尚无终极专属冷却。

## 6. 渲染与资产约束

- `LoadImages` 启动时加载；渲染帧内不生成或加载文件。
- 四类怪物每类 6 walk + 6 attack，总 48 张动作图。Boss 暂时静态肉盾立绘。
- 三职业各 18 张攻击帧；法师为规避尺寸跳变，当前不切换攻击帧，使用稳定立绘加施法环。
- 二级双人渲染一级素材，战斗实体仍为一个；三级使用独立等级图。
- 图片须透明、统一脚底锚点和主体尺寸；补帧必须验证切换前后的大小及位置，不只验证文件存在。
- `DrawIceBlasts`、`DrawFrozenShell`、`DrawProjectiles` 是程序特效，不是新增序列图。
- 当前无图集批处理、对象池或空间索引；必须经性能测量再选择优化，不能以“使用帧图”直接断言 CPU 瓶颈。

## 7. 已知偏差与待处理项

| 问题 | 当前行为 | 后续要求 |
|---|---|---|
| 长线成长 | 只有展示页 | 设计 profile 存档版本、奖励去重、升级消费原子性后实现 |
| 初始银币 | 密集怪潮版本已改500 | 随随机编队难度继续验证经济 |
| 事件模态 | 弹窗时战斗继续 Update | 需产品决定是否暂停并做一致测试 |
| 强化叠加 | 部分概率可超过 100%，贯穿次数不增收益 | 定义上限、过滤已满级事件与说明文案 |
| 三级事件 | 每次合成三级都弹出 | 若改首次触发，增加职业标记与回归测试 |
| 祝福覆盖 | 普通祝福可能覆盖大招增益强度 | 明确优先级/来源/时效，避免较弱覆盖较强 |
| 终极箭 | 锁定目标爆炸，目标死亡会消失 | 贯穿路线与固定落点需单独定义碰撞算法 |
| 冰冻 | 立即伤害，冰环后扩张；现有 slowTime 在墙前不递减 | 完善时效和命中时序，避免视觉/逻辑不一致 |
| 游戏名 | 当前为星球防线 | 改名统一资源、README、发布名 |

## 8. 后续拆分建议（尚未实施）

main.lua → 配置(config)、战斗模拟(battle)、首页(home)、特效(effects)、账号存档(profile)。先覆盖状态切换和击杀归属，再逐个提取；本次不进行大规模重构。

未来账号结构建议 `schemaVersion / gold / xp / mechaFragments / mechaLevel / clearedStages`；银币、怒气、临时强化必须留在 battle 内。结算须有 runId 与已领奖标记；未完成闭环前不得展示虚构货币或奖励。

## 9. 验证与发布

- 本地检查：`git diff --check`；通过实际 Lua 解释执行导航测试，覆盖不同宽高与绘制参数合法性。
- 回归命令：`npx --yes --package fengari-node-cli fengari tests/home-navigation.lua`。使用引擎绘制/输入桩运行真实 main.lua；覆盖 375×812、390×844、430×932、450×800、1280×800。此测试验证路由与几何，不验证真实引擎像素和触摸事件。
- Maker LSP：`maker-lua-lsp --mode check --path scripts`。缺少 emmylua_check 时记录限制，不能宣称诊断通过。
- 布局校样：安装 `sharp` 并让 Node 可解析后运行 `node tests/render-home-proof.cjs`，生成三视口四页面 PNG。通过 Lua 的真实绘制调用检查资源、比例、遮挡；字体与绘制后端不同于 Maker，不替代引擎验收。
- 远程：先 Maker 状态，使用 `maker_build_current_directory`；成功后检查 runtime.log 与 state.json。构建成功不等于手机运行和画面已经验收。
- 手工验收：四 Tab、回首页开局、结算返回、长屏触底、普通攻击/合成/终极、第十波一 Boss。
- Maker origin 与 GitHub github 是独立远端；构建不代表已同步 GitHub。不得把含认证信息的 remote URL 写进文档或日志。
- 发布回滚依据提交 SHA；不执行覆盖用户工作区的破坏性重置。

变更要求：玩法、数值、状态、资源路径、存储协议的改变须同时更新两份 PRD 的实现状态与验收项。

本次验证记录：2026-09-26 五视口导航测试通过；LSP 命令执行失败，原因是缺少 emmylua_check；浏览器自动化连接超时，未完成真实画面验收。需在 Maker 手机预览复核文字、触摸、安全区及既有战斗表现。
