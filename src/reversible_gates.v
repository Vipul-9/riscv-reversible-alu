`timescale 1ns / 1ps
//============================================================================
// Reversible Gate Library
//
//  Gate      Mapping                                    Quantum Cost
//  Feynman   (A,B)   -> (A, A^B)                         1
//  Toffoli   (A,B,C) -> (A, B, (A&B)^C)                  5
//  Peres     (A,B,C) -> (A, A^B, (A&B)^C)                4
//  Fredkin   (A,B,C) -> (A, A'B + AC, A'C + AB)          5   (controlled swap)
//============================================================================

module feynman_gate (
    input  wire a, b,
    output wire p, q
);
    assign p = a;
    assign q = a ^ b;
endmodule

module toffoli_gate (
    input  wire a, b, c,
    output wire p, q, r
);
    assign p = a;
    assign q = b;
    assign r = (a & b) ^ c;
endmodule

module peres_gate (
    input  wire a, b, c,
    output wire p, q, r
);
    assign p = a;
    assign q = a ^ b;
    assign r = (a & b) ^ c;
endmodule

// Fredkin: a=0 -> pass (q=b, r=c); a=1 -> swap (q=c, r=b)
module fredkin_gate (
    input  wire a, b, c,
    output wire p, q, r
);
    assign p = a;
    assign q = (~a & b) | (a & c);
    assign r = (~a & c) | (a & b);
endmodule
