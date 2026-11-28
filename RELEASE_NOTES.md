## v2 阶段 4 · Phase 4 — 演出与养成闭环 / Cinematics & progression loop
- 主能力：按角色解锁时间（15–25 秒）发动，抽究极技并附带回血/回气/清增益/全手牌转射击等效果 / Main abilities draw the ultimate
- UL 开场 2.5 秒环绕运镜与气场爆发；LL/UL 究极技击倒最后一人触发 LEGENDARY FINISH / UL intro and Legendary Finish
- 主页「出战」进入新养成中心：编队（队长 + 3 人、难度）、角色（升级/升星/3 槽装备、UL 陀螺仪立绘）、装备洗练（安全升级）/ New progression hub
- 存档保存为 UserSaveData.json；战斗按等级/星级/Z 能力/装备计算面板，胜利掉落经验书、星魂、洗练石与装备 / JSON save + rewards

## v2 阶段 2 · Phase 2 — 3D 镜头、冲刺与受击 / Camera, dashes, hitstun
- 新镜头控制器：弹簧阻尼平滑；越肩 48° / 前冲广角 56° + 速度线 / 瞬移 120° 反打切镜 / 必杀仰拍特写 38° / Spring-damped camera with dash, vanish-cut and close-up shots
- 受击分级：轻受击 0.30s、连击受击 0.47s、重击飞 0.67s + 空中受身；霸体白闪；眩晕与麻痹 / Light, combo, heavy hitstun with air recovery; armor flash; stun & paralysis
- 前冲 0.28s（可用卡取消），后撤带 0.15s 收招硬直；浮空待机；瞬移三层残影 / Forward dash cancel, back-dash recovery, hover idle, 3-layer afterimages

## v2 阶段 3 · Phase 3 — 进阶连击与特殊量表 / Advanced combos & unique gauges
- 输入缓冲 0.25s、侧滑连（≤0.42s：+8 气、闪避+10%、抽卡加速）、聚气连（+15 气）、主动断连（>0.45s）/ Input buffer, side-step & charge-step combos, drop combo
- 四种特殊量表：攻击爆发（凯）、自动闪避（瑟菲）、受击反制（克洛斯，每局 3 次）、形态充能超载（诺瓦）/ 4 unique gauges
- 拼招对决：双方打击卡相撞，3 秒 0–999 能量条点击锁定，高分者免费追击 / Strike clash bar
- 升龙冲击：集满 7 珠，命中后 4 选 1 猜卡，猜错吃终结技、猜中弹反 / Rising Rush 1-of-4 guess

## v2 阶段 1 · Phase 1 — BattleCore 数据层 / Data layer
- 新阵容 6 人：克洛斯 UL 红 · 瑟菲 UL 蓝 · 凯 LL 紫 · 诺瓦 LL 黄 · 岚 SP 绿 · 塞拉 SP 光 / New 6-fighter roster (2 UL, 2 LL, 2 SP)
- 等级 1–5000、星级 1–14、Z 能力 I–IV、队长规则、UL 极限能力 / Levels, stars, Z abilities, leader rules, Ultra ability
- 10 件装备模板，3 词条、绿/金/红珠、B→神 评级、安全重铸 / 10 equipment templates, beads, grades, secure reforge
- 分层伤害公式 + 连击递减 100/95/85/75/65/50% / Layered damage formula + combo decay
- JSON 存档 / JSON save data

<!-- 每次发布时，本文件内容会作为「更新说明」出现在 GitHub Release 页面顶部。 -->

### 换人回来了 · Tag switching is back
- 战斗界面卡牌上方有 2 个队友头像（显示血量环、属性色、冷却秒数），点一下换人，冷却 10 秒
  Two teammate portraits above the cards (HP ring, element color, cooldown). Tap to switch; 10 s cooldown
- **援护换人 Cover change**：被连击时点头像，队友冲进来交叉双臂格挡，打断对手连招
- **特殊援护 Special cover**：凯（打击援护）/艾格（射击援护）在对应招式打来时换上，会把对手直接击退到远距离（每套连招一次）
- 岚离场时为队友 +25 气力；AI 血量低于 35% 也会换人

### 气力与视角 · Ki & camera
- **气力一直自动恢复**（每秒 8 点，被打、出招时也恢复）；长按聚气每秒 32 点
  **Ki now recovers all the time** (8/s, also while attacking or being hit); holding to charge gives 32/s
- **视角更接近龙珠激战传说**：画面上的距离压缩一半，双方都更大；镜头在角色背后 2.2 米、偏左、胸口高度，视野收窄
  **Camera closer to DBL**: on-screen distance halved so both fighters look bigger; camera 2.2 m behind, slightly left, chest height, narrower FOV

### 修复 · Fixes
- **v3.1.49 / v3.1.50 是坏包，请不要安装**（编译失败但仍被打包）。本版修复了编译错误，并加强了发布检查：只有完整编译成功、可执行文件存在时才会发布
  **v3.1.49 / v3.1.50 were broken builds — please don't install them.** Fixed, and releases now require a successful build

### 震动开关 · Vibration toggle
- 首页右上角新增震动按钮；战斗暂停菜单里也可以开关。关闭后整个游戏都不再震动
  New vibration button on the home screen and in the battle pause menu

### 聚气动画重做 · New power-up
- 新姿势：双脚大开、拳头收在腰间、挺胸，身体微微颤抖，每 0.6 秒爆发一次
- 气场改为沿身体快速上升的细亮光束 + 脚下脉动光圈，不再是「水滴」粒子

### 画面 · Presentation（参考龙珠激战传说实机录像 / learned from DBL footage）
- 镜头：对峙时在角色背后偏左；近身连击时切到 3/4 侧面并贴近
- 右侧大号斜体连击数；加粗描边伤害数字；左上角状态提示；瞬身青色光环；紫色夜空场景
