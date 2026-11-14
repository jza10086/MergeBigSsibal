# 合成大西八 · MergeBigSsibal

minigame for 1–8 online participants, using GodotPartyDefaultProtocol 1.0. Install this repository at `games/minigame/gp_merge_ssibal/` in the complete GodotParty project and select it in the minigame playlist lobby. This package is not a standalone Godot project.

Aim with the mouse and drop with left click or Space (rebindable). Matching circles merge into the next of eleven sizes; each merge awards the triangular score of the resulting tier (3, 6, 10, …, 66). The largest tier stays in the bin. Each player has a separate bin and the same seeded sequence. The host simulates all bins. Reliable events carry births, merges, removals, scores and final resting positions; moving circles use minimal 20 Hz unreliable ordered position samples and local interpolation. Spectators can watch.

A ball remaining above the red line for two seconds ends that player's run, with 1.4 seconds of grace for newly dropped balls. Drops have a 0.55-second cooldown. All bins ending or the room time limit (default 180 seconds) ends the round. Scores determine ranking, ties share ranks, and disconnected participants withdraw. Esc opens the framework menu; the round continues. Loading and settlement use the protocol's shared pages.

All circles are plain colors; no external art is included. The package provides Chinese and English gameplay text. Shared protocol pages follow the protocol's own localization.

The editable arena is in arena_view.tscn; bin_view.tscn is the shared skin for the main and opponent bins. The scene owns the frame, labels and evolution legend. Scripts render only live balls, aim and warning state. merge_world.gd remains the host simulation. Shared round lifecycle changes (architecture checklist G01) remain a separate protocol task.

1–8 人独立落球合成。鼠标瞄准，点击或空格落球；同级圆球相碰合成更大一级并得分。越过红线持续 2 秒结束，落球有入场宽限。默认 3 分钟，全部结束或到时按分数排名。11 级纯色占位，最高级保留在容器中。

## 包内开发文档

未带 `res://` 的源码路径以本包根目录为基准。

- [M14 合成大西八　B　依赖 G01](gp_merge_ssibal_development.md)
