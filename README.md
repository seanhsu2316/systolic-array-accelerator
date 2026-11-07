# Systolic-Array AI Accelerator

INT8 systolic-array accelerator for matrix multiplication, written in Verilog and verified against a NumPy golden model.
It runs a small INT8 model that recognizes motion (walk / run / jump) from phone accelerometer data.

**Results**

- 4×4 array is bit-exact with NumPy on 100 random INT8 matrix multiplications
- Motion-recognition inference runs on the RTL array: hardware scores bit-exact with NumPy, **63 / 63** held-out windows correct
- Synthesized with Yosys 0.70: **~14.4K generic cells**, including 768 flip-flops

## Why I built this

I'm interested in AI, and I wanted to see what AI hardware actually does under the hood.
Most of the computation in a neural network is matrix multiplication, so I decided to build the hardware that does it, starting from a single multiply-accumulate unit.

## Architecture

```
            b_top[0]   b_top[1]   b_top[2]   b_top[3]
               ↓          ↓          ↓          ↓
a_left[0] → [PE00] →   [PE01] →   [PE02] →   [PE03]
               ↓          ↓          ↓          ↓
a_left[1] → [PE10] →   [PE11] →   [PE12] →   [PE13]
               ↓          ↓          ↓          ↓
a_left[2] → [PE20] →   [PE21] →   [PE22] →   [PE23]
               ↓          ↓          ↓          ↓
a_left[3] → [PE30] →   [PE31] →   [PE32] →   [PE33]
```

- **Output-stationary** dataflow: each PE keeps one element of C = A × B in its own accumulator.
- Rows of A enter from the left, columns of B enter from the top, both **skewed** by one clock per row/column so matching values meet in the right PE.
- Each PE = one MAC unit + two registers that pass `a` to the right and `b` downward one clock later.
- Inputs are 8-bit signed (INT8); accumulators are 32-bit to avoid overflow.
- The array size is a parameter `N`; the N×N grid is built with `generate for` loops.

## End-to-end pipeline

```
phone (phyphox, 100 Hz x/y/z)
   → Python: 2 s windows → 12 features → linear model → INT8 quantization
   → Verilog: 4×4 systolic array computes  features @ weights
   → Python / testbench: + bias → argmax → walk / run / jump
```

Python handles preprocessing and the final decision; the matrix multiplication, which is the heavy part, runs on the array.

**Data.** I recorded 2 min walking, 2 min running and 1 min jumping with the phone in my front pocket.
Each recording is cut into 2-second windows with 1-second overlap, with 3 s trimmed from each end to remove the moments of putting the phone in and taking it out (label noise). This gives 310 windows.

**Features.** Each window (200 samples × 3 axes = 600 numbers) is reduced to 12 features: mean, standard deviation, max and min per axis.
Standard deviation alone separates the classes well (x-axis: walk 2.6, run 6.4, jump 12.9).

**Model.** A linear classifier, `scores = F @ W + b` with `W` of shape 12×3, trained with softmax and gradient descent in NumPy.
Train/test split is by time: the first 80% of each recording trains, the last 20% tests, with a gap so overlapping windows never appear in both.

**Quantization.** Symmetric per-tensor INT8: `q = clip(round(x / scale), -128, 127)` with `scale = max|x| / 127`.
Bias is kept in INT32 to match the accumulator. INT8 predictions match the float model on all 63 test windows.

**Mapping onto the 4×4 array.**
- 63 test windows are padded to 64 and processed in 16 groups of 4 (one window per row).
- The 3 output scores are padded to 4 columns.
- The 12 features do not need to be split: because the array is output-stationary, each PE keeps accumulating, so all 12 values are streamed through in one pass (K = 12 > N = 4).
- Each group takes K + 2N = 20 cycles to stream in and drain.

## Synthesis

Yosys 0.70, generic gate library (`synth -top systolic_array; stat`):

| Item | Count |
|---|---|
| Total cells | 14,416 |
| Flip-flops | 768 (16 PEs × (32-bit acc + 8-bit a + 8-bit b)) |
| One MAC | 885 cells |

Breaking the MAC apart, an 8×8 multiplier is 412 cells and a 32-bit adder is 172, so the multipliers dominate the area.
Multiplier size grows roughly with the square of the bit width, which is why INT8 (or lower) matters for AI accelerators.

These are generic Yosys cells, not a standard-cell area; the count changes with the Yosys version (0.33 gives 17,712 for the same design).

