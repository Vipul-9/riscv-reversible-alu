`timescale 1ns / 1ps
//============================================================================
// 32-Bit Reversible Barrel Shifter
//
// 5-stage logarithmic Fredkin-gate network for SLL, SRL, SRA.
// Shift amount: shamt[4:0] (5 bits, 0–31 positions)
//
// Architecture:
//   Stage k (k=0..4): controlled by shamt[k], shifts by 2^k positions
//   Each stage: 32 Fredkin gates performing conditional swap
//
// Direction/mode control:
//   shift_dir:  0 = left (SLL), 1 = right (SRL/SRA)
//   arith_mode: 0 = logical (zero-fill), 1 = arithmetic (sign-extend, SRA)
//
// For right shift: we reverse the data, left-shift, then reverse again.
// This avoids duplicating the entire barrel shifter.
//
// Alternatively: we implement right-shift directly by swapping from MSB side.
//
// Implementation chosen: direct left/right via Fredkin with fill control.
//
// Quantum Cost: 5 stages × 32 Fredkin gates × QC(5) = 800
//               + direction/fill control ≈ 50
//               Total ≈ 850
//============================================================================
module barrel_shifter_32 (
    input  wire [31:0] data_in,
    input  wire [4:0]  shamt,       // shift amount (B[4:0] in RISC-V)
    input  wire        shift_dir,   // 0 = left (SLL), 1 = right (SRL/SRA)
    input  wire        arith_mode,  // 0 = logical, 1 = arithmetic (sign-extend)
    output wire [31:0] data_out,
    output wire [31:0] garbage_out  // bits displaced by shift
);

    // Fill bit: 0 for SLL/SRL, sign bit for SRA
    wire fill_bit = arith_mode & shift_dir & data_in[31];

    // Pre-reverse for right shift:
    // If shifting right, we bit-reverse the input, do a left shift,
    // then bit-reverse the output. This reuses the same left-shift logic.
    // However, for SRA we need to fill with sign bit on the MSB side after reverse.

    // Actually, let's implement this more directly for clarity and 
    // to count the reversible gates precisely.

    // For LEFT shift by 2^k:  data[i] ← data[i - 2^k] if shamt[k]=1
    // For RIGHT shift by 2^k: data[i] ← data[i + 2^k] if shamt[k]=1

    // We'll use conditional reversal (Fredkin swaps) + left-shift + conditional reversal.

    // Step 1: Conditional bit-reversal for right shift (using Fredkin gates)
    wire [31:0] stage_pre;
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : pre_reverse
            fredkin_gate fg_pre (
                .a(shift_dir),
                .b(data_in[i]),
                .c(data_in[31-i]),
                .p(),                  // shift_dir passes through
                .q(stage_pre[i]),      // swapped if shift_dir=1
                .r(stage_pre[31-i])
            );
        end
    endgenerate

    // Stage 0: shift by 1 (controlled by shamt[0])
    wire [31:0] stage0;
    generate
        for (i = 0; i < 32; i = i + 1) begin : shift_stage0
            if (i == 0) begin : s0_lsb
                // Bit 0 gets fill_bit when shifting
                fredkin_gate fg_s0 (
                    .a(shamt[0]),
                    .b(stage_pre[0]),
                    .c(fill_bit),
                    .p(),
                    .q(stage0[0]),
                    .r()               // garbage
                );
            end else begin : s0_rest
                fredkin_gate fg_s0 (
                    .a(shamt[0]),
                    .b(stage_pre[i]),
                    .c(stage_pre[i-1]),
                    .p(),
                    .q(stage0[i]),
                    .r()               // garbage
                );
            end
        end
    endgenerate

    // Stage 1: shift by 2 (controlled by shamt[1])
    wire [31:0] stage1;
    generate
        for (i = 0; i < 32; i = i + 1) begin : shift_stage1
            if (i < 2) begin : s1_low
                fredkin_gate fg_s1 (
                    .a(shamt[1]),
                    .b(stage0[i]),
                    .c(fill_bit),
                    .p(),
                    .q(stage1[i]),
                    .r()
                );
            end else begin : s1_rest
                fredkin_gate fg_s1 (
                    .a(shamt[1]),
                    .b(stage0[i]),
                    .c(stage0[i-2]),
                    .p(),
                    .q(stage1[i]),
                    .r()
                );
            end
        end
    endgenerate

    // Stage 2: shift by 4 (controlled by shamt[2])
    wire [31:0] stage2;
    generate
        for (i = 0; i < 32; i = i + 1) begin : shift_stage2
            if (i < 4) begin : s2_low
                fredkin_gate fg_s2 (
                    .a(shamt[2]),
                    .b(stage1[i]),
                    .c(fill_bit),
                    .p(),
                    .q(stage2[i]),
                    .r()
                );
            end else begin : s2_rest
                fredkin_gate fg_s2 (
                    .a(shamt[2]),
                    .b(stage1[i]),
                    .c(stage1[i-4]),
                    .p(),
                    .q(stage2[i]),
                    .r()
                );
            end
        end
    endgenerate

    // Stage 3: shift by 8 (controlled by shamt[3])
    wire [31:0] stage3;
    generate
        for (i = 0; i < 32; i = i + 1) begin : shift_stage3
            if (i < 8) begin : s3_low
                fredkin_gate fg_s3 (
                    .a(shamt[3]),
                    .b(stage2[i]),
                    .c(fill_bit),
                    .p(),
                    .q(stage3[i]),
                    .r()
                );
            end else begin : s3_rest
                fredkin_gate fg_s3 (
                    .a(shamt[3]),
                    .b(stage2[i]),
                    .c(stage2[i-8]),
                    .p(),
                    .q(stage3[i]),
                    .r()
                );
            end
        end
    endgenerate

    // Stage 4: shift by 16 (controlled by shamt[4])
    wire [31:0] stage4;
    generate
        for (i = 0; i < 32; i = i + 1) begin : shift_stage4
            if (i < 16) begin : s4_low
                fredkin_gate fg_s4 (
                    .a(shamt[4]),
                    .b(stage3[i]),
                    .c(fill_bit),
                    .p(),
                    .q(stage4[i]),
                    .r()
                );
            end else begin : s4_rest
                fredkin_gate fg_s4 (
                    .a(shamt[4]),
                    .b(stage3[i]),
                    .c(stage3[i-16]),
                    .p(),
                    .q(stage4[i]),
                    .r()
                );
            end
        end
    endgenerate

    // Step 3: Conditional bit-reversal for right shift (undo the pre-reversal)
    wire [31:0] stage_post;
    generate
        for (i = 0; i < 16; i = i + 1) begin : post_reverse
            fredkin_gate fg_post (
                .a(shift_dir),
                .b(stage4[i]),
                .c(stage4[31-i]),
                .p(),
                .q(stage_post[i]),
                .r(stage_post[31-i])
            );
        end
    endgenerate

    assign data_out    = stage_post;
    assign garbage_out = data_in;  // original input preserved as garbage for reversibility

endmodule
