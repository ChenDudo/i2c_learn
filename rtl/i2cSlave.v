/* i2cSlave.v
 <http://www.opencores.org/cores//>
*/

`include "i2cSlave_define.v"
`include "registerInterface.v"
`include "serialInterface.v"

module i2cSlave (
	input  wire			clk,
	input  wire			rst,
	inout  wire			sda,
	input  wire			scl,
	input  wire [7:0]	myReg4,
	input  wire [7:0]	myReg5,
	input  wire [7:0]	myReg6,
	input  wire [7:0]	myReg7,
	output wire [7:0]	myReg0,
	output wire [7:0]	myReg1,
	output wire [7:0]	myReg2,
	output wire [7:0]	myReg3
);

registerInterface u_registerInterface(
	.clk		(clk),
	.addr		(regAddr),
	.dataIn		(dataToRegIF),
	.writeEn	(writeEn),
	.dataOut	(dataFromRegIF),
	.myReg0		(myReg0),
	.myReg1		(myReg1),
	.myReg2		(myReg2),
	.myReg3		(myReg3),
	.myReg4		(myReg4),
	.myReg5		(myReg5),
	.myReg6		(myReg6),
	.myReg7		(myReg7)
);

serialInterface u_serialInterface (
	.clk				(clk), 
	.rst				(rstSyncToClk | startEdgeDet), 
	.dataIn				(dataFromRegIF), 
	.dataOut			(dataToRegIF), 
	.writeEn			(writeEn),
	.regAddr			(regAddr), 
	.scl				(sclDelayed[`SCL_DEL_LEN-1]), 
	.sdaIn				(sdaDeb), 
	.sdaOut				(sdaOut), 
	.startStopDetState	(startStopDetState),
	.clearStartStopDet	(clearStartStopDet) 
);

// local wires and regs
wire 		clearStartStopDet;
wire 		sdaOut;
wire 		sdaIn;
wire 		rstSyncToClk;
wire 		writeEn;
wire [7:0] 	regAddr;
wire [7:0] 	dataToRegIF;
wire [7:0] 	dataFromRegIF;

reg 					sdaDeb;
reg 					sclDeb;
reg 					startEdgeDet;
reg [1:0]				startStopDetState;
reg [1:0]				rstPipe;
reg [`DEB_I2C_LEN-1:0] 	sdaPipe;
reg [`DEB_I2C_LEN-1:0] 	sclPipe;
reg [`SCL_DEL_LEN-1:0] 	sclDelayed;
reg [`SDA_DEL_LEN-1:0] 	sdaDelayed;

assign sda = (sdaOut == 1'b0) ? 1'b0 : 1'bz;
assign sdaIn = sda;
assign rstSyncToClk = rstPipe[1];

// sync rst rsing edge to clk
always @(posedge clk) begin
	if (rst == 1'b1)
		rstPipe <= 2'b11;
	else
		rstPipe <= {rstPipe[0], 1'b0};
end

// debounce sda and scl
always @(posedge clk) begin
	if (rstSyncToClk == 1'b1) begin
		sdaPipe <= {`DEB_I2C_LEN{1'b1}};
		sdaDeb <= 1'b1;
		sclPipe <= {`DEB_I2C_LEN{1'b1}};
		sclDeb <= 1'b1;
	end
	else begin
		sdaPipe <= {sdaPipe[`DEB_I2C_LEN-2:0], sdaIn};
		sclPipe <= {sclPipe[`DEB_I2C_LEN-2:0], scl};
		if (&sclPipe[`DEB_I2C_LEN-1:1] == 1'b1)
			sclDeb <= 1'b1;
		else if (|sclPipe[`DEB_I2C_LEN-1:1] == 1'b0)
			sclDeb <= 1'b0;
		if (&sdaPipe[`DEB_I2C_LEN-1:1] == 1'b1)
			sdaDeb <= 1'b1;
		else if (|sdaPipe[`DEB_I2C_LEN-1:1] == 1'b0)
			sdaDeb <= 1'b0;
	end
end

/* delay scl and sda
	sclDelayed is used as a delayed sampling clock
	sdaDelayed is only used for start stop detection
	Because sda hold time from scl falling is 0nS
	sda must be delayed with respect to scl to avoid incorrect
	detection of start/stop at scl falling edge. 
*/
always @(posedge clk) begin
	if (rstSyncToClk == 1'b1) begin
		sclDelayed <= {`SCL_DEL_LEN{1'b1}};
		sdaDelayed <= {`SDA_DEL_LEN{1'b1}};
	end
	else begin
		sclDelayed <= {sclDelayed[`SCL_DEL_LEN-2:0], sclDeb};
		sdaDelayed <= {sdaDelayed[`SDA_DEL_LEN-2:0], sdaDeb};
	end
end

// start stop detection
always @(posedge clk) begin
	if (rstSyncToClk == 1'b1) begin
		startStopDetState <= `NULL_DET;
		startEdgeDet <= 1'b0;
	end
	else begin
		if (sclDeb == 1'b1 && sdaDelayed[`SDA_DEL_LEN-2] == 1'b0 && sdaDelayed[`SDA_DEL_LEN-1] == 1'b1)
			startEdgeDet <= 1'b1;
		else
			startEdgeDet <= 1'b0;
		if (clearStartStopDet == 1'b1)
			startStopDetState <= `NULL_DET;
		else if (sclDeb == 1'b1) begin
			if (sdaDelayed[`SDA_DEL_LEN-2] == 1'b1 && sdaDelayed[`SDA_DEL_LEN-1] == 1'b0) 
				startStopDetState <= `STOP_DET;
			else if (sdaDelayed[`SDA_DEL_LEN-2] == 1'b0 && sdaDelayed[`SDA_DEL_LEN-1] == 1'b1)
				startStopDetState <= `START_DET;
		end
	end
end

endmodule


 
