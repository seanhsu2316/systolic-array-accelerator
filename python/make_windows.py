# make_windows.py — 把長錄音切成很多 2 秒的小段，每段就是一個訓練例子
#
# 放法：在這個 .py 檔旁邊建一個 data 資料夾，放 walk.csv、run.csv、jump.csv
#
# TODO：只要完成標 TODO 的迴圈，其他不用改。

import numpy as np

RATE = 100          # 每秒 100 筆
WIN = 2 * RATE      # 一段 2 秒 = 200 筆
STEP = RATE         # 每次往後移 1 秒（相鄰兩段重疊一半）
TRIM = 3 * RATE     # 頭尾各切掉 3 秒（放進、拿出口袋的雜訊）

FILES = {"walk": 0, "run": 1, "jump": 2}   # 動作名稱 → 標籤（AI 要猜的答案）

all_windows = []
all_labels = []

for name, label in FILES.items():
    data = np.loadtxt(f"data/{name}.csv", delimiter=",", skiprows=1)
    acc = data[:, 1:4]              # 只取 x、y、z 三欄（第 0 欄是時間）
    acc = acc[TRIM:-TRIM]           # 頭尾切掉

    count = 0
    # TODO：用 for 迴圈切出一段一段
    #   - start 從 0 開始，每次加 STEP，直到剩下的不夠一段 WIN 為止
    #   - 每段是 acc[start : start + WIN]
    #   - 把這段加進 all_windows，把 label 加進 all_labels，count 加 1
    #   提示：range(起點, 終點, 間隔)
    for start in range(0, len(acc) - WIN + 1, STEP):
        all_windows.append(acc[start:start + WIN])
        all_labels.append(label)
        count += 1

    print(f"{name}: 切出 {count} 段")

X = np.array(all_windows)   # 形狀：(段數, 200, 3)
y = np.array(all_labels)    # 形狀：(段數,)
print("X 的形狀:", X.shape)
print("y 的形狀:", y.shape)

np.savez("windows.npz", X=X, y=y)
print("存成 windows.npz")
