module pattern_gen (
    input  wire [11:0] x,
    input  wire [11:0] y,
    input  wire de,
    output wire [7:0]  red,
    output wire [7:0]  green,
    output wire [7:0]  blue
);
reg  [7:0] r = 0;
reg  [7:0] g = 0;
reg  [7:0] b = 0;

assign red = r;
assign green = g;
assign blue = b;

always @(*) begin
    if(de) begin
        r = ((x % 256)); 
        g = 8'd0;
        b = 8'd0;
    end
    else begin
        r = 8'd0;
        g = 8'd0;
        b = 8'd0;
    end
    
    
    



end












endmodule