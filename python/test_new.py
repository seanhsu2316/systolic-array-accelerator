import numpy as np

RATE, WIN, STEP, TRIM = 100, 200, 100, 300         
FILES = {"walk_new": 0, "run_new": 1, "jump_new": 2}
NAMES = ["walk", "run", "jump"]

F_list, y_list = [], []
for name, label in FILES.items():
    acc = np.loadtxt(f"data/{name}.csv", delimiter=",", skiprows=1)[:, 1:4][TRIM:-TRIM]
    for start in range(0, len(acc) - WIN + 1, STEP):
        w = acc[start:start + WIN]
        F_list.append(np.concatenate([w.mean(0), w.std(0), w.max(0), w.min(0)]))
        y_list.append(label)
F, y = np.array(F_list), np.array(y_list)
print("新資料段數:", len(y), " (走/跑/跳 =", [int((y == k).sum()) for k in range(3)], ")")

m = np.load("model.npz")
Fn = (F - m["mu"]) / m["sd"]
pred = np.argmax(Fn @ m["W"] + m["b"], axis=1)

q = np.load("model_int8.npz")
Fq = np.clip(np.round(Fn / q["s_f"]), -128, 127).astype(np.int32)
pred_int = np.argmax(Fq @ q["Wq"] + q["bq"], axis=1)

print(f"小數版答對率: {(pred == y).mean() * 100:.1f}%")
print(f"INT8 版答對率: {(pred_int == y).mean() * 100:.1f}%")

print("\n混淆矩陣 (列=正確答案, 欄=模型猜的)")
print("          walk   run  jump")
for k in range(3):
    row = [int(((y == k) & (pred_int == j)).sum()) for j in range(3)]
    print(f"{NAMES[k]:>5}   {row[0]:>5} {row[1]:>5} {row[2]:>5}")
