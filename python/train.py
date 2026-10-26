# train.py — 用 12 個特徵訓練一個小模型，猜 走 / 跑 / 跳
# 放法：放在 make_features.py 旁邊（要先跑過它，產生 features.npz）
# TODO：只要完成標 TODO 的兩行，其他不用改。

import numpy as np

d = np.load("features.npz")
F, y = d["F"], d["y"]            # F: (310, 12)  y: (310,)

# 1. 切成 訓練 80% / 考試 20%：每種動作「前 80% 的時間」拿來訓練，「最後 20%」拿來考試
#    不隨機洗牌，因為相鄰兩段重疊一半，洗牌會讓考試題偷看到訓練題的一半資料
#    中間空一段，讓訓練題和考試題完全不重疊
tr, te = [], []
for k in range(3):
    ii = np.where(y == k)[0]          # 答案是 k 的那些段，照時間順序
    cut = int(0.8 * len(ii))
    tr += list(ii[:cut - 1])
    te += list(ii[cut:])
tr, te = np.array(tr), np.array(te)

# 2. 標準化：每個特徵減平均、除標準差，讓 12 個特徵的大小差不多
mu, sd = F[tr].mean(axis=0), F[tr].std(axis=0)
Fn = (F - mu) / sd

# 3. 模型：W 是 (12, 3) 的權重矩陣，b 是 3 個偏移量
W = np.zeros((12, 3))
b = np.zeros(3)

def scores(Fx):
    # TODO 1：每段的 12 個特徵 × W，再加 b → 每段得到 3 個分數（走、跑、跳）
    #   Fx 的形狀是 (段數, 12)，W 是 (12, 3)，結果要是 (段數, 3)
    #   提示：Day 5 用過的矩陣乘法符號
    return Fx @ W + b

# 4. 訓練：重複 300 次「猜 → 看錯多少 → 把 W、b 往對的方向調一點」
Y = np.eye(3)[y[tr]]                       # 答案改成 one-hot，例如 跑 → [0, 1, 0]
for step in range(300):
    s = scores(Fn[tr])
    p = np.exp(s - s.max(axis=1, keepdims=True))
    p /= p.sum(axis=1, keepdims=True)      # softmax：3 個分數 → 3 個機率
    grad = (p - Y) / len(tr)               # 猜的機率 − 正確答案 = 錯多少
    W -= 0.5 * Fn[tr].T @ grad
    b -= 0.5 * grad.sum(axis=0)

# 5. 考試：用沒看過的 20% 測準確率
# TODO 2：3 個分數裡最大的那個位置就是答案（0=走 1=跑 2=跳）
#   提示：np.argmax(..., axis=1)
pred = np.argmax(scores(Fn[te]), axis=1)
acc = (pred == y[te]).mean()
print(f"考試題數: {len(te)}  答對率: {acc * 100:.1f}%")

np.savez("model.npz", W=W, b=b, mu=mu, sd=sd)
print("存成 model.npz")
