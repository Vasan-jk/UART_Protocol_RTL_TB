`include "inc.h"
//`timescale 10ns/10ps

module baud(sys_clk, sys_rst_l, uart_clk);
    input sys_clk;
    input sys_rst_l;
    output reg uart_clk;
    reg [`CWR-1:0]cnt;
    always@(posedge sys_clk or negedge sys_rst_l) begin
        if(!sys_rst_l) begin
            cnt <= 0;
            uart_clk <= 0;
        end
        else if(cnt == `CW - 1) begin 
            cnt <= 0;
            uart_clk <= ~uart_clk;
        end
        else begin
            cnt <= cnt + 1;
        end
    end
endmodule
