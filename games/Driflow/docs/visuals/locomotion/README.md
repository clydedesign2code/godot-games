# 手肘修正版與歷史預覽

最新：arm-fixed.gif（20fps／50ms），arm-before-after.png（放大姿勢對照）。來源tests/arm_visual.gd，以60Hz模擬，每3步明確離屏繪製一張；執行命令見docs/LOCOMOTION.md「後續修正」。

下列basic-motion.gif與poses.png保留作為手關節修正前的歷史對照；不代表目前手部動畫。

# 基本動作實際預覽

由 tests/locomotion_visual.gd 在實際主 checkout 的 Godot 4.6.2 renderer 擷取，每張推進1/60s。basic-motion.gif 為50fps、20ms格距，含蹲下、蹲走、手膝爬行、跳躍四個循環；各面板依自己的時長循環。poses.png 含走與跑。

Notion 工作區單檔上限5MB，GIF縮至640×560、96色；保留時序。原尺寸800×700正常／半速／四分之一速、左右爬行與跑跳的本機輸出位於本輪 Codex 視覺產物 Driflow-locomotion 資料夾。

重新產出：先依 docs/LOCOMOTION.md 指令擷取，再將60Hz PNG重取樣50fps；正常格距20ms、半速40ms、四分之一速80ms。擷取輸出寫/tmp，不寫入專案快取。依本機 Godot介面調整實際執行檔路徑。

[Notion 日誌與正常／慢速預覽](https://app.notion.com/p/40fc42073e33810a8f8ce8e19c2243a8)。圖片是遊戲實拍，沒有真人素材下載或原始碼附件。


### 同日後續：起跳蓄力與蹬腿

原地起跳新增約67ms的快速下沉／伸腿，移動跳約33ms；蹲姿直接伸腿，土狼起跳直接觸發。Boot新增可編輯ToeContact=(12,13)，仍22骨節，Artwork換圖保留。修改入口為player.gd的jump_anticipation／moving_jump_anticipation，以及rig.gd的begin_takeoff／apply_takeoff_pose。新jump_smoke.gd45項檢查及既有攀爬／互動回歸通過；完整結構、輸入取消、擷取命令與時序見docs/LOCOMOTION.md「起跳發力修訂」。最新預覽為jump-push.gif與jump-phases.png，先前檔案保留歷史。


### 同日後續：伸手、扣邊與承重銜接

新增接觸前肩前弧線抬手、前後手先後接近與看向邊緣；catch約0.16s內分時固定掌心、緩衝肩／骨盆與腿，接著才開始原1.02s攀爬。接觸時的Up／W及catch期間的要求會排入climb_requested；start_climb返回true可能是接受佇列，應另檢查實際狀態。真正抓取再核對頂面相對腳底<=130px與原碰撞路徑，兩座高台實際跳抓皆回歸通過。

新tests/reach_smoke.gd的560檢查通過，reach_visual.gd含兩高度左右鏡像及完整chain。完整程式分工、參數、22節換圖契約、測試與擷取命令見docs/LOCOMOTION.md和CLIMB_REFERENCE.md「伸手與扣邊修訂」。最新圖為reach-catch.gif、reach-phases.png；先前預覽保留歷史。


### 同日後續：正常步行不再固定壓低骨盆

原版一移動就把骨盆降7px，跑步降11px，造成半蹲感。現在走路改為承重腿伸直與小幅週期移重，配合腳跟落地、鞋底承重和前腳掌推進；固定垂直鏡頭下站走平均身高差由約6.2px降至1.2px。移動速度維持220／380px/s。

Boot新增HeelContact=(-12,13)，與SoleContact=(0,13)、ToeContact=(12,13)共同校準鞋底；仍22骨節，Artwork可換圖。主流程為rig.gd的ground_foot_pose／solve_ground_foot與骨盆週期，取代舊normal_legs；調整步幅、支撐比例時要一起查身高與接觸誤差。

新walk_height_smoke1230檢查及既有跳躍、抓邊、攀爬、低姿勢與互動回歸通過。完整結構、參數、相位越界／走跑切換處理和重製命令，見docs/LOCOMOTION.md「步行身高修訂」。最新圖為upright-walk.gif、walk-phases.png，先前預覽保留歷史。


## 附件繪圖順序（2026-11-05）

- layer-order.gif／layer-order-slow.gif：六面板正常／四分之一速，50／200ms格距，短片段停留末幀。
- layer-poses.png：左右走、蹲走、手膝與左右攀上放大姿勢。
- layer-before-after.png：相同步態幀左舊右新，前後肢體與衣身遮擋。
- layer-air-reach.png：左右跳躍與伸手序列。

實際Godot renderer；規格與修改方式見[RENDER_ORDER](../../RENDER_ORDER.md)。
