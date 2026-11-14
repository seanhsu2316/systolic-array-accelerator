import numpy as np
WIN, STEP, TRIM = 200, 100, 300


def make_feats(path):
    acc = np.loadtxt(path, delimiter=",", skiprows=1)[:, 1:4][TRIM:-TRIM]
    mag = np.sqrt((acc ** 2).sum(axis=1))
    F = []
    for start in range(0, len(mag) - WIN + 1, STEP):
        w = mag[start:start + WIN]
        F.append([w.mean(), w.std(), w.max(), w.min()])
    return np.array(F)


def load_set(suffix):
    Fs, ys = [], []
    for k, name in enumerate(["walk", "run", "jump"]):
        F = make_feats(f"data/{name}{suffix}.csv")
        Fs.append(F)
        ys += [k] * len(F)
    return np.vstack(Fs), np.array(ys)


def train(F_tr, y_tr):
    mu, sd = F_tr.mean(axis=0), F_tr.std(axis=0)
    X = (F_tr - mu) / sd
    W, b = np.zeros((4, 3)), np.zeros(3)
    Y = np.eye(3)[y_tr]
    for step in range(300):
        s = X @ W + b
        p = np.exp(s - s.max(axis=1, keepdims=True))
        p /= p.sum(axis=1, keepdims=True)
        grad = (p - Y) / len(y_tr)
        W -= 0.5 * X.T @ grad
        b -= 0.5 * grad.sum(axis=0)
    return mu, sd, W, b

def test(model, F_te, y_te, title):
    mu, sd, W, b = model
    pred = np.argmax(((F_te - mu) / sd) @ W + b, axis=1)
    print(f"{title} 答對率: {(pred == y_te).mean() * 100:.1f}%  ({len(y_te)} 段)")
    cm = np.zeros((3, 3), int)
    for t, p_ in zip(y_te, pred):
        cm[t, p_] += 1
    print(cm)

F_old, y_old = load_set("")
F_new, y_new = load_set("_new")
print("舊:", F_old.shape, " 新:", F_new.shape)


m1 = train(F_old, y_old)
test(m1, F_new, y_new, "[只看舊資料] 新的一天")


tr_F, tr_y, te_F, te_y = [F_old], [y_old], [], []
for k in range(3):
    Fk = F_new[y_new == k]
    h = len(Fk) // 2
    tr_F.append(Fk[:h - 1]); tr_y.append(np.full(h - 1, k))
    te_F.append(Fk[h:]);     te_y.append(np.full(len(Fk) - h, k))
F_tr, y_tr = np.vstack(tr_F), np.concatenate(tr_y)
F_te, y_te = np.vstack(te_F), np.concatenate(te_y)
m2 = train(F_tr, y_tr)
test(m2, F_te, y_te, "[舊 + 新前一半] 新的後一半")
