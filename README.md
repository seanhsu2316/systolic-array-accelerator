# Systolic-Array AI Accelerator

INT8 systolic-array accelerator for matrix multiplication, written in Verilog and verified against a NumPy golden model.
Final goal: run a small neural network that recognizes motion (walk / run / jump) from phone sensor data.

> **Status: In Progress.** The 4×4 array is complete and verified. The motion-recognition demo is next.

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

## Verification

| Module | Test | Result |
|---|---|---|
| MAC | 1,007 directed + random checks | ✅ PASS |
| PE | 1,006 checks (forwarding + accumulation) | ✅ PASS |
| 2×2 array | 201 matrix multiplications | ✅ PASS |
| 4×4 array | 201 matrix multiplications | ✅ PASS |
| 4×4 array vs. NumPy | 100 random INT8 matrices | ✅ PASS |

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

## What I learned

- **Software and hardware can check each other.** I didn't expect Python and Verilog to work together. Using NumPy as an independent "examiner" taught me why verification needs a reference model that is separate from the design itself: if the testbench computes the answer the same way the circuit does, both can be wrong and the test still passes.
- **Thinking in grids of wires.** It took me a while to understand how data moves through the array when it is built with `generate` loops. What made it click was naming the wires as a table, `a_wire[i][j]` and `b_wire[i][j]`: the output of one PE is the same wire as the input of its neighbor, so connecting 16 PEs comes down to one rule.

## Roadmap

- [x] MAC unit
- [x] Processing element
- [x] 2×2 and 4×4 systolic arrays
- [x] NumPy golden-model verification
- [ ] Train a small motion-recognition network on phone sensor data (phyphox)
- [ ] Quantize weights to INT8 and run inference on the array
- [ ] Synthesize with Yosys and report area

