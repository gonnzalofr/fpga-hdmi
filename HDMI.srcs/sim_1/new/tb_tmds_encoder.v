`timescale 1ns/1ps

// Self-checking testbench for a DVI TMDS encoder.
//
// Four independent properties are checked on every emitted symbol:
//   1. round trip  - decode(encode(d)) == d          (encoding is a bijection)
//   2. transitions - a data symbol has <= 5 edges    (transition minimisation works)
//   3. disparity   - an independently accumulated running disparity tracks cnt_r
//   4. bound       - |disparity| never exceeds DISP_LIMIT
// Control periods are checked against the four spec codewords, and cnt_r is
// checked to be cleared during blanking.

module tb_tmds_encoder;

    localparam DISP_LIMIT = 12;   // generous; real bound is smaller

    // spec codewords, indexed by {c1,c0}
    localparam [9:0] CTRL_00 = 10'b1101010100;
    localparam [9:0] CTRL_01 = 10'b0010101011;
    localparam [9:0] CTRL_10 = 10'b0101010100;
    localparam [9:0] CTRL_11 = 10'b1010101011;

    reg         clk = 1'b0;
    reg  [7:0]  d   = 8'h00;
    reg         c0  = 1'b0, c1 = 1'b0, de = 1'b0;
    wire [9:0]  q;

    always #5 clk = ~clk;

    tmds_encoder dut (.d(d), .clk(clk), .c0(c0), .c1(c1), .de(de), .q(q));

    // ---- pipeline the stimulus by one cycle to match the registered output ----
    reg [7:0] d_q;
    reg       c0_q, c1_q, de_q;
    reg       primed = 1'b0;

    always @(posedge clk) begin
        d_q  <= d;
        c0_q <= c0;
        c1_q <= c1;
        de_q <= de;
        primed <= 1'b1;
    end

    // ---- scoreboard ----
    integer errors      = 0;
    integer checked     = 0;
    integer ctrl_checked= 0;
    integer signed ref_disp = 0;
    integer max_abs_disp = 0;
    integer max_trans    = 0;

    // ---- helpers ----
    function [3:0] ones8(input [7:0] v);
        begin
            ones8 = v[0]+v[1]+v[2]+v[3]+v[4]+v[5]+v[6]+v[7];
        end
    endfunction

    function [4:0] ones10(input [9:0] v);
        begin
            ones10 = v[0]+v[1]+v[2]+v[3]+v[4]+v[5]+v[6]+v[7]+v[8]+v[9];
        end
    endfunction

    // number of 0->1 / 1->0 edges within the 10-bit symbol
    function [4:0] transitions(input [9:0] v);
        integer i;
        begin
            transitions = 0;
            for (i = 0; i < 9; i = i + 1)
                if (v[i] !== v[i+1]) transitions = transitions + 1;
        end
    endfunction

    // inverse of the TMDS encoding
    function [7:0] tmds_decode(input [9:0] sym);
        reg [7:0] m;
        reg [7:0] r;
        integer i;
        begin
            m = sym[9] ? ~sym[7:0] : sym[7:0];
            r[0] = m[0];
            for (i = 1; i < 8; i = i + 1)
                r[i] = sym[8] ? (m[i] ^ m[i-1]) : ~(m[i] ^ m[i-1]);
            tmds_decode = r;
        end
    endfunction

    task fail(input [8*40:1] what);
        begin
            errors = errors + 1;
            if (errors <= 12)
                $display("  FAIL [%0s] d=%02h q=%010b cnt_r=%0d ref=%0d",
                         what, d_q, q, dut.cnt_r, ref_disp);
        end
    endtask

    // ---- checking, one symbol per cycle, sampled mid-cycle ----
    reg [7:0]  dec;
    reg [4:0]  tr;
    reg [9:0]  want_ctrl;

    always @(negedge clk) begin
        if (primed) begin
            if (de_q) begin
                checked = checked + 1;

                dec = tmds_decode(q);
                if (dec !== d_q) fail("round trip");

                tr = transitions(q);
                if (tr > 5) fail("too many transitions");
                if (tr > max_trans) max_trans = tr;

                // independent disparity model over all ten transmitted bits
                ref_disp = ref_disp + (2 * ones10(q) - 10);
                if (ref_disp !== dut.cnt_r) fail("disparity mismatch");

                if (ref_disp > max_abs_disp)  max_abs_disp =  ref_disp;
                if (-ref_disp > max_abs_disp) max_abs_disp = -ref_disp;
                if (ref_disp > DISP_LIMIT || ref_disp < -DISP_LIMIT)
                    fail("disparity unbounded");
            end
            else begin
                ctrl_checked = ctrl_checked + 1;
                case ({c1_q, c0_q})
                    2'b00: want_ctrl = CTRL_00;
                    2'b01: want_ctrl = CTRL_01;
                    2'b10: want_ctrl = CTRL_10;
                    2'b11: want_ctrl = CTRL_11;
                endcase
                if (q !== want_ctrl) begin
                    errors = errors + 1;
                    if (errors <= 12)
                        $display("  FAIL [control code] c1c0=%b%b q=%010b want=%010b",
                                 c1_q, c0_q, q, want_ctrl);
                end
                if (dut.cnt_r !== 0) fail("cnt not cleared in blanking");
                ref_disp = 0;
            end
        end
    end

    // ---- stimulus ----
    integer i, j, k;
    integer seed = 32'hC0FFEE;

    task send(input [7:0] v);
        begin
            @(negedge clk);
            d = v; de = 1'b1; c0 = 1'b0; c1 = 1'b0;
        end
    endtask

    task blank(input b1, input b0, input integer n);
        integer m;
        begin
            for (m = 0; m < n; m = m + 1) begin
                @(negedge clk);
                de = 1'b0; c1 = b1; c0 = b0;
            end
        end
    endtask

    initial begin
        $display("");
        $display("=============== tmds_encoder testbench ===============");

        // 1. all four control codewords
        blank(1'b0, 1'b0, 4);
        blank(1'b0, 1'b1, 4);
        blank(1'b1, 1'b0, 4);
        blank(1'b1, 1'b1, 4);
        $display(" phase 1: control codewords          (%0d symbols)", ctrl_checked);

        // 2. exhaustive ascending
        for (i = 0; i < 256; i = i + 1) send(i[7:0]);
        $display(" phase 2: all 256 values ascending");

        // 3. exhaustive descending (different cnt history)
        for (i = 255; i >= 0; i = i - 1) send(i[7:0]);
        $display(" phase 3: all 256 values descending");

        // 4. every value held for 8 cycles - worst case for disparity drift
        for (i = 0; i < 256; i = i + 1)
            for (j = 0; j < 8; j = j + 1) send(i[7:0]);
        $display(" phase 4: each value repeated x8");

        // 5. pathological constants
        for (j = 0; j < 64; j = j + 1) send(8'hFE);
        for (j = 0; j < 64; j = j + 1) send(8'h00);
        for (j = 0; j < 64; j = j + 1) send(8'hFF);
        for (j = 0; j < 64; j = j + 1) send(8'hAA);
        $display(" phase 5: pathological constants");

        // 6. random, with blanking intervals interleaved
        for (k = 0; k < 40; k = k + 1) begin
            for (j = 0; j < 200; j = j + 1) send($random(seed));
            blank(1'b0, 1'b0, 6);
        end
        $display(" phase 6: random stream with blanking");

        @(negedge clk); @(negedge clk);

        $display("");
        $display(" data symbols checked : %0d", checked);
        $display(" control symbols      : %0d", ctrl_checked);
        $display(" max transitions seen : %0d  (limit 5)", max_trans);
        $display(" max |disparity|      : %0d", max_abs_disp);
        $display("");
        if (errors == 0) $display(" RESULT: all checks PASSED");
        else             $display(" RESULT: %0d error(s)", errors);
        $display("======================================================");
        $display("");
        $finish;
    end

endmodule