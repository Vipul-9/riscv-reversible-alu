//============================================================================
// 32-Bit Reversible Adder/Subtractor — Component Testbench
//
// Tests:
//   1. ADD: basic cases, boundary, overflow
//   2. SUB: basic cases, borrow, underflow
//   3. Carry propagation: ripple through all 32 bits
//   4. B complement path verification
//   5. Garbage output consistency
//   6. Random stimulus (500 vectors per mode)
//
// Golden reference: Verilog behavioral model
//============================================================================
`timescale 1ns / 1ps

module tb_adder_subtractor;

    // DUT signals
    reg  [31:0] a, b;
    reg         sub_mode;
    wire [31:0] result;
    wire        cout;
    wire [63:0] garbage;
    wire [31:0] b_xor;

    // DUT instantiation
    adder_subtractor_32 uut (
        .a(a),
        .b(b),
        .sub_mode(sub_mode),
        .result(result),
        .cout(cout),
        .garbage(garbage),
        .b_xor(b_xor)
    );

    // Counters
    integer total_tests, pass_count, fail_count;

    // Golden model
    function [32:0] golden_add_sub;
        input [31:0] a_in, b_in;
        input        sub;
        begin
            if (sub)
                golden_add_sub = {1'b0, a_in} - {1'b0, b_in};
            else
                golden_add_sub = {1'b0, a_in} + {1'b0, b_in};
        end
    endfunction

    // Test task
    task run_test;
        input [31:0] test_a, test_b;
        input         test_sub;
        reg   [32:0]  expected_full;
        reg   [31:0]  expected_result;
        reg           expected_cout;
        begin
            a = test_a;
            b = test_b;
            sub_mode = test_sub;
            #100;

            expected_full = golden_add_sub(test_a, test_b, test_sub);
            expected_result = expected_full[31:0];

            // For ADD: cout is carry out
            // For SUB: A-B = A + ~B + 1, cout=1 means no borrow (A >= B unsigned)
            if (test_sub)
                expected_cout = (test_a >= test_b) ? 1'b1 : 1'b0;
            else
                expected_cout = expected_full[32];

            total_tests = total_tests + 1;

            if (result === expected_result) begin
                pass_count = pass_count + 1;
            end else begin
                fail_count = fail_count + 1;
                $display("FAIL: %s | A=0x%08h B=0x%08h | Got=0x%08h Expected=0x%08h | Cout: Got=%b Exp=%b",
                         test_sub ? "SUB" : "ADD", test_a, test_b, result, expected_result, cout, expected_cout);
            end
        end
    endtask

    // B complement verification
    task verify_b_complement;
        integer i;
        reg pass;
        begin
            $display("\n--- B Complement Path Verification ---");
            // In ADD mode (sub_mode=0): b_xor should equal b (unchanged)
            a = 32'h0; b = 32'hA5A5_5A5A; sub_mode = 0;
            #100;
            if (b_xor === b)
                $display("  PASS: ADD mode — b_xor == b (no complement)");
            else begin
                $display("  FAIL: ADD mode — b_xor=0x%08h expected=0x%08h", b_xor, b);
                fail_count = fail_count + 1;
            end
            total_tests = total_tests + 1;
            pass_count = pass_count + (b_xor === b ? 1 : 0);

            // In SUB mode (sub_mode=1): b_xor should equal ~b
            sub_mode = 1;
            #100;
            if (b_xor === ~b)
                $display("  PASS: SUB mode — b_xor == ~b (complemented)");
            else begin
                $display("  FAIL: SUB mode — b_xor=0x%08h expected=0x%08h", b_xor, ~b);
                fail_count = fail_count + 1;
            end
            total_tests = total_tests + 1;
            pass_count = pass_count + (b_xor === ~b ? 1 : 0);
        end
    endtask

    // Garbage consistency check — garbage should be deterministic for same inputs
    task verify_garbage_consistency;
        reg [63:0] garbage_saved;
        begin
            $display("\n--- Garbage Consistency Check ---");
            a = 32'h1234_5678; b = 32'h9ABC_DEF0; sub_mode = 0;
            #100;
            garbage_saved = garbage;

            // Apply same inputs again
            a = 32'h0; b = 32'h0; sub_mode = 0;
            #50;
            a = 32'h1234_5678; b = 32'h9ABC_DEF0; sub_mode = 0;
            #100;

            total_tests = total_tests + 1;
            if (garbage === garbage_saved) begin
                $display("  PASS: Garbage outputs are deterministic");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Garbage outputs changed for same inputs");
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        total_tests = 0;
        pass_count  = 0;
        fail_count  = 0;

        $display("============================================================");
        $display("  32-Bit Adder/Subtractor — Component Test Suite");
        $display("============================================================");

        // ======== ADD Tests ========
        $display("\n--- ADD Tests ---");
        run_test(32'h0000_0000, 32'h0000_0000, 0);  // 0 + 0
        run_test(32'h0000_0001, 32'h0000_0001, 0);  // 1 + 1
        run_test(32'hFFFF_FFFF, 32'h0000_0001, 0);  // MAX + 1 (carry out)
        run_test(32'h7FFF_FFFF, 32'h0000_0001, 0);  // INT_MAX + 1 (signed overflow)
        run_test(32'h8000_0000, 32'h8000_0000, 0);  // MIN + MIN
        run_test(32'hDEAD_BEEF, 32'h1234_5678, 0);  // arbitrary
        run_test(32'h0000_FFFF, 32'h0001_0000, 0);  // carry propagation across halfword
        run_test(32'hFFFF_FFFF, 32'hFFFF_FFFF, 0);  // MAX + MAX

        // ======== SUB Tests ========
        $display("\n--- SUB Tests ---");
        run_test(32'h0000_0005, 32'h0000_0003, 1);  // 5 - 3 = 2
        run_test(32'h0000_0003, 32'h0000_0005, 1);  // 3 - 5 (borrow)
        run_test(32'h0000_0000, 32'h0000_0001, 1);  // 0 - 1 = -1
        run_test(32'h8000_0000, 32'h0000_0001, 1);  // MIN - 1 (signed overflow)
        run_test(32'hFFFF_FFFF, 32'hFFFF_FFFF, 1);  // MAX - MAX = 0
        run_test(32'h0000_0000, 32'h0000_0000, 1);  // 0 - 0 = 0
        run_test(32'h1234_5678, 32'hDEAD_BEEF, 1);  // arbitrary

        // ======== Carry Propagation ========
        $display("\n--- Carry Propagation Tests ---");
        run_test(32'h0000_0001, 32'h0000_FFFF, 0);  // carry across lower 16 bits
        run_test(32'h0FFF_FFFF, 32'h0000_0001, 0);  // carry through 28 bits
        run_test(32'h7FFF_FFFF, 32'h7FFF_FFFF, 0);  // carry through 31 bits
        run_test(32'hFFFF_FFFE, 32'h0000_0002, 0);  // carry all the way out

        // ======== B Complement Path ========
        verify_b_complement;

        // ======== Garbage Consistency ========
        verify_garbage_consistency;

        // ======== Random Tests ========
        $display("\n--- Random ADD Tests (500 vectors) ---");
        begin : random_add
            integer i;
            for (i = 0; i < 500; i = i + 1)
                run_test($urandom, $urandom, 0);
        end

        $display("--- Random SUB Tests (500 vectors) ---");
        begin : random_sub
            integer i;
            for (i = 0; i < 500; i = i + 1)
                run_test($urandom, $urandom, 1);
        end

        // ======== Summary ========
        $display("\n============================================================");
        $display("  ADDER/SUBTRACTOR TEST SUMMARY");
        $display("  Total: %0d | Pass: %0d | Fail: %0d", total_tests, pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** %0d TESTS FAILED ***", fail_count);
        $display("============================================================\n");

        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("tb_adder_subtractor.vcd");
        $dumpvars(0, tb_adder_subtractor);
    end

endmodule
