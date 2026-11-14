# M14 合成大西八　B　依赖 G01

来源：2026-11-07 架构审查及其最后实施记录。整理日期：2026-11-14。下列待办保留原状态；实施前核对本包源码与工作区，不以历史检查代替本次验收。

[共享 G01–G03 任务](../../../protocols/godot_party_default_protocol/doc/godot_party_default_protocol_development.md) · [包说明](gp_merge_ssibal_guide.md)


包：`gp_merge_ssibal`。定位：[game.gd](../game.gd)、[arena_view.gd](../arena_view.gd)。

- [ ] 保留现有 world/view 分离与网络 Error 处理。G01 完成后检查本包重写 send_action/publish 的真实差异，只有语义已一致才合并，不先删掉其正确处理。

验证：两种语言、放球/合并、菜单释放门控、观战者不能放球、独立玩家箱体与结算。

实施记录（2026-11-07，子仓提交 `ad8b834`）：M14 包内双语与场景化两项完成。新增 arena_view.tscn 和复用 bin_view.tscn，保留 Inspector 外框样式；视图接收翻译 Callable，默认预览使用包内中文 Translation。补全包内中英文简介、设置及动态模板；world、玩法、人数、消息字段和现有网络 Error 处理保持不变。G01 尚未实施，send_action/publish 合并及共享页面生命周期迁移继续待办，本次未修改协议。

验证记录：现有规则检查及单人正式大厅→落球→结算→回合保存检查通过；覆盖菜单阻止/恢复、观战身份不发送、两个独立箱体的状态文字、溢出提示及场景样式保留；1920×1080 中英文游戏画面已直接渲染检查。本轮未重跑双端网络，未做真人多人、跨机器网络或手感验收。
