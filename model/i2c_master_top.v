//  $Id: i2c_master_top.v,v 1.1 2008-11-08 13:15:10 sfielding Exp $
//  $Date: 2008-11-08 13:15:10 $
//  $Revision: 1.1 $
//  $Author: sfielding $
//  $Locker:  $
//  $State: Exp $
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.11  2005/02/27 09:26:24  rherveille
//               Fixed register overwrite issue.
//               Removed full_case pragma, replaced it by a default statement.
//
//               Revision 1.10  2003/09/01 10:34:38  rherveille
//               Fix a blocking vs. non-blocking error in the wb_dat output mux.
//
//               Revision 1.9  2003/01/09 16:44:45  rherveille
//               Fixed a bug in the Command Register declaration.
//
//               Revision 1.8  2002/12/26 16:05:12  rherveille
//               Small code simplifications
//
//               Revision 1.7  2002/12/26 15:02:32  rherveille
//               Core is now a Multimaster I2C controller
//
//               Revision 1.6  2002/11/30 22:24:40  rherveille
//               Cleaned up code
//
//               Revision 1.5  2001/11/10 10:52:55  rherveille
//               Changed PRER reset value from 0x0000 to 0xffff, conform specs.

// synopsys translate_off
`include "..\rtl\timescale.v"
// synopsys translate_on
`include "i2c_master_byte_ctrl.v"
`include "i2c_master_defines.v"

module i2c_master_top(
	input	wire		wb_clk_i,	  // master clock input 
	input	wire		wb_rst_i,	  // synchronous active high reset 
	input	wire		arst_i,		  // asynchronous reset 
	input	wire [2:0]	wb_adr_i,	  // lower address bits 
	input	wire [7:0]	wb_dat_i,	  // databus input 
	input	wire		wb_we_i,	  // write enable input 
	input	wire		wb_stb_i,	  // stobe/core select signal 
	input	wire		wb_cyc_i,	  // valid bus cycle input 
	input	wire		scl_pad_i,    // SCL-line input
	input	wire		sda_pad_i,    // SDA-line input
	output	reg			wb_ack_o,	  // bus cycle acknowledge output 
	output	reg			wb_inta_o,	  // interrupt request signal output
	output	reg  [7:0]	wb_dat_o,	  // databus output
	output	wire		scl_pad_o,    // SCL-line output (always 1'b0)
	output	wire		scl_padoen_o, // SCL-line output enable (active low)
	output	wire		sda_pad_o,    // SDA-line output (always 1'b0)
	output	wire		sda_padoen_o  // SDA-line output enable (active low)
);

	// hookup byte controller block
	i2c_master_byte_ctrl byte_controller (
		.clk      ( wb_clk_i     ),
		.rst      ( wb_rst_i     ),
		.nReset   ( rst_i        ),
		.ena      ( core_en      ),
		.clk_cnt  ( prer         ),
		.start    ( sta          ),
		.stop     ( sto          ),
		.read     ( rd           ),
		.write    ( wr           ),
		.ack_in   ( ack          ),
		.din      ( txr          ),
		.cmd_ack  ( done         ),
		.ack_out  ( irxack       ),
		.dout     ( rxr          ),
		.i2c_busy ( i2c_busy     ),
		.i2c_al   ( i2c_al       ),
		.scl_i    ( scl_pad_i    ),
		.scl_o    ( scl_pad_o    ),
		.scl_oen  ( scl_padoen_o ),
		.sda_i    ( sda_pad_i    ),
		.sda_o    ( sda_pad_o    ),
		.sda_oen  ( sda_padoen_o )
	);

	// parameters
	parameter ARST_LVL = 1'b0; // asynchronous reset level

	// variable declarations
	// registers
	reg  [15:0] prer; // clock prescale register
	reg  [ 7:0] ctr;  // control register
	reg  [ 7:0] txr;  // transmit register
	wire [ 7:0] rxr;  // receive register
	reg  [ 7:0] cr;   // command register
	wire [ 7:0] sr;   // status register

	// done signal: command completed, clear command register
	wire done;

	// core enable signal
	wire core_en;
	wire ien;

	// status register signals
	wire irxack;
	reg  rxack;       // received aknowledge from slave
	reg  tip;         // transfer in progress
	reg  irq_flag;    // interrupt pending flag
	wire i2c_busy;    // bus busy (start signal detected)
	wire i2c_al;      // i2c bus arbitration lost
	reg  al;          // status register arbitration lost bit

	// module body
	// generate internal reset
	wire rst_i = arst_i ^ ARST_LVL;

	// generate wishbone signals
	wire wb_wacc = wb_cyc_i & wb_stb_i & wb_we_i;

	// generate acknowledge output signal
	always @(posedge wb_clk_i)
		wb_ack_o <= #1 wb_cyc_i & wb_stb_i & ~wb_ack_o; // because timing is always honored

	// assign DAT_O
	always @(posedge wb_clk_i) begin
		case (wb_adr_i) 				// synopsis parallel_case
			3'b000: wb_dat_o <= #1 prer[ 7:0];
			3'b001: wb_dat_o <= #1 prer[15:8];
			3'b010: wb_dat_o <= #1 ctr;
			3'b011: wb_dat_o <= #1 rxr; // write is transmit register (txr)
			3'b100: wb_dat_o <= #1 sr;  // write is command register (cr)
			3'b101: wb_dat_o <= #1 txr;
			3'b110: wb_dat_o <= #1 cr;
			3'b111: wb_dat_o <= #1 0;   // reserved
		endcase
	end

	// generate registers
	always @(posedge wb_clk_i or negedge rst_i)
		if (!rst_i) begin
			prer <= #1 16'hffff;
			ctr  <= #1  8'h0;
			txr  <= #1  8'h0;
		end
		else if (wb_rst_i) begin
			prer <= #1 16'hffff;
			ctr  <= #1  8'h0;
			txr  <= #1  8'h0;
		end
		else if (wb_wacc)
			case (wb_adr_i) // synopsis parallel_case
				3'b000 : prer [ 7:0] <= #1 wb_dat_i;
				3'b001 : prer [15:8] <= #1 wb_dat_i;
				3'b010 : ctr		 <= #1 wb_dat_i;
				3'b011 : txr		 <= #1 wb_dat_i;
				default: ;
			endcase

	// generate command register (special case)
	always @(posedge wb_clk_i or negedge rst_i)
		if (~rst_i)
			cr <= #1 8'h0;
		else if (wb_rst_i)
			cr <= #1 8'h0;
		else if (wb_wacc) begin
			if (core_en & (wb_adr_i == 3'b100) )
				cr <= #1 wb_dat_i;
		end
		else begin
			if (done | i2c_al)
				cr[7:4] <= #1 4'h0;		// clear command bits when done or when aribitration lost
			cr[2:1] <= #1 2'b0;			// reserved bits
			cr[0]   <= #1 2'b0;			// clear IRQ_ACK bit
		end

	// decode command register
	wire sta  = cr[7];
	wire sto  = cr[6];
	wire rd   = cr[5];
	wire wr   = cr[4];
	wire ack  = cr[3];
	wire iack = cr[0];	//Interrupt acknowledge. When set, clears a pending interrupt.

	// decode control register
	assign core_en = ctr[7];
	assign ien = ctr[6];

	// status register block + interrupt request signal
	always @(posedge wb_clk_i or negedge rst_i)
		if (!rst_i) begin
			al	   	 <= #1 1'b0;
			rxack 	 <= #1 1'b0;
			tip	 	 <= #1 1'b0;
			irq_flag <= #1 1'b0;
		end
		else if (wb_rst_i) begin
			al	  	 <= #1 1'b0;
			rxack	 <= #1 1'b0;
			tip	 	 <= #1 1'b0;
			irq_flag <= #1 1'b0;
		end
		else begin
			al	  	 <= #1 i2c_al | (al & ~sta);
			rxack    <= #1 irxack;
			tip	  	 <= #1 (rd | wr);
			irq_flag <= #1 (done | i2c_al | irq_flag) & ~iack; // interrupt request flag is always generated
		end

	// generate interrupt request signals
	always @(posedge wb_clk_i or negedge rst_i)
		if (!rst_i)
			wb_inta_o <= #1 1'b0;
		else if (wb_rst_i)
			wb_inta_o <= #1 1'b0;
		else
			wb_inta_o <= #1 irq_flag && ien; // interrupt signal is only generated when IEN (interrupt enable bit is set)

	// assign status register bits
	assign sr[7]   = rxack;
	assign sr[6]   = i2c_busy;
	assign sr[5]   = al;
	assign sr[4:2] = 3'h0; // reserved
	assign sr[1]   = tip;
	assign sr[0]   = irq_flag;

endmodule
