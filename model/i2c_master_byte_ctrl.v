//  $Id: i2c_master_byte_ctrl.v,v 1.1 2008-11-08 13:15:10 sfielding Exp $
//  $Date: 2008-11-08 13:15:10 $
//  $Revision: 1.1 $
//  $Author: sfielding $
//  $Locker:  $
//  $State: Exp $
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.7  2004/02/18 11:40:46  rherveille
//               Fixed a potential bug in the statemachine. During a 'stop' 2 cmd_ack signals were generated. Possibly canceling a new start command.
//
//               Revision 1.6  2003/08/09 07:01:33  rherveille
//               Fixed a bug in the Arbitration Lost generation caused by delay on the (external) sda line.
//               Fixed a potential bug in the byte controller's host-acknowledge generation.
//
//               Revision 1.5  2002/12/26 15:02:32  rherveille
//               Core is now a Multimaster I2C controller
//
//               Revision 1.4  2002/11/30 22:24:40  rherveille
//               Cleaned up code
//
//               Revision 1.3  2001/11/05 11:59:25  rherveille
//               Fixed wb_ack_o generation bug.
//               Fixed bug in the byte_controller statemachine.
//               Added headers.

// synopsys translate_off
`include "..\rtl\timescale.v"
// synopsys translate_on

`include "i2c_master_defines.v"
`include "i2c_master_bit_ctrl.v"

module i2c_master_byte_ctrl (
	input  wire			clk,			// master clock 
	input  wire			rst,			// synchronous active high reset 
	input  wire			nReset,			// asynchronous active low reset 
	input  wire			ena,			// core enable signal 
	input  wire	[15:0] 	clk_cnt,		// 4x SCL 
	input  wire			start, 
	input  wire			stop, 
	input  wire			read, 
	input  wire			write, 
	input  wire			ack_in, 
	input  wire	[7:0] 	din,
	input  wire			scl_i, 
	input  wire			sda_i, 
	output reg			cmd_ack, 
	output reg			ack_out, 
	output wire	[7:0] 	dout, 
	output wire			i2c_busy, 
	output wire			i2c_al, 
	output wire			scl_o, 
	output wire			scl_oen, 
	output wire			sda_o, 
	output wire			sda_oen 
);

	// Variable declarations
	// statemachine
	parameter [4:0] ST_IDLE  = 5'b0_0000;
	parameter [4:0] ST_START = 5'b0_0001;
	parameter [4:0] ST_READ  = 5'b0_0010;
	parameter [4:0] ST_WRITE = 5'b0_0100;
	parameter [4:0] ST_ACK   = 5'b0_1000;
	parameter [4:0] ST_STOP  = 5'b1_0000;

	// signals for bit_controller
	reg [3:0] core_cmd;
	reg       core_txd;
	wire      core_ack, core_rxd;

	// signals for shift register
	reg [7:0] sr; 			//8bit shift register
	reg       shift, ld;

	// signals for state machine
	wire      go;
	reg [2:0] dcnt;
	wire      cnt_done;

	// Module body
	// hookup bit_controller
	i2c_master_bit_ctrl bit_controller (
		.clk     ( clk      ),
		.rst     ( rst      ),
		.nReset  ( nReset   ),
		.ena     ( ena      ),
		.clk_cnt ( clk_cnt  ),
		.cmd     ( core_cmd ),
		.cmd_ack ( core_ack ),
		.busy    ( i2c_busy ),
		.al      ( i2c_al   ),
		.din     ( core_txd ),
		.dout    ( core_rxd ),
		.scl_i   ( scl_i    ),
		.scl_o   ( scl_o    ),
		.scl_oen ( scl_oen  ),
		.sda_i   ( sda_i    ),
		.sda_o   ( sda_o    ),
		.sda_oen ( sda_oen  )
	);

	// generate go-signal
	assign go = (read | write | stop) & ~cmd_ack;
	// assign dout output to shift-register
	assign dout = sr;

	// generate shift register
	always @(posedge clk or negedge nReset)
		if (!nReset)
			sr <= #1 8'h0;
		else if (rst)
			sr <= #1 8'h0;
		else if (ld)
			sr <= #1 din;
		else if (shift)
			sr <= #1 {sr[6:0], core_rxd};

	// generate counter
	always @(posedge clk or negedge nReset)
		if (!nReset)
		dcnt <= #1 3'h0;
		else if (rst)
		dcnt <= #1 3'h0;
		else if (ld)
		dcnt <= #1 3'h7;
		else if (shift)
		dcnt <= #1 dcnt - 3'h1;

	assign cnt_done = ~(|dcnt);

	// state machine
	reg [4:0] c_state; // synopsis enum_state
	always @(posedge clk or negedge nReset)
		if (!nReset) begin
			core_cmd <= #1 `I2C_CMD_NOP;
			core_txd <= #1 1'b0;
			shift	 <= #1 1'b0;
			ld		 <= #1 1'b0;
			cmd_ack	 <= #1 1'b0;
			c_state	 <= #1 ST_IDLE;
			ack_out	 <= #1 1'b0;
		end
		else if (rst | i2c_al) begin
			core_cmd <= #1 `I2C_CMD_NOP;
			core_txd <= #1 1'b0;
			shift	 <= #1 1'b0;
			ld		 <= #1 1'b0;
			cmd_ack	 <= #1 1'b0;
			c_state	 <= #1 ST_IDLE;
			ack_out	 <= #1 1'b0;
		 end
		else begin
			// initially reset all signals
			core_txd <= #1 sr[7];
			shift	 <= #1 1'b0;
			ld		 <= #1 1'b0;
			cmd_ack	 <= #1 1'b0;
			case (c_state) // synopsys full_case parallel_case
			ST_IDLE:
				if (go) begin
					if (start) begin
						c_state	<= #1 ST_START;
						core_cmd <= #1 `I2C_CMD_START;
					end
					else if (read) begin
						c_state	<= #1 ST_READ;
						core_cmd <= #1 `I2C_CMD_READ;
					end
					else if (write) begin
						c_state	<= #1 ST_WRITE;
						core_cmd <= #1 `I2C_CMD_WRITE;
					end
					else begin // stop
						c_state	<= #1 ST_STOP;
						core_cmd <= #1 `I2C_CMD_STOP;
					end
					ld <= #1 1'b1;
				end
			ST_START:
				if (core_ack) begin
					if (read) begin
						c_state	<= #1 ST_READ;
						core_cmd <= #1 `I2C_CMD_READ;
					end
					else begin
						c_state	<= #1 ST_WRITE;
						core_cmd <= #1 `I2C_CMD_WRITE;
					end
					ld <= #1 1'b1;
				end

			ST_WRITE:
				if (core_ack)
					if (cnt_done) begin
						c_state	<= #1 ST_ACK;
						core_cmd <= #1 `I2C_CMD_READ;
					end
				else begin
					c_state	<= #1 ST_WRITE;		 // stay in same state
					core_cmd <= #1 `I2C_CMD_WRITE; // write next bit
					shift	<= #1 1'b1;
				end

			ST_READ:
				if (core_ack) begin
					if (cnt_done) begin
						c_state	 <= #1 ST_ACK;
						core_cmd <= #1 `I2C_CMD_WRITE;
					end
					else begin
						c_state	 <= #1 ST_READ;		 // stay in same state
						core_cmd <= #1 `I2C_CMD_READ; // read next bit
					end
					shift	 <= #1 1'b1;
					core_txd <= #1 ack_in;
				end

			ST_ACK:
				if (core_ack) begin
					 if (stop) begin
						c_state	<= #1 ST_STOP;
						core_cmd <= #1 `I2C_CMD_STOP;
					 end
					 else begin
						c_state	<= #1 ST_IDLE;
						core_cmd <= #1 `I2C_CMD_NOP;
						// generate command acknowledge signal
						cmd_ack	<= #1 1'b1;
					end
					// assign ack_out output to bit_controller_rxd (contains last received bit)
					ack_out <= #1 core_rxd;
					core_txd <= #1 1'b1;
				end
				else
					core_txd <= #1 ack_in;

			ST_STOP:
				if (core_ack) begin
					c_state	<= #1 ST_IDLE;
					core_cmd <= #1 `I2C_CMD_NOP;
					// generate command acknowledge signal
					cmd_ack	<= #1 1'b1;
				end
			endcase
		end
endmodule
