# gen_vectors.py — 用 NumPy 當「標準答案」（golden model）
#
# 做三件事：
#   1. 隨機產生 NUM_TESTS 組 4×4 的 A、B（8-bit 有號數，-128 ~ 127）
#   2. 用 NumPy 算出正確答案 C = A × B
#   3. 把 A、B、C 寫成 .hex 檔，讓 Verilog testbench 讀進去比對
#
 
import numpy as np
 
N = 4            # 陣列大小 4×4
NUM_TESTS = 100  # 要產生幾題
 
np.random.seed(0)  # 固定亂數種子，每次跑出來的題目都一樣，方便 debug
 
def write_hex(filename, values, bits):
    """把一串整數寫成 hex 檔，一行一個。負數用二補數表示。"""
    mask = (1 << bits) - 1
    digits = bits // 4
    with open(filename, "w") as f:
        for v in values:
            f.write(f"{int(v) & mask:0{digits}x}\n")
 
all_a, all_b, all_c = [], [], []
 
for t in range(NUM_TESTS):
    # TODO 1：產生 4×4 的隨機矩陣 A 和 B，數值範圍 -128 ~ 127
    #         提示：np.random.randint(最小值, 最大值+1, size=(N, N))
    A = np.random.randint(-128, 128, size=(N, N))
    B = np.random.randint(-128, 128, size=(N, N))
 
    # TODO 2：算出 C = A × B
    #         提示：NumPy 的矩陣乘法是 @
    #         注意：要先用 .astype(np.int32) 轉成 32-bit，為什麼？想想看
    C = A.astype(np.int32) @ B.astype(np.int32)
 
    all_a.extend(A.flatten())   # flatten：把 4×4 攤平成 16 個數字（一列一列排）
    all_b.extend(B.flatten())
    all_c.extend(C.flatten())
 
write_hex("a.hex", all_a, 8)
write_hex("b.hex", all_b, 8)
write_hex("c_expected.hex", all_c, 32)
 
print(f"產生了 {NUM_TESTS} 題，寫入 a.hex、b.hex、c_expected.hex")
print("第 1 題的 A =\n", np.array(all_a[:16]).reshape(N, N))
print("第 1 題的 C =\n", np.array(all_c[:16]).reshape(N, N))
