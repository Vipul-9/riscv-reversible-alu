`timescale 1ns / 1ps
//============================================================================
// 32-Bit RISC-V Compatible Reversible ALU — Top Level
//
// Supports all RV32I ALU operations:
//   0000: ADD     0001: SUB     0010: AND     0011: OR
//   0100: XOR     0101: SLL     0110: SRL     0111: SRA
//   1000: SLT     1001: SLTU
//
// Features:
//   - All arithmetic/logic built from reversible gates
//     (Peres, Toffoli, Fredkin, Feynman)
//   - Reversible barrel shifter for SLL/SRL/SRA
//   - Reversible comparator for SLT/SLTU
//   - Status flags: Zero, Carry, Overflow, Sign
//   - CRC-8 error detection with re-computation verification
//
// Gate Library:
//   Feynman (QC=1), Peres (QC=4), Toffoli (QC=5), Fredkin (QC=5)
//============================================================================
module rv32i_reversible_alu (
    input  wire [31:0] a,           // operand A (rs1)
    input  wire [31:0] b,           // operand B (rs2)
    input  wire [3:0]  op_sel,      // operation selector
    output wire [31:0] result,      // ALU result (rd)
    // Status flags
    output wire        flag_zero,
    output wire        flag_carry,
    output wire        flag_overflow,
    output wire        flag_sign,
    // CRC error detection
    output wire [7:0]  crc_signature,
    output wire        error_flag,
    // Garbage outputs (required for reversibility)
    output wire [63:0] garbage_arith,
    output wire [63:0] garbage_and,
    output wire [63:0] garbage_or,
    output wire [31:0] garbage_shift,
    output wire [31:0] b_xor_out
);

    // ====================================================================
    // Control signal derivation
    // ====================================================================
    wire sub_mode    = (op_sel == 4'b0001) |  // SUB
                       (op_sel == 4'b1000) |  // SLT  (needs subtraction)
                       (op_sel == 4'b1001);   // SLTU (needs subtraction)

    wire shift_dir   = (op_sel == 4'b0110) |  // SRL
                       (op_sel == 4'b0111);   // SRA

    wire arith_shift = (op_sel == 4'b0111);   // SRA only

    wire is_unsigned = (op_sel == 4'b1001);   // SLTU

    // ====================================================================
    // Arithmetic Unit: ADD / SUB
    // ====================================================================
    wire [31:0] arith_result;
    wire        arith_cout;
    wire [31:0] arith_b_xor;

    adder_subtractor_32 u_arith (
        .a(a),
        .b(b),
        .sub_mode(sub_mode),
        .result(arith_result),
        .cout(arith_cout),
        .garbage(garbage_arith),
        .b_xor(arith_b_xor)
    );

    assign b_xor_out = arith_b_xor;

    // ====================================================================
    // Logic Unit: AND / OR / XOR
    // ====================================================================
    wire [31:0] and_result, or_result, xor_result;

    logic_unit_32 u_logic (
        .a(a),
        .b(b),
        .result_and(and_result),
        .result_or(or_result),
        .result_xor(xor_result),
        .garbage_and(garbage_and),
        .garbage_or(garbage_or)
    );

    // ====================================================================
    // Barrel Shifter: SLL / SRL / SRA
    // ====================================================================
    wire [31:0] shift_result;

    barrel_shifter_32 u_shifter (
        .data_in(a),
        .shamt(b[4:0]),        // RISC-V: shift amount = rs2[4:0]
        .shift_dir(shift_dir),
        .arith_mode(arith_shift),
        .data_out(shift_result),
        .garbage_out(garbage_shift)
    );

    // ====================================================================
    // Comparator: SLT / SLTU
    // ====================================================================
    // Overflow for signed comparison: carry_in to bit 31 XOR carry_out of bit 31
    // We approximate carry_in_msb from the adder's internal carry chain.
    // For the Peres-based ripple carry, carry_in[31] is internal.
    // We can derive overflow as: (A[31] == B_comp[31]) && (result[31] != A[31])
    wire arith_overflow = (a[31] ^ arith_b_xor[31] ^ 1'b1) & (arith_result[31] ^ a[31]);
    // Simplified: overflow = (~(A[31]^B'[31])) & (Result[31]^A[31])
    // where B' = B XOR sub_mode

    wire [31:0] slt_result;
    wire        slt_garbage;

    comparator_slt u_comparator (
        .sub_sign(arith_result[31]),
        .sub_cout(arith_cout),
        .sub_overflow(arith_overflow),
        .is_unsigned(is_unsigned),
        .result(slt_result),
        .garbage(slt_garbage)
    );

    // ====================================================================
    // Output MUX
    // ====================================================================
    output_mux_32 u_mux (
        .result_arith(arith_result),
        .result_and(and_result),
        .result_or(or_result),
        .result_xor(xor_result),
        .result_shift(shift_result),
        .result_slt(slt_result),
        .op_sel(op_sel),
        .result_out(result)
    );

    // ====================================================================
    // Flag Generator
    // ====================================================================
    // Carry into MSB: for overflow calculation, use the XOR method
    wire carry_in_msb_approx = arith_result[31] ^ a[31] ^ arith_b_xor[31];

    flag_generator u_flags (
        .result(result),
        .carry_out(arith_cout),
        .carry_in_msb(carry_in_msb_approx),
        .flag_zero(flag_zero),
        .flag_carry(flag_carry),
        .flag_overflow(flag_overflow),
        .flag_sign(flag_sign)
    );

    // ====================================================================
    // CRC-8 Error Detection (Re-computation method)
    // ====================================================================
    // For re-computation verification, we need the inverse circuit to
    // reconstruct input A from the result. In a reversible circuit,
    // running the gates in reverse order with inverted control achieves this.
    //
    // For ADD: A = Result - B  (re-subtract)
    // For SUB: A = Result + B  (re-add)
    // For AND: A cannot be uniquely recovered (lossy) — use CRC of result only
    // For XOR: A = Result XOR B (self-inverse)
    //
    // Simplified approach: re-compute for arithmetic ops, CRC-only for others.

    // Re-computation for arithmetic operations (ADD/SUB)
    wire [31:0] recomputed_a;
    wire [63:0] recomp_garbage;
    wire        recomp_cout;
    wire [31:0] recomp_bxor;

    // Inverse of ADD is SUB, inverse of SUB is ADD
    wire recomp_sub = ~sub_mode;

    adder_subtractor_32 u_recomp (
        .a(arith_result),    // use result as input
        .b(b),               // same operand B
        .sub_mode(recomp_sub),
        .result(recomputed_a),
        .cout(recomp_cout),
        .garbage(recomp_garbage),
        .b_xor(recomp_bxor)
    );

    // CRC and verification
    // For non-arithmetic ops, recomputed_a won't match — use reference = recomputed
    // to suppress false errors. Error detection is meaningful for ADD/SUB/SLT/SLTU.
    wire is_arithmetic = (op_sel <= 4'b0001) | (op_sel >= 4'b1000);
    wire [31:0] ref_a    = a;
    wire [31:0] recomp_a = is_arithmetic ? recomputed_a : a;  // bypass for non-arith

    crc8_detector u_crc (
        .data_in(result),
        .reference_in(ref_a),
        .recomputed_in(recomp_a),
        .crc_out(crc_signature),
        .error_flag(error_flag)
    );

endmodule
