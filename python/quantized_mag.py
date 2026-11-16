import numpy as np
m = np.load("model_mag.npz")
mu, sd, W, b = m["mu"], m["sd"], m["W"], m["b"]
Fn_tr = (m["F_tr"] - mu) / sd     
Fn_te = (m["F_te"] - mu) / sd    
y_te = m["y_te"]

def quantize(x, scale):
    return np.clip(np.round(x / scale), -128, 127).astype(np.int32)

s_w = np.abs(W).max() / 127     
s_f = np.abs(Fn_tr).max() / 127    
Wq = quantize(W, s_w)
Fq = quantize(Fn_te, s_f)
bq = np.round(b / (s_f * s_w)).astype(np.int32)

pred_float = np.argmax(Fn_te @ W + b, axis=1)
pred_int   = np.argmax(Fq @ Wq + bq, axis=1)
print("W 的 scale:", round(s_w, 5), "  特徵的 scale:", round(s_f, 5))
print(f"小數版答對率: {(pred_float == y_te).mean()*100:.1f}%")
print(f"INT8 版答對率: {(pred_int == y_te).mean()*100:.1f}%")
np.savez("model_mag_int8.npz", Wq=Wq, bq=bq, Fq=Fq, y_te=y_te)
print("存成 model_mag_int8.npz")
