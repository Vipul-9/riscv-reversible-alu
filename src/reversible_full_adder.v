`timescale 1ns / 1ps
//============================================================================
// Reversible Full Adder — 1-bit, using two Peres gates
//
// Peres gate: P = A, Q = A ⊕ B, R = (A·B) ⊕ C
//
//   Stage 1 — Peres(A, B, 0):       P1=A,    Q1=A⊕B,        R1=A·B
//   Stage 2 — Peres(Q1, Cin, R1):   P2=A⊕B,  Q2=A⊕B⊕Cin,   R2=((A⊕B)·Cin)⊕(A·B)
//
//   Sum  = Q2 = A ⊕ B ⊕ Cin
//   Cout = R2 = (A·B) ⊕ (Cin·(A⊕B)) = Majority(A,B,Cin)
//
// Quantum Cost: 4 + 4 = 8
// Garbage: P1 (=A), P2 (=A⊕B) → 2 garbage outputs
//============================================================================
module reversible_full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout,
    output wire garbage0,  // = A (from Peres1.P)
    output wire garbage1   // = A ⊕ B (from Peres2.P)
);

    // Stage 1: Peres gate — c input is 0 (NOT cin)
    wire p1_p, p1_q, p1_r;
    peres_gate pg1 (
        .a(a),
        .b(b),
        .c(1'b0),
        .p(p1_p),   // = A
        .q(p1_q),   // = A ⊕ B
        .r(p1_r)    // = A · B
    );

    // Stage 2: Peres gate
    wire p2_p, p2_q, p2_r;
    peres_gate pg2 (
        .a(p1_q),   // A ⊕ B
        .b(cin),
        .c(p1_r),   // A · B
        .p(p2_p),   // = A ⊕ B (garbage)
        .q(p2_q),   // = A ⊕ B ⊕ Cin = Sum
        .r(p2_r)    // = ((A⊕B)·Cin) ⊕ (A·B) = Cout
    );

    assign sum      = p2_q;
    assign cout     = p2_r;
    assign garbage0 = p1_p;
    assign garbage1 = p2_p;

endmodule
