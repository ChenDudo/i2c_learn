/*  i2cSlaveTop.v
 <http://www.opencores.org/cores//>
*/

`include "i2cSlave_define.v"
`include "i2cSlave.v"

module i2cSlaveTop (
	input			clk,
	input			rst,
	inout			sda,
	input			scl,
	output [7:0]	myReg0
);

i2cSlave u_i2cSlave(
	.clk	(clk),
	.rst	(rst),
	.sda	(sda),
	.scl	(scl),
	.myReg4	(8'h12),
	.myReg5	(8'h34),
	.myReg6	(8'h56),
	.myReg7	(8'h78),
	.myReg0	(myReg0),
	.myReg1	(),
	.myReg2	(),
	.myReg3	()
);

endmodule


 
