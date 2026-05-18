`include "inc.h"
`timescale 10ns/10ps
module uart(sys_clk, sys_rst_l, xmitH, xmit_dataH, uart_REC_dataH, uart_XMIT_dataH, xmit_doneH, rec_dataH, rec_readyH, xmit_active, rec_busy);
input sys_clk, sys_rst_l, xmitH, uart_REC_dataH;
input [`word_len-1:0] xmit_dataH;
output uart_XMIT_dataH, xmit_doneH, rec_readyH, xmit_active, rec_busy;
output [`word_len-1:0] rec_dataH;
wire uart_clk;
baud au(sys_clk, sys_rst_l, uart_clk);

uxmit xmit(uart_clk,sys_rst_l,xmitH, xmit_dataH, xmit_doneH, xmit_active, uart_XMIT_dataH);
u_rec rec(uart_clk,sys_rst_l,uart_REC_dataH, rec_dataH, rec_readyH, rec_busy);

endmodule