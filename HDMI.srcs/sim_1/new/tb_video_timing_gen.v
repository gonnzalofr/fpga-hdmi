`timescale 1ns / 1ps

module tb_video_timing_gen;

    localparam CLK_PERIOD = 39.683;   // 25.2 MHz

    localparam H_TOTAL  = 800;
    localparam V_TOTAL  = 525;
    localparam H_ACTIVE = 640;
    localparam V_ACTIVE = 480;

    reg         clk = 0;
    wire        hsync, vsync, de;
    wire [11:0] x, y;

    always #(CLK_PERIOD/2.0) clk = ~clk;

    video_timing_gen dut (
        .pix_clk (clk),
        .hsync   (hsync),
        .vsync   (vsync),
        .de      (de),
        .x       (x),
        .y       (y)
    );

    integer errors = 0;

    task check;
        input [255:0] name;
        input integer got;
        input integer want;
        begin
            if (got === want)
                $display("PASS  %0s = %0d", name, got);
            else begin
                $display("FAIL  %0s = %0d, expected %0d", name, got, want);
                errors = errors + 1;
            end
        end
    endtask

    integer h_low, h_period, v_low;
    integer de_hits, i;
    integer first_de_x, first_de_y;

    initial begin
        // Sampling on negedge keeps us clear of the posedge where
        // every DUT output changes -- no race, no delta-cycle guessing.

        repeat (10) @(negedge clk);

        // ---- hsync pulse width and line period ----
        while (hsync !== 1'b1) @(negedge clk);   // get outside a pulse
        while (hsync !== 1'b0) @(negedge clk);   // now at a pulse start

        h_low = 0;
        while (hsync === 1'b0) begin
            h_low = h_low + 1;
            @(negedge clk);
        end

        h_period = h_low;
        while (hsync === 1'b1) begin
            h_period = h_period + 1;
            @(negedge clk);
        end

        check("hsync low width", h_low,    96);
        check("hsync period",    h_period, H_TOTAL);

        // ---- vsync pulse width, in pixel clocks ----
        while (vsync !== 1'b1) @(negedge clk);
        while (vsync !== 1'b0) @(negedge clk);

        v_low = 0;
        while (vsync === 1'b0) begin
            v_low = v_low + 1;
            @(negedge clk);
        end

        check("vsync low width", v_low, 2 * H_TOTAL);

        // ---- one full frame: active pixel count ----
        // vsync just ended, so we are at a known point in the frame.
        // Counting over exactly H_TOTAL*V_TOTAL clocks spans one frame
        // regardless of where in it we started.

        de_hits    = 0;
        first_de_x = -1;
        first_de_y = -1;

        for (i = 0; i < H_TOTAL * V_TOTAL; i = i + 1) begin
            if (de === 1'b1) begin
                de_hits = de_hits + 1;
                if (first_de_x < 0) begin
                    first_de_x = x;
                    first_de_y = y;
                end
                if (x >= H_ACTIVE || y >= V_ACTIVE) begin
                    $display("FAIL  de high at out-of-range (x=%0d y=%0d)", x, y);
                    errors = errors + 1;
                end
            end
            @(negedge clk);
        end

        check("active pixels per frame", de_hits, H_ACTIVE * V_ACTIVE);

        $display("first de sample was at x=%0d y=%0d", first_de_x, first_de_y);

        if (errors == 0)
            $display("\n=== ALL CHECKS PASSED ===");
        else
            $display("\n=== %0d CHECK(S) FAILED ===", errors);

        $finish;
    end

endmodule