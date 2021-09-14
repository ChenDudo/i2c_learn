//  $Id: i2c_master_defines.v,v 1.1 2008-11-08 13:15:10 sfielding Exp $
//  $Date: 2008-11-08 13:15:10 $
//  $Revision: 1.1 $
//  $Author: sfielding $
//  $Locker:  $
//  $State: Exp $
// Change History:
//               $Log: not supported by cvs2svn $
//               Revision 1.3  2001/11/05 11:59:25  rherveille
//               Fixed wb_ack_o generation bug.
//               Fixed bug in the byte_controller statemachine.
//               Added headers.


// I2C registers wishbone addresses

// bitcontroller states
`define I2C_CMD_NOP   4'b0000
`define I2C_CMD_START 4'b0001
`define I2C_CMD_STOP  4'b0010
`define I2C_CMD_WRITE 4'b0100
`define I2C_CMD_READ  4'b1000
