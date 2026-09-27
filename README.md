# 星球防线

《星球防线》是一个使用 TapTap Maker 开发的竖屏合成塔防 Demo。玩家消耗当局银币随机召唤防守角色，将同等级角色拖动合并，并通过事件强化抵挡十波怪物进攻。

## 当前玩法

- 通铺顶栏、固定底部四 Tab：主页、守卫图鉴、机甲展示、星图；主页可进入战斗，结算可返回主页。
- 十波怪物进攻，包含普通、敏捷、肉盾、甲壳和 Boss 类型。
- 弓箭手、冰霜法师、奶妈三种职业，最高可合成至三级。
- 六帧怪物行走/攻击动画和职业攻击动画。
- 箭矢、冰弹、祝福三类独立弹道，命中后结算伤害或增益。
- 击杀怪物自动获得银币，召唤与事件强化费用逐次增加。
- 城墙生命、星核生命、职业强化和局外机甲成长设计。

## 项目结构

```text
assets/                 游戏图片和动画素材
docs/                   产品文档与素材预览
scripts/main.lua        核心战斗逻辑
scripts/export-*.cjs    怪物动画切图工具
```

## 本地开发

项目使用 TapTap Maker 本地开发工作流。安装并登录 Maker CLI 后，在项目根目录构建：

```bash
npx -y @taptap/maker install --ide codex
npx -y @taptap/maker init
```

Maker 构建入口为 `scripts/main.lua`，构建参数为 `entry=main.lua`、`scriptsPath=scripts`。

## 文档

- [MVP 产品基线（当前验收依据）](docs/mvp-product-prd.md)
- [技术 PRD（架构、定位与待办）](docs/technical-prd.md)
- [角色设计库（六名新角色、造型动画规范与复用模板，尚未实现）](docs/characters/README.md)
- [历史产品方案（含未实现规划）](docs/zombie-garden-prd.md)
- [怪物素材预览](docs/monster-library-desktop.png)
- [防守角色素材预览](docs/defender-library-desktop.png)

## 当前状态

这是首页导航与核心战斗玩法原型。机甲永久成长、多关解锁和长期奖励尚未实现；数值、美术一致性、移动端性能和关卡节奏仍在持续调整。
