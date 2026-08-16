`timescale 1ns/1ps

module tb_video;

    // ---- Expected geometry (mirror of the DUT parameters) ----
    localparam H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48;
    localparam V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33;
    localparam H_POL = 1'b0, V_POL = 1'b0;

    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;   // 800
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP;   // 525

    // 25.175 MHz pixel clock -> 39.722 ns period
    localparam real HALF_PERIOD = 19.861;

    reg pix_clk = 1'b0;
    always #(HALF_PERIOD) pix_clk = ~pix_clk;

    wire        hsync, vsync, de;
    wire [11:0] x, y;
    wire [7:0]  red, green, blue;

    video_timing_gen #(
        .H_ACTIVE(H_ACTIVE), .H_FP(H_FP), .H_SYNC(H_SYNC), .H_BP(H_BP),
        .V_ACTIVE(V_ACTIVE), .V_FP(V_FP), .V_SYNC(V_SYNC), .V_BP(V_BP),
        .H_POL(H_POL), .V_POL(V_POL)
    ) u_timing (
        .pix_clk(pix_clk),
        .hsync(hsync), .vsync(vsync), .de(de),
        .x(x), .y(y)
    );

    pattern_gen u_pattern (
        .x(x), .y(y), .de(de),
        .red(red), .green(green), .blue(blue)
    );

    // ---------------- Frame capture to PPM ----------------
    // Absolute path avoids hunting through the XSim run directory.
    // Use forward slashes even on Windows.
    localparam OUTFILE = "D:/FPGA/HDMI/frame.ppm";

    integer fd;
    integer pix_written = 0;
    reg     capturing   = 1'b0;
    reg     capture_done= 1'b0;

    initial begin
        fd = $fopen(OUTFILE, "w");
        if (fd == 0) begin
            $display("ERROR: cannot open %0s", OUTFILE);
            $finish;
        end
        $fwrite(fd, "P3\n%0d %0d\n255\n", H_ACTIVE, V_ACTIVE);
    end

    // Sample mid-cycle so combinational outputs have settled
    always @(negedge pix_clk) begin
        if (!capture_done) begin
            if (!capturing && de === 1'b1 && x == 0 && y == 0)
                capturing = 1'b1;

            if (capturing && de === 1'b1) begin
                $fwrite(fd, "%0d %0d %0d\n", red, green, blue);
                pix_written = pix_written + 1;
                if (pix_written == H_ACTIVE * V_ACTIVE) begin
                    capture_done = 1'b1;
                    $fclose(fd);
                    $display("[capture] wrote %0d pixels to %0s",
                             H_ACTIVE * V_ACTIVE, OUTFILE);
                end
            end
        end
    end

    // ---------------- Timing self-checks ----------------
    localparam FRAMES   = 1;
    localparam RUN_CLKS = H_TOTAL * V_TOTAL * FRAMES;

    integer clk_count      = 0;
    integer de_cycles      = 0;
    integer hs_cycles      = 0;
    integer vs_cycles      = 0;
    integer de_runs        = 0;
    integer cur_de_run     = 0;
    integer bad_de_runs    = 0;
    integer hs_runs        = 0;
    integer cur_hs_run     = 0;
    integer bad_hs_runs    = 0;
    integer line_starts    = 0;
    integer errors         = 0;

    reg de_d = 1'b0, hs_active_d = 1'b0;
    wire hs_active = (hsync === H_POL);
    wire vs_active = (vsync === V_POL);

    always @(negedge pix_clk) begin
        clk_count <= clk_count + 1;

        if (de === 1'b1)  de_cycles <= de_cycles + 1;
        if (hs_active)    hs_cycles <= hs_cycles + 1;
        if (vs_active)    vs_cycles <= vs_cycles + 1;

        // measure length of each contiguous de run (should be H_ACTIVE)
        if (de === 1'b1) cur_de_run <= cur_de_run + 1;
        else if (de_d === 1'b1) begin
            de_runs <= de_runs + 1;
            if (cur_de_run != H_ACTIVE) begin
                bad_de_runs <= bad_de_runs + 1;
                if (bad_de_runs < 4)
                    $display("[check] de run length %0d (expected %0d) at line %0d",
                             cur_de_run, H_ACTIVE, y);
            end
            cur_de_run <= 0;
        end
        de_d <= de;

        // measure each hsync pulse width (should be H_SYNC)
        if (hs_active) cur_hs_run <= cur_hs_run + 1;
        else if (hs_active_d) begin
            hs_runs <= hs_runs + 1;
            if (cur_hs_run != H_SYNC) begin
                bad_hs_runs <= bad_hs_runs + 1;
                if (bad_hs_runs < 4)
                    $display("[check] hsync width %0d (expected %0d)",
                             cur_hs_run, H_SYNC);
            end
            cur_hs_run <= 0;
        end
        hs_active_d <= hs_active;

        if (((clk_count + 1) % (H_TOTAL*100)) == 0)
            $display("[progress] %0d / %0d clocks, %0d pixels captured",
                     clk_count + 1, RUN_CLKS, pix_written);

        if (clk_count + 1 == RUN_CLKS) report_and_finish;
    end

    real fps;

    task report_and_finish;
        begin
            $display("");
            $display("=========== timing report (%0d frames) ===========", FRAMES);
            $display(" pixel clock        : %0.3f MHz", 1000.0/(2.0*HALF_PERIOD));
            $display(" clocks simulated   : %0d", clk_count + 1);

            check_int("active pixels    ", de_cycles, H_ACTIVE*V_ACTIVE*FRAMES);
            check_int("active lines     ", de_runs,   V_ACTIVE*FRAMES);
            check_int("hsync pulses     ", hs_runs,   V_TOTAL*FRAMES);
            check_int("hsync cycles tot ", hs_cycles, H_SYNC*V_TOTAL*FRAMES);
            check_int("vsync cycles tot ", vs_cycles, H_TOTAL*V_SYNC*FRAMES);
            check_int("bad de runs      ", bad_de_runs, 0);
            check_int("bad hsync widths ", bad_hs_runs, 0);

            fps = (1000.0/(2.0*HALF_PERIOD)) * 1.0e6 / (H_TOTAL*V_TOTAL);
            $display(" derived frame rate : %0.3f Hz", fps);
            $display(" derived line rate  : %0.3f kHz",
                     (1000.0/(2.0*HALF_PERIOD)) * 1000.0 / H_TOTAL);
            $display("=================================================");
            if (errors == 0) $display(" RESULT: all timing checks PASSED");
            else             $display(" RESULT: %0d check(s) FAILED", errors);
            $display("");
            $finish;
        end
    endtask

    task check_int(input [8*20:1] name, input integer got, input integer exp);
        begin
            if (got == exp)
                $display(" %0s : %0d  OK", name, got);
            else begin
                $display(" %0s : %0d  MISMATCH (expected %0d)", name, got, exp);
                errors = errors + 1;
            end
        end
    endtask

    // ---------------- Waveform window ----------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_video);
        // only keep the first ~3 lines of the first frame, else the VCD is huge
        #(2.0*HALF_PERIOD*3*H_TOTAL);
        $dumpoff;
    end

endmodule