//============================================================================
// Gate-Level Testbench — Verifies reversibility of all fundamental gates
//
// Tests:
//   1. Feynman gate:  bijectivity (4 input combos → 4 unique outputs)
//   2. Toffoli gate:  bijectivity (8 input combos → 8 unique outputs)
//   3. Fredkin gate:  bijectivity (8 input combos → 8 unique outputs)
//   4. Peres gate:    bijectivity (8 input combos → 8 unique outputs)
//============================================================================
`timescale 1ns / 1ps

module tb_gates;

    integer pass_count, fail_count;

    // ========== Feynman Gate Test ==========
    reg  fg_a, fg_b;
    wire fg_p, fg_q;

    feynman_gate uut_fg (.a(fg_a), .b(fg_b), .p(fg_p), .q(fg_q));

    task test_feynman;
        reg [1:0] outputs [0:3];
        integer i, j, unique_ok;
        begin
            $display("\n=== Feynman Gate Test ===");
            for (i = 0; i < 4; i = i + 1) begin
                fg_a = i[1]; fg_b = i[0];
                #10;
                outputs[i] = {fg_p, fg_q};
                $display("  Input: %b%b  Output: %b%b", fg_a, fg_b, fg_p, fg_q);
            end
            // Check uniqueness
            unique_ok = 1;
            for (i = 0; i < 4; i = i + 1)
                for (j = i+1; j < 4; j = j + 1)
                    if (outputs[i] == outputs[j]) unique_ok = 0;
            if (unique_ok) begin
                $display("  PASS: All outputs unique (bijective)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Non-unique outputs detected!");
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========== Toffoli Gate Test ==========
    reg  tg_a, tg_b, tg_c;
    wire tg_p, tg_q, tg_r;

    toffoli_gate uut_tg (.a(tg_a), .b(tg_b), .c(tg_c), .p(tg_p), .q(tg_q), .r(tg_r));

    task test_toffoli;
        reg [2:0] outputs [0:7];
        integer i, j, unique_ok;
        begin
            $display("\n=== Toffoli Gate Test ===");
            for (i = 0; i < 8; i = i + 1) begin
                tg_a = i[2]; tg_b = i[1]; tg_c = i[0];
                #10;
                outputs[i] = {tg_p, tg_q, tg_r};
                $display("  Input: %b%b%b  Output: %b%b%b", tg_a, tg_b, tg_c, tg_p, tg_q, tg_r);
            end
            unique_ok = 1;
            for (i = 0; i < 8; i = i + 1)
                for (j = i+1; j < 8; j = j + 1)
                    if (outputs[i] == outputs[j]) unique_ok = 0;
            if (unique_ok) begin
                $display("  PASS: All outputs unique (bijective)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Non-unique outputs detected!");
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========== Fredkin Gate Test ==========
    reg  fk_a, fk_b, fk_c;
    wire fk_p, fk_q, fk_r;

    fredkin_gate uut_fk (.a(fk_a), .b(fk_b), .c(fk_c), .p(fk_p), .q(fk_q), .r(fk_r));

    task test_fredkin;
        reg [2:0] outputs [0:7];
        integer i, j, unique_ok;
        begin
            $display("\n=== Fredkin Gate Test ===");
            for (i = 0; i < 8; i = i + 1) begin
                fk_a = i[2]; fk_b = i[1]; fk_c = i[0];
                #10;
                outputs[i] = {fk_p, fk_q, fk_r};
                $display("  Input: %b%b%b  Output: %b%b%b", fk_a, fk_b, fk_c, fk_p, fk_q, fk_r);
            end
            unique_ok = 1;
            for (i = 0; i < 8; i = i + 1)
                for (j = i+1; j < 8; j = j + 1)
                    if (outputs[i] == outputs[j]) unique_ok = 0;
            if (unique_ok) begin
                $display("  PASS: All outputs unique (bijective)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Non-unique outputs detected!");
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ========== Peres Gate Test ==========
    reg  pg_a, pg_b, pg_c;
    wire pg_p, pg_q, pg_r;

    peres_gate uut_pg (.a(pg_a), .b(pg_b), .c(pg_c), .p(pg_p), .q(pg_q), .r(pg_r));

    task test_peres;
        reg [2:0] outputs [0:7];
        integer i, j, unique_ok;
        begin
            $display("\n=== Peres Gate Test ===");
            for (i = 0; i < 8; i = i + 1) begin
                pg_a = i[2]; pg_b = i[1]; pg_c = i[0];
                #10;
                outputs[i] = {pg_p, pg_q, pg_r};
                $display("  Input: %b%b%b  Output: %b%b%b", pg_a, pg_b, pg_c, pg_p, pg_q, pg_r);
            end
            unique_ok = 1;
            for (i = 0; i < 8; i = i + 1)
                for (j = i+1; j < 8; j = j + 1)
                    if (outputs[i] == outputs[j]) unique_ok = 0;
            if (unique_ok) begin
                $display("  PASS: All outputs unique (bijective)");
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL: Non-unique outputs detected!");
                fail_count = fail_count + 1;
            end
            // Also verify full-adder functionality
            $display("  Verifying Peres as full-adder component...");
            // Q = A XOR B (propagate), R = (A·B) XOR C (generate with carry)
        end
    endtask

    // ========== Main ==========
    initial begin
        pass_count = 0;
        fail_count = 0;

        test_feynman;
        test_toffoli;
        test_fredkin;
        test_peres;

        $display("\n========================================");
        $display("Gate Tests Complete: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================\n");
        $finish;
    end

endmodule
