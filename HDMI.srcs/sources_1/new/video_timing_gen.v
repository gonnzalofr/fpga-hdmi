module video_timing_gen #(
    parameter H_ACTIVE = 640, H_FP = 16, H_SYNC = 96, H_BP = 48,
    parameter V_ACTIVE = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33,
    parameter H_POL = 1'b0, V_POL = 1'b0
)(
    input  wire       pix_clk,
    output reg        hsync,
    output reg        vsync,
    output reg        de,
    output reg [11:0] x,
    output reg [11:0] y
);

reg [11:0] h_count = 0, v_count = 0 ;

localparam H_TOTAL      = H_ACTIVE + H_FP + H_SYNC + H_BP;
localparam H_SYNC_START = H_ACTIVE + H_FP;
localparam H_SYNC_END   = H_ACTIVE + H_FP + H_SYNC;
localparam V_TOTAL      = V_ACTIVE + V_FP + V_SYNC + V_BP;
localparam V_SYNC_START = V_ACTIVE + V_FP;
localparam V_SYNC_END   = V_ACTIVE + V_FP + V_SYNC;

    always @(posedge pix_clk) begin
        if(h_count == H_TOTAL - 1) begin
            h_count <= 0;
            v_count <= v_count + 1;
            if(v_count == V_TOTAL - 1) begin
                v_count <= 0;
            end
        end
        else begin
            h_count <= h_count + 1;
        end
    end

    always @(posedge pix_clk) begin
        x <= h_count;
        y <= v_count;
        
        
        hsync <= (h_count >= H_SYNC_START) && (h_count < H_SYNC_END) ? H_POL: ~H_POL;
        vsync <= (v_count >= V_SYNC_START) && (v_count < V_SYNC_END) ? V_POL: ~V_POL;
        
        de <= (h_count < H_ACTIVE && v_count < V_ACTIVE);
        
        
    end



endmodule