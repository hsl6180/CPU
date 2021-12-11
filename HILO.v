`include "lib/defines.vh"
module HILO(
    input wire clk,
    input wire rst,
    input wire we,
    input wire [31:0] hi_i,
    input wire [31:0] lo_i,
    output reg [31:0] hi_o,
    output reg [31:0] lo_o
    );
    
    always @ (posedge clk) begin 
        if (rst) begin 
            hi_o <= 32'b0;
            lo_o <= 32'b0 ;
        end 
        else if (we) begin 
            hi_o <= hi_i;
            lo_o <= lo_i;
        end
    end 
    
    
endmodule
