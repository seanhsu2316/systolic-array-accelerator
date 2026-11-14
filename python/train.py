import numpy as np

d = np.load("features.npz")
F, y = d["F"], d["y"]           

tr, te = [], []
for k in range(3):
    ii = np.where(y == k)[0]         
    cut = int(0.8 * len(ii))
    tr += list(ii[:cut - 1])
    te += list(ii[cut:])
tr, te = np.array(tr), np.array(te)


mu, sd = F[tr].mean(axis=0), F[tr].std(axis=0)
Fn = (F - mu) / sd


W = np.zeros((12, 3))
b = np.zeros(3)

def scores(Fx):
    
    return Fx @ W + b


Y = np.eye(3)[y[tr]]                       
for step in range(300):
    s = scores(Fn[tr])
    p = np.exp(s - s.max(axis=1, keepdims=True))
    p /= p.sum(axis=1, keepdims=True)     
    grad = (p - Y) / len(tr)               
    W -= 0.5 * Fn[tr].T @ grad
    b -= 0.5 * grad.sum(axis=0)


pred = np.argmax(scores(Fn[te]), axis=1)
acc = (pred == y[te]).mean()
print(f"考試題數: {len(te)}  答對率: {acc * 100:.1f}%")

np.savez("model.npz", W=W, b=b, mu=mu, sd=sd)
print("存成 model.npz")
