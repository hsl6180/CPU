`include "defines.vh"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/12/16 22:17:30
// Design Name: LL
// Module Name: my_mul
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module my_mul(
	input wire rst,							//复位
	input wire clk,							//时钟
	input wire signed_mul_i,				//是否为有符号乘法运算�?1位有符号
	input wire[31:0] muldata1_i,			//被乘�?
	input wire[31:0] muldata2_i,			//乘数
	input wire start_i,						//是否�?始乘法运�?
	input wire annul_i,						//是否取消乘法运算�?1位取�?
	output reg[63:0] result_o,				//乘法运算结果
	output reg ready_o						//乘法运算是否结束
);
	reg[31:0] temp_op1;
	reg[31:0] temp_op2;
	reg[5:0] cnt_mul;						 //记录进行到第几位�?32，stop
	reg[1:0] state;						    //除法器处于的状�?�（00空闲�?01�?始，11结束�?	
	reg[63:0] multiplicand;                 //加载被乘数，运算时每次左移一�?
    reg[31:0] multiplier;                   //加载乘数，运算时每次右移�?位，相当于y
    reg[63:0] product_temp;		            //临时结果（累加器�?
    wire[63:0] partial_product;            // 部分积：乘数末位�?1，由被乘数左移得到；乘数末位�?0，部分积�?0
	
	assign partial_product = multiplier[0] ? multiplicand:64'd0;        //若此时y的最低位�?1，则把x赋�?�给部分积partial_product，否则把0赋�?�给partial_product
	
	
	always @ (posedge clk) begin
		if (rst) begin
			state <= `MulFree;
			result_o <= {`ZeroWord,`ZeroWord};
			ready_o <= `MulResultNotReady;
		end else begin
			case(state)
			
				`MulFree: begin			//乘法器空�?
					if (start_i == `MulStart && annul_i == 1'b0) begin
							state <= `MulOn;					
							cnt_mul <= 6'b000000;
							if(signed_mul_i == 1'b1 && muldata1_i[31] == 1'b1) begin			//被乘数为负数
								temp_op1 = ~muldata1_i + 1;
							end else begin
								temp_op1 = muldata1_i;
							end
							if (signed_mul_i == 1'b1 && muldata2_i[31] == 1'b1 ) begin			//乘数为负�?
								temp_op2 = ~muldata2_i + 1;
							end else begin
								temp_op2 = muldata2_i;
							end
							multiplicand <= {32'b0,temp_op1};//被乘�?
							multiplier <= temp_op2;          //乘数
							product_temp <= {`ZeroWord, `ZeroWord};
					end else begin
						ready_o <= `MulResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
				`MulOn: begin				//乘法运算
					if(annul_i == 1'b0) begin			//进行乘法运算
						if(cnt_mul != 6'b100000) begin
							multiplicand <= {multiplicand[62:0],1'b0};  //被乘数x每次左移�?位�??
							multiplier <= {1'b0,multiplier[31:1]};      //相当于乘数y右移�?�?
							product_temp <= product_temp + partial_product;
							cnt_mul <= cnt_mul + 1;		                //乘法运算次数
						end	else begin
							if ((signed_mul_i == 1'b1) && ((muldata1_i[31] ^ muldata2_i[31]) == 1'b1)) begin
								product_temp <= (~product_temp + 1);
							end
							state <= `MulEnd;
							cnt_mul <= 6'b000000;
						end
					end else begin	
						state <= `MulFree;
					end
				end
				
				`MulEnd: begin			//乘法结束
					result_o <= product_temp;
					ready_o <= `MulResultReady;
					if (start_i == `MulStop) begin
						state <= `MulFree;
						ready_o <= `MulResultNotReady;
						result_o <= {`ZeroWord, `ZeroWord};
					end
				end
				
			endcase
		end
	end
endmodule