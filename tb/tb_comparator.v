//============================================================================
// Reversible Comparator (SLT/SLTU) — Component Testbench
//
// Tests signed (SLT) and unsigned (SLTU) comparisons by driving the
// comparator_slt module with pre-computed subtraction results.
//============================================================================
`timescale 1ns / 1ps

module tb_comparator;

    // We test the comparator_slt module by computing A-B externally
    // and feeding the subtraction results (sign, cout, overflow).

    // DUT signals
    reg         sub_sign, sub_cout, sub_overflow, is_unsigned;
    wire [31:0] result;
    wire        garbage;

    comparator_slt uut (
        .sub_sign(sub_sign),
        .sub_cout(sub_cout),
        .sub_overflow(sub_overflow),
        .is_unsigned(is_unsigned),
        .result(result),
        .garbage(garbage)
    );

    // Full adder/subtractor for generating inputs to comparator
    // We also instantiate the adder for end-to-end test
    reg  [31:0] a, b;
    wire [31:0] sub_result;
    wire        cout;
    wire [63:0] garb;
    wire [31:0] b_xor;

    adder_subtractor_32 u_sub (
        .a(a), .b(b), .sub_mode(1'b1),
        .result(sub_result), .cout(cout),
        .garbage(garb), .b_xor(b_xor)
    );

    integer total_tests, pass_count, fail_count;

    // End-to-end test: feed A and B, compute subtraction, drive comparator
    task test_slt;
        input [31:0] test_a, test_b;
        input        test_unsigned;
        reg [31:0]   expected;
        reg          overflow;
        begin
            a = test_a; b = test_b;
            #50;  // let subtractor settle

            // Compute overflow: (A[31] == B'[31]) && (Result[31] != A[31])
            // where B' = ~B (complemented for subtraction)
            overflow = (test_a[31] ^ (~test_b[31]) ^ 1'b1) & (sub_result[31] ^ test_a[31]);

            sub_sign     = sub_result[31];
            sub_cout     = cout;
            sub_overflow = overflow;
            is_unsigned  = test_unsigned;
            #50;  // let comparator settle

            if (test_unsigned)
                expected = (test_a < test_b) ? 32'd1 : 32'd0;
            else
                expected = ($signed(test_a) < $signed(test_b)) ? 32'd1 : 32'd0;

            total_tests = total_tests + 1;
            if (result === expected) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %s | A=0x%08h B=0x%08h | Got=%0d Exp=%0d | sign=%b cout=%b ovf=%b",
                         test_unsigned ? "SLTU" : "SLT ",
                         test_a, test_b, result[0], expected[0],
                         sub_sign, sub_cout, sub_overflow);
            end
        end
    endtask

    initial begin
        total_tests = 0; pass_count = 0; fail_count = 0;

        $display("============================================================");
        $display("  Reversible Comparator (SLT/SLTU) — Component Test Suite");
        $display("============================================================");

        // === SLT (signed) ===
        $display("\n--- SLT (Signed) Tests ---");
        test_slt(32'h0000_0001, 32'h0000_0002, 0);  // 1 < 2 → 1
        test_slt(32'h0000_0002, 32'h0000_0001, 0);  // 2 < 1 → 0
        test_slt(32'h0000_0000, 32'h0000_0000, 0);  // 0 < 0 → 0
        test_slt(32'hFFFF_FFFF, 32'h0000_0001, 0);  // -1 < 1 → 1
        test_slt(32'h0000_0001, 32'hFFFF_FFFF, 0);  // 1 < -1 → 0
        test_slt(32'h8000_0000, 32'h7FFF_FFFF, 0);  // MIN < MAX → 1
        test_slt(32'h7FFF_FFFF, 32'h8000_0000, 0);  // MAX < MIN → 0
        test_slt(32'h8000_0000, 32'h8000_0001, 0);  // MIN < MIN+1 → 1
        test_slt(32'hFFFF_FFFF, 32'hFFFF_FFFE, 0);  // -1 < -2 → 0
        test_slt(32'hFFFF_FFFE, 32'hFFFF_FFFF, 0);  // -2 < -1 → 1
        test_slt(32'h7FFF_FFFF, 32'h7FFF_FFFF, 0);  // MAX < MAX → 0
        test_slt(32'h8000_0000, 32'h8000_0000, 0);  // MIN < MIN → 0

        // === SLTU (unsigned) ===
        $display("\n--- SLTU (Unsigned) Tests ---");
        test_slt(32'h0000_0001, 32'h0000_0002, 1);  // 1 < 2 → 1
        test_slt(32'h0000_0002, 32'h0000_0001, 1);  // 2 < 1 → 0
        test_slt(32'h0000_0000, 32'h0000_0000, 1);  // 0 < 0 → 0
        test_slt(32'hFFFF_FFFF, 32'h0000_0001, 1);  // MAX < 1 → 0
        test_slt(32'h0000_0001, 32'hFFFF_FFFF, 1);  // 1 < MAX → 1
        test_slt(32'h0000_0000, 32'hFFFF_FFFF, 1);  // 0 < MAX → 1
        test_slt(32'hFFFF_FFFF, 32'hFFFF_FFFF, 1);  // MAX < MAX → 0
        test_slt(32'h8000_0000, 32'h7FFF_FFFF, 1);  // 0x80.. < 0x7F.. → 0 (unsigned)
        test_slt(32'h7FFF_FFFF, 32'h8000_0000, 1);  // 0x7F.. < 0x80.. → 1 (unsigned)
        test_slt(32'h0000_0000, 32'h0000_0001, 1);  // 0 < 1 → 1

        // === Random tests ===
        $display("\n--- Random SLT (500 vectors) ---");
        begin : r_slt
            integer i;
            for (i = 0; i < 500; i = i + 1)
                test_slt($urandom, $urandom, 0);
        end
        $display("--- Random SLTU (500 vectors) ---");
        begin : r_sltu
            integer i;
            for (i = 0; i < 500; i = i + 1)
                test_slt($urandom, $urandom, 1);
        end

        $display("\n============================================================");
        $display("  COMPARATOR TEST SUMMARY");
        $display("  Total: %0d | Pass: %0d | Fail: %0d", total_tests, pass_count, fail_count);
        if (fail_count == 0) $display("  *** ALL TESTS PASSED ***");
        else $display("  *** %0d TESTS FAILED ***", fail_count);
        $display("============================================================\n");
        $finish;
    end

    initial begin
        $dumpfile("tb_comparator.vcd");
        $dumpvars(0, tb_comparator);
    end

endmodule
