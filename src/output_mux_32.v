`timescale 1ns / 1ps
//============================================================================
// 32-Bit Reversible Output MUX
//
// Selects one of the functional unit outputs based on OpSel using a
// Fredkin-gate swap chain — a fully reversible multiplexer.
//
// Architecture:
//   The default data path carries result_arith (ADD/SUB).
//   Each subsequent stage uses 32 Fredkin gates to conditionally swap
//   the chain data with an alternate functional unit output, controlled
//   by a one-hot decoded select signal.
//
//   Since the selects are one-hot, exactly one swap occurs (or none for
//   arith), routing the correct result to result_out. All unselected
//   inputs appear on the garbage outputs, preserving all information
//   for reversibility.
//
// Inputs:
//   result_arith[31:0]  — from adder/subtractor (ADD, SUB)
//   result_and[31:0]    — from logic unit (AND)
//   result_or[31:0]     — from logic unit (OR)
//   result_xor[31:0]    — from logic unit (XOR)
//   result_shift[31:0]  — from barrel shifter (SLL, SRL, SRA)
//   result_slt[31:0]    — from comparator (SLT, SLTU)
//   op_sel[3:0]         — operation selector
//
// OpSel encoding:
//   0000 = ADD, 0001 = SUB, 0010 = AND, 0011 = OR,
//   0100 = XOR, 0101 = SLL, 0110 = SRL, 0111 = SRA,
//   1000 = SLT, 1001 = SLTU
//
// Quantum Cost: 5 swap stages × 32 Fredkin gates × QC(5) = 800
//============================================================================
module output_mux_32 (
    input  wire [31:0] result_arith,
    input  wire [31:0] result_and,
    input  wire [31:0] result_or,
    input  wire [31:0] result_xor,
    input  wire [31:0] result_shift,
    input  wire [31:0] result_slt,
    input  wire [3:0]  op_sel,
    output wire [31:0] result_out,
    // Garbage outputs — unselected inputs preserved for reversibility
    output wire [31:0] garbage_and,
    output wire [31:0] garbage_or,
    output wire [31:0] garbage_xor,
    output wire [31:0] garbage_shift,
    output wire [31:0] garbage_slt
);

    // One-hot decode of functional unit selection from op_sel.
    // Control path — data path below is reversible via Fredkin gates.
    // Default (no select active): result_arith passes through.
    wire sel_and   = (op_sel == 4'b0010);                                // AND
    wire sel_or    = (op_sel == 4'b0011);                                // OR
    wire sel_xor   = (op_sel == 4'b0100);                                // XOR
    wire sel_shift = (op_sel[3:2] == 2'b01) & (op_sel[1] | op_sel[0]);  // SLL, SRL, SRA
    wire sel_slt   = (op_sel[3:1] == 3'b100);                           // SLT, SLTU

    // === Fredkin Swap Chain ===
    // Default: result_arith flows through the chain.
    // Each stage conditionally swaps the chain with an alternate input.
    // Fredkin behaviour:
    //   control=1 → Q=C, R=B  (swap: alternate goes to chain, chain to garbage)
    //   control=0 → Q=B, R=C  (pass: chain continues, alternate to garbage)

    genvar i;

    // Stage 1: Conditionally swap chain with result_and
    wire [31:0] chain1;
    generate
        for (i = 0; i < 32; i = i + 1) begin : swap_and
            fredkin_gate fg (
                .a(sel_and),
                .b(result_arith[i]),
                .c(result_and[i]),
                .p(),
                .q(chain1[i]),
                .r(garbage_and[i])
            );
        end
    endgenerate

    // Stage 2: Conditionally swap chain with result_or
    wire [31:0] chain2;
    generate
        for (i = 0; i < 32; i = i + 1) begin : swap_or
            fredkin_gate fg (
                .a(sel_or),
                .b(chain1[i]),
                .c(result_or[i]),
                .p(),
                .q(chain2[i]),
                .r(garbage_or[i])
            );
        end
    endgenerate

    // Stage 3: Conditionally swap chain with result_xor
    wire [31:0] chain3;
    generate
        for (i = 0; i < 32; i = i + 1) begin : swap_xor
            fredkin_gate fg (
                .a(sel_xor),
                .b(chain2[i]),
                .c(result_xor[i]),
                .p(),
                .q(chain3[i]),
                .r(garbage_xor[i])
            );
        end
    endgenerate

    // Stage 4: Conditionally swap chain with result_shift
    wire [31:0] chain4;
    generate
        for (i = 0; i < 32; i = i + 1) begin : swap_shift
            fredkin_gate fg (
                .a(sel_shift),
                .b(chain3[i]),
                .c(result_shift[i]),
                .p(),
                .q(chain4[i]),
                .r(garbage_shift[i])
            );
        end
    endgenerate

    // Stage 5: Conditionally swap chain with result_slt
    wire [31:0] chain5;
    generate
        for (i = 0; i < 32; i = i + 1) begin : swap_slt
            fredkin_gate fg (
                .a(sel_slt),
                .b(chain4[i]),
                .c(result_slt[i]),
                .p(),
                .q(chain5[i]),
                .r(garbage_slt[i])
            );
        end
    endgenerate

    assign result_out = chain5;

endmodule
