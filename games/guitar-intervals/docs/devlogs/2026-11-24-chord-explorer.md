# 2026-11-24 · 指板查閱與弦組選擇

## 查閱流程

先前從首頁找到高音四弦的 Gm7/B♭ 要點九次。新版首頁先顯示 C 大三和弦，從預設狀態點 G、m7、第一轉位即可比較。和弦的播放鍵放在指板上方。查音程保留複選，開始雙音練習時採用目前試聽的那一個音程。兩種查閱都能在練習之後返回原來的位置。

## 弦組與指法

使用三條弦可選 123、234、345、456，四條弦可選 1234、2345、3456。每張小圖用實際弦序標示範圍。指法查閱聚焦目前五品並另列空弦。顯示整個指板時，窄畫面會分成 0–7、8–15 品上下兩段。

查閱涵蓋 14 種和弦。一般七／六和弦的三弦配置省略純五度，半減七和弦與減七和弦使用四條弦。三和弦與掛留和弦可在四條弦上重複一音。轉位和播放依實際發聲的弦、品與八度計算，手指配置仍受非空弦最多跨四品的限制。

## 驗證

使用 Godot 4.6.2、GDScript、Web 單執行緒匯出與 Chrome 觸控模擬。模型測試涵蓋 12 根音、所有連續弦組與各種可用轉位，另以真實 viewport 點擊驗證位置、單音、合奏、切題及返回查閱。板面測試可用下列指令重跑。

```sh
godot --headless --path games/guitar-intervals --script res://tests/test_inversion_theory.gd
godot --headless --path games/guitar-intervals --script res://tests/test_board_layout.gd
godot --path games/guitar-intervals --script res://tests/test_inversion_practice.gd
```

瀏覽器測試包含 1360 × 900、1024 × 768 與 768 × 1024。測試案例包括 Gm7/B♭ 高音四弦、Cm7 中間三弦、用同一個和弦練習後返回查閱，以及從試聽鍵偵測實際音訊輸出。iPad 實機的觸感與 Safari 音訊仍待驗證。
