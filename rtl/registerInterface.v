/* registerInterface.v
 <http://www.opencores.org/cores//>
*/

`include "i2cSlave_define.v"

module registerInterface (
	input  wire 		clk,
	input  wire [7:0]	addr,
	input  wire [7:0]	dataIn,
	input  wire 		writeEn,
	input  wire [7:0]	myReg4,
	input  wire [7:0]	myReg5,
	input  wire [7:0]	myReg6,
	input  wire [7:0]	myReg7,
	output reg  [7:0]	dataOut,
	output reg  [7:0]	myReg0,
	output reg  [7:0]	myReg1,
	output reg  [7:0]	myReg2,
	output reg  [7:0]	myReg3
);

// --- I2C Read
always @(posedge clk) begin
	case (addr)
		8'h00: dataOut <= myReg0;  
		8'h01: dataOut <= myReg1;  
		8'h02: dataOut <= myReg2;  
		8'h03: dataOut <= myReg3;  
		8'h04: dataOut <= myReg4;  
		8'h05: dataOut <= myReg5;  
		8'h06: dataOut <= myReg6;  
		8'h07: dataOut <= myReg7;  
		default: dataOut <= 8'h00;
	endcase
end

// --- I2C Write
always @(posedge clk) begin
	if (writeEn == 1'b1) begin
		case (addr)
			8'h00: myReg0 <= dataIn;  
			8'h01: myReg1 <= dataIn;
			8'h02: myReg2 <= dataIn;
			8'h03: myReg3 <= dataIn;
		endcase
	end
end

endmodule


 
