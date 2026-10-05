`timescale 1ns / 1ps
//============================================================================
// CRC-8 Error Detection Module (Reversible Implementation)
//
// CRC-8-CCITT Polynomial: x^8 + x^2 + x + 1 (0x07)
//
// Error Detection Strategy (Option B — Re-computation via inverse):
//   1. Forward path: ALU computes Result from (A, B, OpSel)
//   2. CRC computation: Compute CRC-8 of the 32-bit Result
//   3. Inverse path: Using Result + OpSel, re-compute A (or B)
//      using the inverse of the reversible ALU circuit
//   4. Compare: XOR original A with re-computed A
//      If any bit differs → error detected
//
// This module implements:
//   - CRC-8 computation of 32-bit input (purely Feynman-gate network)
//   - Input re-verification comparator
//
// CRC-8 is computed combinationally as a matrix multiply over GF(2).
// Each CRC bit is the XOR of specific input bits (determined by the
// polynomial's companion matrix raised to the 32nd power).
//
// For polynomial 0x07, the CRC-8 of a 32-bit word D[31:0] is:
//   (Derived from the CRC matrix — each row selects which input
//    bits to XOR together)
//
// Quantum Cost: ~128 Feynman gates (QC=128)
//============================================================================
module crc8_detector (
    input  wire [31:0] data_in,       
    input  wire [31:0] reference_in,  
    input  wire [31:0] recomputed_in,  
    output wire [7:0]  crc_out,       
    output wire error_flag
);

    wire [7:0] crc;

    // Byte 3 (MSB): data_in[31:24]
    // CRC-8 poly 0x07 (x^8+x^2+x+1), LFSR unrolled per byte, MSB-first
    // For byte m[7:0]: crc[0]=m7^m6^m0, crc[1]=m6^m1^m0, crc[2]=m6^m2^m1^m0,
    //   crc[3]=m7^m3^m2^m1, crc[4]=m4^m3^m2, crc[5]=m5^m4^m3,
    //   crc[6]=m6^m5^m4, crc[7]=m7^m6^m5

    wire [7:0] crc_b3;
    assign crc_b3[0] = data_in[31] ^ data_in[30] ^ data_in[24];
    assign crc_b3[1] = data_in[30] ^ data_in[25] ^ data_in[24];
    assign crc_b3[2] = data_in[30] ^ data_in[26] ^ data_in[25] ^ data_in[24];
    assign crc_b3[3] = data_in[31] ^ data_in[27] ^ data_in[26] ^ data_in[25];
    assign crc_b3[4] = data_in[28] ^ data_in[27] ^ data_in[26];
    assign crc_b3[5] = data_in[29] ^ data_in[28] ^ data_in[27];
    assign crc_b3[6] = data_in[30] ^ data_in[29] ^ data_in[28];
    assign crc_b3[7] = data_in[31] ^ data_in[30] ^ data_in[29];

    // Byte 2: data_in[23:16]
    wire [7:0] d2;
    assign d2 = data_in[23:16] ^ crc_b3;

    wire [7:0] crc_b2;
    assign crc_b2[0] = d2[7] ^ d2[6] ^ d2[0];
    assign crc_b2[1] = d2[6] ^ d2[1] ^ d2[0];
    assign crc_b2[2] = d2[6] ^ d2[2] ^ d2[1] ^ d2[0];
    assign crc_b2[3] = d2[7] ^ d2[3] ^ d2[2] ^ d2[1];
    assign crc_b2[4] = d2[4] ^ d2[3] ^ d2[2];
    assign crc_b2[5] = d2[5] ^ d2[4] ^ d2[3];
    assign crc_b2[6] = d2[6] ^ d2[5] ^ d2[4];
    assign crc_b2[7] = d2[7] ^ d2[6] ^ d2[5];

    // Byte 1: data_in[15:8]
    wire [7:0] d1;
    assign d1 = data_in[15:8] ^ crc_b2;

    wire [7:0] crc_b1;
    assign crc_b1[0] = d1[7] ^ d1[6] ^ d1[0];
    assign crc_b1[1] = d1[6] ^ d1[1] ^ d1[0];
    assign crc_b1[2] = d1[6] ^ d1[2] ^ d1[1] ^ d1[0];
    assign crc_b1[3] = d1[7] ^ d1[3] ^ d1[2] ^ d1[1];
    assign crc_b1[4] = d1[4] ^ d1[3] ^ d1[2];
    assign crc_b1[5] = d1[5] ^ d1[4] ^ d1[3];
    assign crc_b1[6] = d1[6] ^ d1[5] ^ d1[4];
    assign crc_b1[7] = d1[7] ^ d1[6] ^ d1[5];

    // Byte 0 (LSB): data_in[7:0]
    wire [7:0] d0;
    assign d0 = data_in[7:0] ^ crc_b1;

    assign crc[0] = d0[7] ^ d0[6] ^ d0[0];
    assign crc[1] = d0[6] ^ d0[1] ^ d0[0];
    assign crc[2] = d0[6] ^ d0[2] ^ d0[1] ^ d0[0];
    assign crc[3] = d0[7] ^ d0[3] ^ d0[2] ^ d0[1];
    assign crc[4] = d0[4] ^ d0[3] ^ d0[2];
    assign crc[5] = d0[5] ^ d0[4] ^ d0[3];
    assign crc[6] = d0[6] ^ d0[5] ^ d0[4];
    assign crc[7] = d0[7] ^ d0[6] ^ d0[5];

    assign crc_out = crc;

    // Re-verification: XOR reference vs recomputed
    wire [31:0] diff;

    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : verify
            feynman_gate fg_verify (
                .a(reference_in[i]),
                .b(recomputed_in[i]),
                .p(),            
                .q(diff[i])   
            );
        end
    endgenerate

    assign error_flag = |diff;

endmodule
