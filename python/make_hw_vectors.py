# make_hw_vectors.py — 把 INT8 模型和考試題寫成 .hex 檔，給 Verilog 陣列算
# 放法：放在 quantize.py 旁邊（要先跑過它，產生 model_int8.npz）
# 這個檔案不用改，直接跑。跑完會多 5 個 .hex 檔，要上傳到 EDA Playground。

import numpy as np

N = 4                                       # 陣列是 4×4
m = np.load("model_int8.npz")
Wq, bq, s_f, mu, sd = m["Wq"], m["bq"], m["s_f"], m["mu"], m["sd"]
d = np.load("features.npz")
F, y = d["F"], d["y"]

# 考試題：跟 train.py 一樣，每種動作最後 20%
te = []
for k in range(3):
    ii = np.where(y == k)[0]
    te += list(ii[int(0.8 * len(ii)):])
te = np.array(te)

Fq = np.clip(np.round(((F[te] - mu) / sd) / s_f), -128, 127).astype(np.int32)   # (63, 12)
labels = y[te]

# 補零（padding）：陣列一次算 4 段 × 4 個分數
#   63 段 → 補成 64 段（16 組，每組 4 段），多出來那段全是 0
#   3 個分數 → 補成 4 欄，第 4 欄的權重全是 0
Fpad = np.zeros((64, 12), dtype=np.int32); Fpad[:63] = Fq
Wpad = np.zeros((12, N), dtype=np.int32);  Wpad[:, :3] = Wq
bpad = np.zeros(N, dtype=np.int32);        bpad[:3] = bq
Lpad = np.zeros(64, dtype=np.int32);       Lpad[:63] = labels

expected = Fpad @ Wpad                      # NumPy 算的正確答案（不含 b），硬體要跟它一模一樣

def write_hex(name, arr, digits):
    mask = (1 << (4 * digits)) - 1
    with open(name, "w") as f:
        for v in arr.flatten():
            f.write(f"{int(v) & mask:0{digits}x}\n")

write_hex("fq.hex", Fpad, 2)                # 64×12 個 INT8 特徵
write_hex("wq.hex", Wpad, 2)                # 12×4 個 INT8 權重
write_hex("bq.hex", bpad, 8)                # 4 個 INT32 偏移量
write_hex("labels.hex", Lpad, 2)            # 64 個正確答案
write_hex("expected.hex", expected, 8)      # 64×4 個 INT32 分數

pred = np.argmax(expected[:63, :3] + bq, axis=1)
print(f"NumPy 用整數算的答對率: {(pred == labels).mean() * 100:.1f}%  (硬體應該要一樣)")
print("寫好 fq.hex、wq.hex、bq.hex、labels.hex、expected.hex")
