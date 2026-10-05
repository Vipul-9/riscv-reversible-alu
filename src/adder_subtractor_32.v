`timescale 1ns / 1ps
//============================================================================
// 32-Bit Reversible Adder/Subtractor
//
// Uses 32 reversible full adders in ripple-carry configuration.
// Subtraction: B is complemented (Feynman gates), Cin = 1 for two's complement.
//
// Ports:
//   sub_mode: 0 = ADD, 1 = SUB (A - B)
//   a, b:     32-bit operands
//   result:   32-bit sum/difference
//   cout:     carry/borrow out of MSB
//   garbage:  64 garbage bits (2 per full adder)
//============================================================================
module adder_subtractor_32 (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        sub_mode,   // 0=ADD, 1=SUB
    output wire [31:0] result,
    output wire        cout,       // carry out of bit 31
    output wire [63:0] garbage,    // 2 garbage bits per FA × 32
    output wire [31:0] b_xor       // B after XOR with sub_mode (preserved for reversibility)
);

    // B complement for subtraction using Feynman gates
    // Each Feynman: (sub_mode, B[i]) → (sub_mode, sub_mode ⊕ B[i])
    // When sub_mode=1, B[i] is complemented
    wire [31:0] b_comp;
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : b_complement
            feynman_gate fg_comp (
                .a(sub_mode),
                .b(b[i]),
                .p(),           // sub_mode passes through (not used)
                .q(b_comp[i])   // sub_mode ⊕ B[i]
            );
        end
    endgenerate

    assign b_xor = b_comp;

    // Carry chain
    wire [32:0] carry;
    assign carry[0] = sub_mode;  // Cin = 1 for subtraction (two's complement)

    // 32 reversible full adders
    generate
        for (i = 0; i < 32; i = i + 1) begin : fa_chain
            reversible_full_adder rfa (
                .a(a[i]),
                .b(b_comp[i]),
                .cin(carry[i]),
                .sum(result[i]),
                .cout(carry[i+1]),
                .garbage0(garbage[2*i]),
                .garbage1(garbage[2*i+1])
            );
        end
    endgenerate

    assign cout = carry[32];

endmodule