## Repository layout

| Path | Description |
|---|---|
| `rtl/mac.v` | Multiply-accumulate unit: `acc <= acc + a * b` |
| `rtl/pe.v` | Processing element: MAC + data forwarding to neighbors |
| `rtl/array2x2.v` | 2×2 array, wired by hand (learning step) |
| `rtl/systolic_array.v` | Parameterized N×N array (default 4×4) using `generate` |
| `tb/tb_*.v` | Self-checking testbenches for each module |
| `tb/tb_golden.v` | Reads NumPy-generated test vectors and compares results |
| `python/gen_vectors.py` | NumPy golden model: random A, B and expected C = A @ B |
| `python/make_windows.py` | Cut recordings into 2 s windows |
| `python/make_features.py` | 12 features per window |
| `python/train.py` | Train the linear classifier |
| `python/quantize.py` | INT8 quantization and accuracy check |
| `python/make_hw_vectors.py` | Write the INT8 model and test windows as .hex for the array |
| `tb/tb_infer.v` | Runs the motion model on the 4×4 array and checks against NumPy |

## Verification

| Module | Test | Result |
|---|---|---|
| MAC | 1,007 directed + random checks | ✅ PASS |
| PE | 1,006 checks (forwarding + accumulation) | ✅ PASS |
| 2×2 array | 201 matrix multiplications | ✅ PASS |
| 4×4 array | 201 matrix multiplications | ✅ PASS |
| 4×4 array vs. NumPy | 100 random INT8 matrices | ✅ PASS |
| Motion model on 4×4 array | 63 test windows, scores vs. NumPy | ✅ PASS, 63 / 63 correct |

**Golden-model flow:**

```
python/gen_vectors.py  →  a.hex, b.hex, c_expected.hex  →  tb/tb_golden.v  →  PASS / FAIL
```

## How to run

Requires [Icarus Verilog](https://bleyer.org/icarus/) and Python 3 with NumPy (or use [EDA Playground](https://edaplayground.com) in the browser).

```bash
# 1. Generate test vectors
cd python
python gen_vectors.py
mv *.hex ..
cd ..

# 2. Simulate the 4×4 array against NumPy
iverilog -g2012 -o sim rtl/mac.v rtl/pe.v rtl/systolic_array.v tb/tb_golden.v
vvp sim
# Expected: PASS: 100 tests match NumPy golden model
```

**Motion-recognition demo** (put `walk.csv`, `run.csv`, `jump.csv` from phyphox in `python/data/`):

```bash
cd python
python make_windows.py
python make_features.py
python train.py
python quantize.py
python make_hw_vectors.py
mv *.hex ..
cd ..

iverilog -g2012 -o sim rtl/mac.v rtl/pe.v rtl/systolic_array.v tb/tb_infer.v
vvp sim
# Expected: PASS: all hardware scores match NumPy
#           hardware accuracy: 63 / 63
```

## What I learned

- **Software and hardware can check each other.** I didn't expect Python and Verilog to work together. Using NumPy as an independent "examiner" taught me why verification needs a reference model that is separate from the design itself: if the testbench computes the answer the same way the circuit does, both can be wrong and the test still passes.
- **Thinking in grids of wires.** It took me a while to understand how data moves through the array when it is built with `generate` loops. What made it click was naming the wires as a table, `a_wire[i][j]` and `b_wire[i][j]`: the output of one PE is the same wire as the input of its neighbor, so connecting 16 PEs comes down to one rule.
- **An AI model is mostly multiplication.** Before this project, "AI" and "hardware" felt like separate topics. Training the motion model showed me that the whole model is one matrix multiplication, `F @ W + b`, which is exactly what my array computes. Synthesis then showed where the cost is: the multipliers take most of the area, which is why quantizing to INT8 matters so much for AI hardware.

## Limitations

- The data comes from one person in one session, so 63 / 63 is on easy data. A recording from a different day would be a fairer test.
- Everything runs in simulation (Icarus Verilog / EDA Playground); nothing has been run on an FPGA yet.

## Roadmap

- [x] MAC unit
- [x] Processing element
- [x] 2×2 and 4×4 systolic arrays
- [x] NumPy golden-model verification
- [x] Train a small motion-recognition model on phone sensor data (phyphox)
- [x] Quantize weights to INT8 and run inference on the array
- [x] Synthesize with Yosys and report area
- [ ] Test on new recordings from a different day
- [ ] Run on an FPGA
