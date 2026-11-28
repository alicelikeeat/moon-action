<!-- 每次发布时，本文件内容会作为「更新说明」出现在 GitHub Release 页面顶部。 -->

### 换人回来了 · Tag switching is back
- 战斗界面卡牌上方有 2 个队友头像（显示血量环、属性色、冷却秒数），点一下换人，冷却 10 秒
  Two teammate portraits above the cards (HP ring, element color, cooldown). Tap to switch; 10 s cooldown
- **援护换人 Cover change**：被连击时点头像，队友冲进来交叉双臂格挡，打断对手连招
- **特殊援护 Special cover**：凯（打击援护）/艾格（射击援护）在对应招式打来时换上，会把对手直接击退到远距离（每套连招一次）
- 岚离场时为队友 +25 气力；AI 血量低于 35% 也会换人

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
