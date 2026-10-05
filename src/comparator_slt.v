`timescale 1ns / 1ps
//============================================================================
// Reversible Comparator for SLT / SLTU (Set Less Than)
//
// Implements RISC-V SLT and SLTU:
//   SLT:  rd = (rs1 < rs2) ? 1 : 0  (signed comparison)
//   SLTU: rd = (rs1 < rs2) ? 1 : 0  (unsigned comparison)
//
// Method:
//   1. Compute A - B using the adder/subtractor (reused from arithmetic core)
//   2. For SLT (signed):
//      - less = sign_bit XOR overflow
//      - sign_bit = result[31], overflow = cin_msb XOR cout_msb
//   3. For SLTU (unsigned):
//      - less = NOT(carry_out)  (borrow occurred)
//   4. Result = {31'b0, less}
//
// This module takes the subtraction results (sign, carry, overflow)
// and produces the 32-bit SLT/SLTU output.
//
// Quantum Cost: ~10 Feynman gates
//============================================================================
module comparator_slt (
    input  wire        sub_sign,     // result[31] of A-B
    input  wire        sub_cout,     // carry out of A-B
    input  wire        sub_overflow, // overflow of A-B
    input  wire        is_unsigned,  // 0=SLT (signed), 1=SLTU (unsigned)
    output wire [31:0] result,
    output wire        garbage       // intermediate garbage bit
);

    // SLT (signed): less = sign XOR overflow
    // When sign != overflow, A < B in signed arithmetic
    wire less_signed;
    feynman_gate fg_slt (
        .a(sub_sign),
        .b(sub_overflow),
        .p(),                   // garbage
        .q(less_signed)         // sign ⊕ overflow
    );

    // SLTU (unsigned): less = NOT(carry_out)
    // In subtraction, carry_out=0 means borrow → A < B (unsigned)
    wire less_unsigned = ~sub_cout;

    // Select between signed and unsigned result using Fredkin gate
    wire less;
    fredkin_gate fg_sel (
        .a(is_unsigned),
        .b(less_signed),
        .c(less_unsigned),
        .p(),                   // garbage
        .q(less),               // selected result
        .r(garbage)             // garbage
    );

    // Zero-extend to 32 bits
    assign result = {31'b0, less};

endmodule
