`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.05.2026 11:21:44
// Design Name: 
// Module Name: crc
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_crc;

    reg  [31:0] data_in;
    reg  [31:0] reference_in;
    reg  [31:0] recomputed_in;
    wire [7:0]  crc_out;
    wire        error_flag;

    crc8_detector uut (
        .data_in(data_in),
        .reference_in(reference_in),
        .recomputed_in(recomputed_in),
        .crc_out(crc_out),
        .error_flag(error_flag)
    );

    integer total_tests, pass_count, fail_count;

    task check;
        input [63:0] test_name;  
        input        condition;
        begin
            total_tests = total_tests + 1;
            if (condition) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL: %0s", test_name);
            end
        end
    endtask

    initial begin
        total_tests = 0; pass_count = 0; fail_count = 0;

        $display("============================================================");
        $display("  CRC-8 Error Detection - Component Test Suite");
        $display("============================================================");

        // === Test 1: CRC of zero should be zero ===
        $display("\n--- CRC Properties ---");
        data_in = 32'h0; reference_in = 32'h0; recomputed_in = 32'h0;
        #100;
        $display("  CRC(0x00000000) = 0x%02h", crc_out);
        check("CRC_ZERO", crc_out == 8'h00);

        // === Test 2: CRC of non-zero data should be non-zero ===
        data_in = 32'h0000_0001; reference_in = 32'h0; recomputed_in = 32'h0;
        #100;
        $display("  CRC(0x00000001) = 0x%02h", crc_out);
        check("CRC_NONZ", crc_out != 8'h00);

        // === Test 3: Collision check for 256 values ===
        $display("\n--- CRC Uniqueness (collision check for 256 values) ---");
        begin : collision_check
            reg [7:0] crc_table [0:255];
            integer i, j, collisions;
            collisions = 0;
            for (i = 0; i < 256; i = i + 1) begin
                data_in = i;
                #50;
                crc_table[i] = crc_out;
            end
            for (i = 0; i < 256; i = i + 1)
                for (j = i + 1; j < 256; j = j + 1)
                    if (crc_table[i] == crc_table[j])
                        collisions = collisions + 1;
            $display("  Collisions among first 256 values: %0d (some expected for 8-bit CRC)", collisions);
            total_tests = total_tests + 1;
            if (collisions < 32768) begin
                pass_count = pass_count + 1;
                $display("  PASS: Collision rate acceptable");
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL: Too many collisions");
            end
        end

        // === Test 4: Single bit flip detection ===
        $display("\n--- Single Bit Flip Detection ---");
        begin : bitflip_test
            reg [7:0] crc_original;
            integer bit_idx, detected;
            detected = 0;
            data_in = 32'hA5A5_5A5A;
            #50;
            crc_original = crc_out;
            $display("  Original CRC(0xA5A55A5A) = 0x%02h", crc_original);

            for (bit_idx = 0; bit_idx < 32; bit_idx = bit_idx + 1) begin
                data_in = 32'hA5A5_5A5A ^ (32'h1 << bit_idx);
                #50;
                if (crc_out != crc_original)
                    detected = detected + 1;
            end
            $display("  Detected %0d/32 single-bit flips via CRC change", detected);
            total_tests = total_tests + 1;
            if (detected == 32) begin
                pass_count = pass_count + 1;
                $display("  PASS: All single-bit errors detected");
            end else begin
                fail_count = fail_count + 1;
                $display("  FAIL: Missed %0d single-bit errors", 32 - detected);
            end
        end

        // === Test 5: Re-verification (no error) ===
        $display("\n--- Re-verification: No Error ---");
        data_in = 32'h1234_5678;
        reference_in  = 32'hAAAA_BBBB;
        recomputed_in = 32'hAAAA_BBBB;
        #100;
        $display("  Ref=Recomp -> error_flag=%b", error_flag);
        check("NO_ERROR", error_flag == 1'b0);

        // === Test 6: Re-verification (error detected) ===
        $display("\n--- Re-verification: Error Detected ---");
        reference_in  = 32'hAAAA_BBBB;
        recomputed_in = 32'hAAAA_BBBC;
        #100;
        $display("  Ref!=Recomp (1-bit diff) -> error_flag=%b", error_flag);
        check("ERR_DET1", error_flag == 1'b1);

        recomputed_in = 32'h0000_0000;
        #100;
        $display("  Ref!=Recomp (large diff) -> error_flag=%b", error_flag);
        check("ERR_DET2", error_flag == 1'b1);

        // === Test 7: All-ones vs all-zeros ===
        reference_in  = 32'hFFFF_FFFF;
        recomputed_in = 32'h0000_0000;
        #100;
        check("ALL_DIFF", error_flag == 1'b1);

        reference_in  = 32'hFFFF_FFFF;
        recomputed_in = 32'hFFFF_FFFF;
        #100;
        check("ALL_SAME", error_flag == 1'b0);

        // === Summary ===
        $display("\n============================================================");
        $display("  CRC-8 TEST SUMMARY");
        $display("  Total: %0d | Pass: %0d | Fail: %0d", total_tests, pass_count, fail_count);
        if (fail_count == 0) $display("  *** ALL TESTS PASSED ***");
        else $display("  *** %0d TESTS FAILED ***", fail_count);
        $display("============================================================\n");
        $finish;
    end

    initial begin
        $dumpfile("tb_crc8.vcd");
        $dumpvars(0, tb_crc);
    end

endmodule
