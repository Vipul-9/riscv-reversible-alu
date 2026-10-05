//============================================================================
// 32-Bit Reversible Barrel Shifter — Component Testbench
//
// Tests SLL, SRL, SRA with exhaustive shift amounts + random vectors
//============================================================================
`timescale 1ns / 1ps

module tb_barrel_shifter;

    reg  [31:0] data_in;
    reg  [4:0]  shamt;
    reg         shift_dir, arith_mode;
    wire [31:0] data_out, garbage_out;

    barrel_shifter_32 uut (
        .data_in(data_in), .shamt(shamt),
        .shift_dir(shift_dir), .arith_mode(arith_mode),
        .data_out(data_out), .garbage_out(garbage_out)
    );

    integer total_tests, pass_count, fail_count;

    function [31:0] golden_shift;
        input [31:0] din; input [4:0] sa;
        input dir, arith;
        begin
            if (dir == 0)      golden_shift = din << sa;
            else if (arith==0) golden_shift = din >> sa;
            else               golden_shift = $signed(din) >>> sa;
        end
    endfunction

    task run_test;
        input [31:0] td; input [4:0] ts;
        input tdir, tarith;
        reg [31:0] expected;
        begin
            data_in = td; shamt = ts;
            shift_dir = tdir; arith_mode = tarith;
            #100;
            expected = golden_shift(td, ts, tdir, tarith);
            total_tests = total_tests + 1;
            if (data_out === expected)
                pass_count = pass_count + 1;
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: dir=%b arith=%b | Data=0x%08h Shamt=%0d | Got=0x%08h Exp=0x%08h",
                         tdir, tarith, td, ts, data_out, expected);
            end
        end
    endtask

    task test_all_shamts;
        input [31:0] td; input tdir, tarith;
        integer s;
        begin
            for (s = 0; s < 32; s = s + 1)
                run_test(td, s[4:0], tdir, tarith);
        end
    endtask

    initial begin
        total_tests = 0; pass_count = 0; fail_count = 0;

        $display("============================================================");
        $display("  32-Bit Barrel Shifter — Component Test Suite");
        $display("============================================================");

        // SLL exhaustive
        $display("\n--- SLL: All shifts (data=0x00000001) ---");
        test_all_shamts(32'h0000_0001, 0, 0);
        $display("--- SLL: All shifts (data=0xDEADBEEF) ---");
        test_all_shamts(32'hDEAD_BEEF, 0, 0);

        // SRL exhaustive
        $display("\n--- SRL: All shifts (data=0x80000000) ---");
        test_all_shamts(32'h8000_0000, 1, 0);
        $display("--- SRL: All shifts (data=0xDEADBEEF) ---");
        test_all_shamts(32'hDEAD_BEEF, 1, 0);

        // SRA exhaustive (negative)
        $display("\n--- SRA: All shifts (negative: 0x80000000) ---");
        test_all_shamts(32'h8000_0000, 1, 1);
        // SRA exhaustive (positive)
        $display("--- SRA: All shifts (positive: 0x7FFFFFFF) ---");
        test_all_shamts(32'h7FFF_FFFF, 1, 1);

        // SRA sign extension checks
        $display("\n--- SRA: Sign extension cases ---");
        run_test(32'hF000_0000, 5'd4,  1, 1);
        run_test(32'h8000_0000, 5'd31, 1, 1);
        run_test(32'hFFFF_FFFF, 5'd1,  1, 1);
        run_test(32'hFFFF_FFFE, 5'd1,  1, 1);

        // Random tests
        $display("\n--- Random SLL (500) ---");
        begin : r_sll
            integer i;
            for (i = 0; i < 500; i = i + 1)
                run_test($urandom, $urandom % 32, 0, 0);
        end
        $display("--- Random SRL (500) ---");
        begin : r_srl
            integer i;
            for (i = 0; i < 500; i = i + 1)
                run_test($urandom, $urandom % 32, 1, 0);
        end
        $display("--- Random SRA (500) ---");
        begin : r_sra
            integer i;
            for (i = 0; i < 500; i = i + 1)
                run_test($urandom, $urandom % 32, 1, 1);
        end

        $display("\n============================================================");
        $display("  BARREL SHIFTER TEST SUMMARY");
        $display("  Total: %0d | Pass: %0d | Fail: %0d", total_tests, pass_count, fail_count);
        if (fail_count == 0) $display("  *** ALL TESTS PASSED ***");
        else $display("  *** %0d TESTS FAILED ***", fail_count);
        $display("============================================================\n");
        $finish;
    end

    initial begin
        $dumpfile("tb_barrel_shifter.vcd");
        $dumpvars(0, tb_barrel_shifter);
    end

endmodule
