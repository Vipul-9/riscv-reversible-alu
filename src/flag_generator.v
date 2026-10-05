`timescale 1ns / 1ps
//============================================================================
// Reversible Flag Generator
//
// Generates ALU status flags using reversible gates:
//   Z (Zero):     result == 0 (reversible OR-reduce tree + NOT)
//   C (Carry):    carry-out from MSB (direct from adder)
//   V (Overflow): signed overflow = cin_msb ⊕ cout_msb (Feynman gate)
//   S (Sign):     result[31] (MSB, direct wire)
//
// Only valid for arithmetic operations (ADD, SUB, SLT, SLTU).
// For logic/shift operations, flags may be ignored by the processor.
//
// Zero Flag Architecture:
//   5-level binary OR-reduce tree using Peres + Feynman gates.
//   Each 2-input OR(a,b) = (a⊕b) ⊕ (a·b):
//     Peres(a, b, 0)   → (a, a⊕b, a·b)       [QC = 4]
//     Feynman(a⊕b, a·b) → (a⊕b, a|b)          [QC = 1]
//   Final NOT via Feynman(1, or_all) → ~or_all  [QC = 1]
//
// Quantum Cost:
//   Z: 31 Peres (31×4=124) + 31 Feynman (31) + 1 Feynman (NOT) = 156
//   C: 0 (direct wire)
//   V: 1 Feynman gate = 1
//   S: 0 (direct wire)
//   Total: 157
//
// Garbage: 63 bits (zero flag) + 1 bit (overflow) = 64 bits
//============================================================================
module flag_generator (
    input  wire [31:0] result,
    input  wire        carry_out,     // from adder MSB
    input  wire        carry_in_msb,  // carry into bit 31
    output wire        flag_zero,     // Z: result is zero
    output wire        flag_carry,    // C: carry out
    output wire        flag_overflow, // V: signed overflow
    output wire        flag_sign,     // S: sign bit
    output wire [62:0] garbage_zero,     // OR-tree (62) + NOT (1) garbage
    output wire        garbage_overflow  // overflow Feynman garbage
);

    genvar i;

    // === Zero Flag: Reversible OR-reduce tree + NOT ===
    // OR-reduce all 32 result bits using a 5-level binary tree.
    // Each 2-input OR uses Peres(a,b,0) + Feynman(a⊕b, a·b).
    // Garbage per OR: 2 bits — Peres P (=a) and Feynman P (=a⊕b).

    // Level 1: OR adjacent pairs (32 → 16)
    wire [15:0] or_l1;
    wire [31:0] g_l1;   // 2 garbage per OR × 16 ORs
    generate
        for (i = 0; i < 16; i = i + 1) begin : or_level1
            wire xor_ab, and_ab;
            peres_gate pg (
                .a(result[2*i]),
                .b(result[2*i+1]),
                .c(1'b0),
                .p(g_l1[2*i]),       // garbage: a
                .q(xor_ab),          // a ⊕ b
                .r(and_ab)           // a · b
            );
            feynman_gate fg (
                .a(xor_ab),
                .b(and_ab),
                .p(g_l1[2*i+1]),     // garbage: a ⊕ b
                .q(or_l1[i])         // a | b
            );
        end
    endgenerate

    // Level 2: OR pairs (16 → 8)
    wire [7:0] or_l2;
    wire [15:0] g_l2;
    generate
        for (i = 0; i < 8; i = i + 1) begin : or_level2
            wire xor_ab, and_ab;
            peres_gate pg (
                .a(or_l1[2*i]),
                .b(or_l1[2*i+1]),
                .c(1'b0),
                .p(g_l2[2*i]),
                .q(xor_ab),
                .r(and_ab)
            );
            feynman_gate fg (
                .a(xor_ab),
                .b(and_ab),
                .p(g_l2[2*i+1]),
                .q(or_l2[i])
            );
        end
    endgenerate

    // Level 3: OR pairs (8 → 4)
    wire [3:0] or_l3;
    wire [7:0] g_l3;
    generate
        for (i = 0; i < 4; i = i + 1) begin : or_level3
            wire xor_ab, and_ab;
            peres_gate pg (
                .a(or_l2[2*i]),
                .b(or_l2[2*i+1]),
                .c(1'b0),
                .p(g_l3[2*i]),
                .q(xor_ab),
                .r(and_ab)
            );
            feynman_gate fg (
                .a(xor_ab),
                .b(and_ab),
                .p(g_l3[2*i+1]),
                .q(or_l3[i])
            );
        end
    endgenerate

    // Level 4: OR pairs (4 → 2)
    wire [1:0] or_l4;
    wire [3:0] g_l4;
    generate
        for (i = 0; i < 2; i = i + 1) begin : or_level4
            wire xor_ab, and_ab;
            peres_gate pg (
                .a(or_l3[2*i]),
                .b(or_l3[2*i+1]),
                .c(1'b0),
                .p(g_l4[2*i]),
                .q(xor_ab),
                .r(and_ab)
            );
            feynman_gate fg (
                .a(xor_ab),
                .b(and_ab),
                .p(g_l4[2*i+1]),
                .q(or_l4[i])
            );
        end
    endgenerate

    // Level 5: Final OR (2 → 1)
    wire or_all;
    wire [1:0] g_l5;
    wire xor_final, and_final;
    peres_gate pg_final (
        .a(or_l4[0]),
        .b(or_l4[1]),
        .c(1'b0),
        .p(g_l5[0]),
        .q(xor_final),
        .r(and_final)
    );
    feynman_gate fg_final (
        .a(xor_final),
        .b(and_final),
        .p(g_l5[1]),
        .q(or_all)
    );

    // NOT: flag_zero = ~or_all (using Feynman with constant 1)
    // When or_all=0 (all bits zero): 1⊕0 = 1 → flag_zero = 1
    // When or_all=1 (any bit set):   1⊕1 = 0 → flag_zero = 0
    wire g_not;
    feynman_gate fg_not (
        .a(1'b1),
        .b(or_all),
        .p(g_not),         // garbage: constant 1 pass-through
        .q(flag_zero)      // ~or_all
    );

    // Collect all zero-flag garbage: g_l1[31:0], g_l2[15:0], g_l3[7:0],
    //                                g_l4[3:0], g_l5[1:0], g_not
    // Total: 32 + 16 + 8 + 4 + 2 + 1 = 63 bits
    assign garbage_zero = {g_not, g_l5, g_l4, g_l3, g_l2, g_l1};

    // === Carry Flag ===
    assign flag_carry = carry_out;

    // === Overflow Flag ===
    // V = carry_in_msb ⊕ carry_out (using one Feynman gate)
    feynman_gate fg_overflow (
        .a(carry_in_msb),
        .b(carry_out),
        .p(garbage_overflow),   // garbage: carry_in_msb
        .q(flag_overflow)       // carry_in_msb ⊕ carry_out
    );

    // === Sign Flag ===
    assign flag_sign = result[31];

endmodule
