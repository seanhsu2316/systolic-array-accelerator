# quantize.py — 把模型的小數變成 INT8 整數（-128 ~ 127），讓硬體算得動
# 放法：放在 train.py 旁邊（要先跑過 train.py，產生 model.npz）
# TODO：只要完成標 TODO 的一行，其他不用改。

import numpy as np

m = np.load("model.npz")
W, b, mu, sd = m["W"], m["b"], m["mu"], m["sd"]
d = np.load("features.npz")
F, y = d["F"], d["y"]
Fn = (F - mu) / sd                          # 跟訓練時一樣先標準化

# 訓練題 / 考試題：跟 train.py 切法一樣
tr, te = [], []
for k in range(3):
    ii = np.where(y == k)[0]
    cut = int(0.8 * len(ii))
    tr += list(ii[:cut - 1])
    te += list(ii[cut:])
tr, te = np.array(tr), np.array(te)

def quantize(x, scale):
    # TODO：把小數 x 除以 scale、四捨五入、再限制在 -128 ~ 127 之間
    #   提示：np.round(...)  和  np.clip(..., -128, 127)
    q = np.clip(np.round(x / scale), -128, 127 )
    return q.astype(np.int32)

# 1. 算 scale：讓「最大的那個數」剛好對到 127
s_w = np.abs(W).max() / 127                 # W 的 scale
s_f = np.abs(Fn[tr]).max() / 127            # 特徵的 scale（只看訓練題，考試題不能偷看）

Wq = quantize(W, s_w)                       # (12, 3) 的 INT8 權重
Fq = quantize(Fn[te], s_f)                  # (63, 12) 的 INT8 特徵
bq = np.round(b / (s_f * s_w)).astype(np.int32)   # 偏移量用 INT32（跟硬體的累加器一樣寬）

# 2. 小數版 vs 整數版，各考一次
pred_float = np.argmax(Fn[te] @ W + b, axis=1)
pred_int   = np.argmax(Fq @ Wq + bq, axis=1)          # 全部是整數運算，硬體就是做這個

print("W 的 scale:", round(s_w, 5), "  特徵的 scale:", round(s_f, 5))
print("Wq 的範圍:", Wq.min(), "~", Wq.max())
print("小數版答對率:", f"{(pred_float == y[te]).mean() * 100:.1f}%")
print("INT8 版答對率:", f"{(pred_int == y[te]).mean() * 100:.1f}%")
print("兩版答案一樣的比例:", f"{(pred_float == pred_int).mean() * 100:.1f}%")

np.savez("model_int8.npz", Wq=Wq, bq=bq, s_w=s_w, s_f=s_f, mu=mu, sd=sd)
print("存成 model_int8.npz")
