module tmds_encoder(
input   wire [7:0] d,
input clk,
input   wire       c0,
input   wire       c1,
input   wire       de,
output  wire [9:0] q
);


wire signed [4:0] N1;
wire signed [4:0] N2;
reg  [8:0] stage1;
reg  [9:0] stage2;
reg [9:0] out;
assign N1 = count_one(d);
assign N2 = count_one(stage1[7:0]);

assign q = out;

reg signed [4:0] cnt_n, cnt_r;

initial begin
    cnt_r = 0;
end
    always @(posedge clk) begin
        if(de) begin
            out <= stage2;
            cnt_r <= cnt_n;
        end
        else begin
            out <=
            ((c0 && c1) ? 10'b1010101011:
            ((c0 && !c1) ? 10'b0010101011:
            ((!c0 && c1) ? 10'b0101010100:
            10'b1101010100)));
            
            cnt_r <= 0;
        end
        
        
    end 
    
    always @(*) begin
    
        
        if(N1 > 4 || (!d[0] && N1 == 4)) begin
            stage1[0] = d[0];
            stage1[1] = stage1[0] ~^ d[1];
            stage1[2] = stage1[1] ~^ d[2];
            stage1[3] = stage1[2] ~^ d[3];
            stage1[4] = stage1[3] ~^ d[4];
            stage1[5] = stage1[4] ~^ d[5];
            stage1[6] = stage1[5] ~^ d[6];
            stage1[7] = stage1[6] ~^ d[7];
            stage1[8] = 1'b0;
        end  
        else begin
            stage1[0] = d[0];
            stage1[1] = stage1[0] ^ d[1];
            stage1[2] = stage1[1] ^ d[2];
            stage1[3] = stage1[2] ^ d[3];
            stage1[4] = stage1[3] ^ d[4];
            stage1[5] = stage1[4] ^ d[5];
            stage1[6] = stage1[5] ^ d[6];
            stage1[7] = stage1[6] ^ d[7];
            stage1[8] = 1'b1;
        end
        
        if(cnt_r == 0||N2 == 4) begin
            if(!stage1[8]) begin
                stage2[7:0] = ~stage1[7:0];
                stage2[8] = stage1[8];
                stage2[9] = ~stage1[8];
                cnt_n = cnt_r - $signed(2*N2 - 8);
            end
            else begin
                stage2[7:0] = stage1[7:0];
                stage2[8] = stage1[8];
                stage2[9] = ~stage1[8];
                cnt_n = cnt_r + $signed(2*N2 - 8);
            end
        end
            else if((cnt_r > 0 && N2 > 4) || (cnt_r < 0 && N2 < 4)) begin
                stage2[7:0] = ~stage1[7:0];
                stage2[8] = stage1[8];
                stage2[9] = 1'b1;
                if(stage1[8]) begin
                    cnt_n = cnt_r - $signed(2*N2 - 8) + 2;
                end
                else begin
                    cnt_n = cnt_r - $signed(2*N2 - 8);
                end
            end
            else begin
                stage2[8:0] = stage1[8:0];
                stage2[9] = 1'b0;
                if(stage1[8]) begin
                    cnt_n = cnt_r + $signed(2*N2 - 8);
                end
                else begin
                    cnt_n = cnt_r + $signed(2*N2 - 8) - 2;
                end
            end   
    end


function [3:0]count_one(
input   [7:0] in
);
    begin
        count_one = in[0] + in[1] + in[2] + in[3] + in[4] + in[5] + in[6] + in[7];
    end  
endfunction

endmodule




