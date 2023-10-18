# SOC Design Lab - Lab3 Report

## R11943022 范詠為

1. Block Diagram
	- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-1cbc4df84db729b054ec3bec1fa50302.png)
	- 我設計了一個 `axilite` module 負責控制 AXI-Lite 的輸入輸出像是 `ap_start`、`data_len`、`tap_coeff` 等信號，在第二點會針對它做介紹。而 datapath 的實現是用一個 `32bx32b` 的乘法器和一個 `32b` 的加法器，透過 address scheduling 去得到相對應要做乘加的值，並用一個 `32b acc_r` register 作為暫存和運算完後的輸出資料，data 的輸入輸出則是遵守 AXI-Stream 的規範。
2. Describe Operation
	- FSM
		- 我分成五個 state，`S_IDLE`、`S_LOAD`、`S_CALC`、`S_SEND`、`S_DONE`。`S_IDLE` 為初始狀態，等待 `ap_start` 來進入 `S_LOAD`。`S_LOAD` 收進一筆 streaming 進來的資料並存到 data bram。`S_CALC` 會花 12 cycles 做單筆 `y[n]` 的運算，算出來結果後到 `S_SEND`  streaming 一筆出去。若是最後一筆（`ss_tlast`）則進入 `S_DONE` 並把 `ap_done` 拉高，否則進入 `S_LOAD` 繼續運算資料。
	- `axilite`  AXI-Lite controller 
		- 我參考 lab2 vitis hls 合出來的 rtl 寫出的，read/write 分別有自己的 state machine，分成 `IDLE` 跟 `DATA`。前者做 address 的 handshake，後者則是 data 的 handshake。在 AXI-Lite 寫進 fir 時，會 decode address 去存 `ap_start`、`data_len` 或 `tap_coeff`。反之在讀取時會去拿 ctrl (`ap_start`、`ap_idle`、`ap_done`) 或是 tap bram 內的暫存值並輸出。
	- AXI-Stream
		- `ss_tready` 在 `state_r == S_LOAD` 時拉高，`sm_tvalid` 則在 `state_r == S_SEND` 時拉高。在輸入 handshake 成功時從 `ss_tdata` 寫入一筆 data bram，運算後從 `acc_r` 輸出至 `sm_tdata`。
		- Address 控制邏輯
			- 因為 bram 是 single port 不能同時讀取寫入，在設計時需要規劃好每個 cycle 要讀取或寫入，稍微 tricky。我的做法是外面進來的 data 先寫入 bram 0x00，接著進入 `S_CALC` 後 fir 從 0x04 開始讀，以 circular 的方式讀回 0x00，接著下一筆 data 寫入 0x04，fir 再從 0x08 開始讀一圈回 0x04。這樣的方式可以利用資料的重複性一個 cycle 讀一筆資料來做運算。比較特別的是前十筆因為演算法特性要初始化為 0，但 bram 會拿到 x，所以要特別給乘法器輸入 0。受限於 single port bram 和唯一的乘加器，加上一些 read/write cycle 上的 offset，`II=14`。
3. Resource Usage
	- 總共用了 **283 LUTs、134 FFs、3DSPs**，未使用 Bram，FF 數量也在合理範圍，而 IO 用了超過板子所提供的量所以顯示紅色。圖中顯示 AXI-Lite 控制器 `axilite_0` 和乘法器 `mul_0` 分別的使用量， 其中乘法器使用了近四成的 LUT，和全部共三個的 DSP。
	- 而我所針對硬體資源使用量所做的優化是把 tap address base 從 0x20 改成 0x80，這麼做的好處是從 AXI-Lite 進來的 tap address 對應到 tap bram address 不用使用減法器，合成後發現 LUT 的數量從 288 減少 5 個到 283，幫助有限。
	- 最下圖 synthesis report 可以看到更細節的用量，甚至會區分不同位元數的 component。
	- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-dcc7faa8980df6c350d7e4265701c6de.png)
	- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-9e3d93be0d2b57708f7ef84baee39bd3.png)
	- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-3a1972716b7b638529d4f12da454c044.png)
4. Timing Report
	- Max Frequency: **`58.824 MHz`** (Clock Period = **`17ns`**)
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-43fbfdfaa3cdbb77f9e1e26a811e04db.png)
		- other constraints: input delay 和 output delay 都設為 **`4ns`**
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-23e9d63de64c479d4c01dc1ca6204872.png)
	- Longest Path Slack: **`0.528 ns`**
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-8b142ab1bac82dd9eaba9f810523bef8.png)
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-b54978cb9223bf26f136c2676f9d4ef2.png)
	- Longest Path: **`waddr_r -> acc_r`**
		- critical path 從 `waddr_r` 到 `mul_0` 到 `acc_r` 非常合理，因為為了省 FF 的數量，並沒有在乘法器前的 data 擋 FF，造成從取得 bram data 的 address 開始到乘加完成有較長的路徑，需要較長的 clock period。觀察路徑上的時間發現單純乘法器也需要差不多 10 ns 的時間。
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-e7f8a4846fb44ac89a8b8359631f0d5b.png)
5. Simulation Waveform
	- \# of clock cycles from ap_start to ap_done (RTL): **`84000 ns / 10 ns = 8400 cycles`**
		- 分析 `II`，**`8400 cycles / 600 data = 14`**。
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-22eec2a68e467f63dd82017dca4acd5d.png)
	- Coefficient Program and Read Back
		- 因為 AXI-Lite 需要做 address handshake 和 data handshake， 所以一筆資料需要 3 個 cycles。
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-89bb82311d17cacea1dc323a08e39aea.png)
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-4ef2ad01788211f51832f92ec11aacef.png)
	- Data-in Stream-in and Data-out Stream-out
		- 可以看到每 14 個 cycles 輸入一筆資料，同樣每 14 個 cycles 輸出一筆資料。
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-fb80e0eabd8bffbec2ca448b6a9a8b32.png)
	- FSM
		- `000` -> `S_IDLE`, `001` -> `S_LOAD`, `010` -> `S_CALC`, `011` -> `S_SEND`, `100` -> `S_DONE`
		- ![](https://raw.githubusercontent.com/BrianEE07/MyNotes-image/main/img/assets/SOC%20Design%20Lab%20-%20Lab3%20Report.assets/2023-10-18-21-03-36-9e3c23acd5841e5f0db73848bf3914b9.png)
