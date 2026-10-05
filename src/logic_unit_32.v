`timescale 1ns / 1ps
//============================================================================
// 32-Bit Reversible Logic Unit
//
// Implements bitwise AND, OR, XOR using only reversible gates.
//
// AND: Toffoli gate — R = 0 ⊕ (A · B) = A · B  (constant input C=0)
// OR:  A | B = (A ⊕ B) ⊕ (A · B)
//      → Feynman(A,B) gives A⊕B, Toffoli(A,B,0) gives A·B,
//        then Feynman(A⊕B, A·B) gives (A⊕B)⊕(A·B) = A|B
// XOR: Feynman gate — Q = A ⊕ B
//
// Each operation produces 32-bit result + garbage.
// The op_sel chooses which result to output (done at top level).
//============================================================================
module logic_unit_32 (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] result_and,
    output wire [31:0] result_or,
    output wire [31:0] result_xor,
    output wire [63:0] garbage_and,  // Toffoli: P=A, Q=B preserved
    output wire [63:0] garbage_or    // intermediate signals
);

    genvar i;

    // === AND: Toffoli(A, B, 0) → (A, B, A·B) ===
    generate
        for (i = 0; i < 32; i = i + 1) begin : and_gen
            toffoli_gate tg_and (
                .a(a[i]),
                .b(b[i]),
                .c(1'b0),              // constant input
                .p(garbage_and[2*i]),   // = A[i] (garbage)
                .q(garbage_and[2*i+1]),// = B[i] (garbage)
                .r(result_and[i])      // = A[i] · B[i]
            );
        end
    endgenerate

    // === XOR: Feynman(A, B) → (A, A⊕B) ===
    wire [31:0] xor_garbage;  // A passes through
    generate
        for (i = 0; i < 32; i = i + 1) begin : xor_gen
            feynman_gate fg_xor (
                .a(a[i]),
                .b(b[i]),
                .p(xor_garbage[i]),    // = A[i] (garbage)
                .q(result_xor[i])      // = A[i] ⊕ B[i]
            );
        end
    endgenerate

    // === OR: A|B = (A⊕B) ⊕ (A·B) ===
    // Reuse result_xor and result_and, combine with Feynman gate
    generate
        for (i = 0; i < 32; i = i + 1) begin : or_gen
            feynman_gate fg_or (
                .a(result_and[i]),        // A·B
                .b(result_xor[i]),        // A⊕B
                .p(garbage_or[2*i]),      // = A·B (garbage)
                .q(result_or[i])          // = (A·B) ⊕ (A⊕B) = A|B
            );
        end
    endgenerate

    // Remaining garbage_or slots filled with xor_garbage
    generate
        for (i = 0; i < 32; i = i + 1) begin : or_garbage_fill
            assign garbage_or[2*i+1] = xor_garbage[i];
        end
    endgenerate

endmodule
