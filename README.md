# 32-Bit RISC-V Reversible ALU (Verilog)

An RV32I-compatible ALU built entirely from **reversible gates** (Feynman, Toffoli, Peres, Fredkin), with **built-in error detection** through inverse re-computation and a CRC-8 result signature.

## Operations

| op_sel | Op | | op_sel | Op |
|---|---|---|---|---|
| 0000 | ADD | | 0101 | SLL |
| 0001 | SUB | | 0110 | SRL |
| 0010 | AND | | 0111 | SRA |
| 0011 | OR | | 1000 | SLT |
| 0100 | XOR | | 1001 | SLTU |

Status flags: **Zero, Carry, Overflow, Sign**.

## Architecture

```
            ┌───────────────┐
 A, B ──┬──►│ Adder/Sub     │──arith──┐
        │   │ (Peres RCA)   │         │
        ├──►│ Logic unit    │──AND/OR/XOR──►┌──────────────┐
        │   │ (Toffoli/Feyn)│         │     │ Output MUX   │──► result ──► flags
        ├──►│ Barrel shifter│──shift──┼────►│ (Fredkin     │          └──► CRC-8 signature
        │   │ (Fredkin)     │         │     │  swap chain) │
        │   └───────────────┘         │     └──────────────┘
        │   SLT/SLTU comparator ◄─────┤
        │                             ▼
        │                   Inverse adder/sub (A' = R ∓ B)
        └──────────────────────► compare A' vs A ──► error_flag
```

| Block | Implementation | Quantum cost |
|---|---|---|
| Full adder | 2 Peres gates | 8 per bit |
| Adder/subtractor | 32-bit ripple carry; B complemented by Feynman gates | 256 + 32 |
| Logic unit | AND = Toffoli, XOR = Feynman, OR = (A⊕B)⊕(A·B) | 224 |
| Barrel shifter | 5-stage logarithmic Fredkin network; right shifts reuse the left-shift path through conditional bit-reversal | ≈ 850 |
| SLT/SLTU | Feynman (sign ⊕ overflow) + Fredkin select | ≈ 10 |
| Output MUX | Fredkin swap chain, one-hot select | 800 |
| Flags | Zero via Peres+Feynman OR-tree | 157 |
| CRC-8 (poly 0x07) | Feynman-gate XOR network | ≈ 128 |

All unselected and intermediate values are kept as garbage outputs, so the design stays reversible.

## Error detection
- **Re-computation:** the arithmetic result goes through an inverse adder/subtractor to recover A′ (A′ = R − B for ADD, A′ = R + B for SUB/SLT/SLTU). If A′ ≠ A, `error_flag` is raised.
- **CRC-8 signature:** computed on the final result (polynomial x⁸ + x² + x + 1) and verified against a software CRC-8.
- **Detection boundary:** faults *before* the re-computation tap are detected. A fault injected *after* the output MUX changes the CRC but not `error_flag`; the testbench demonstrates this explicitly.

## Verification results

| Testbench | What it checks | Result |
|---|---|---|
| `tb_gates` | Bijectivity of all 4 reversible gates | 4 / 4 pass |
| `tb_adder_subtractor` | ADD/SUB corner cases + random vectors | 1022 / 1022 pass |
| `tb_barrel_shifter` | SLL/SRL/SRA, all shift amounts | 1696 / 1696 pass |
| `tb_comparator` | SLT/SLTU signed and unsigned | 1022 / 1022 pass |
| `tb_crc8` | CRC-8 values + error flag | 9 / 9 pass |
| `tb_alu_32bit` | All 10 ops vs golden model, corner + random | 1041 / 1041 pass |
| `tb_fault_injection` | Single-bit, multi-bit, stuck-at and carry-chain faults | 275 / 275 pass; **160 / 160 faults detected** |

## Repository structure
```
src/   reversible_gates.v        Feynman, Toffoli, Peres, Fredkin
       reversible_full_adder.v   adder_subtractor_32.v   logic_unit_32.v
       barrel_shifter_32.v       comparator_slt.v        output_mux_32.v
       flag_generator.v          crc8_detector.v         rv32i_reversible_alu.v (top)
tb/    one testbench per block + full-ALU and fault-injection testbenches
results/  simulation logs for every testbench
```

Full simulation logs for every testbench are in [`results/`](results/).

## How to implement

**Option A: Icarus Verilog (free, any OS)**
1. Install it: `sudo apt install iverilog` (Linux), `brew install icarus-verilog` (macOS), or the Windows installer from bleyer.org/icarus.
2. Clone the repo:
```bash
git clone https://github.com/Vipul-9/riscv-reversible-alu.git
cd riscv-reversible-alu
```
3. Run any testbench. Each one compiles all of `src/` and prints a pass/fail summary:
```bash
iverilog -g2012 -o alu src/*.v tb/tb_alu_32bit.v       && vvp alu   # full ALU, all 10 ops
iverilog -g2012 -o fi  src/*.v tb/tb_fault_injection.v && vvp fi    # fault detection
iverilog -g2012 -o g   src/*.v tb/tb_gates.v           && vvp g     # gate bijectivity
```
4. The block-level and full-ALU testbenches also write a `.vcd` waveform. Open it with GTKWave (`gtkwave *.vcd`).

**Option B: Vivado**
1. Create an RTL project → **Add Sources → design sources**: everything in `src/`.
2. **Add Sources → simulation sources**: the testbenches in `tb/`.
3. Right-click the testbench you want → **Set as Top** → **Run Behavioral Simulation**. The summary prints in the Tcl console.
4. For synthesis, set `rv32i_reversible_alu` as the top module.

**Using the ALU in your own design**
- Instantiate `rv32i_reversible_alu`. Drive `a`, `b` (32-bit) and `op_sel` (4-bit, table above).
- Read `result`, the flags (`flag_zero`, `flag_carry`, `flag_overflow`, `flag_sign`), `error_flag` and `crc_signature`.
- `error_flag` = 1 means the inverse re-computation disagreed with the inputs, so treat the result as faulty.

## Contributing
I'm open to open-source contributions and collaboration. Issues and pull requests are welcome.
You can reach me at **vipulatluri98@gmail.com**.
