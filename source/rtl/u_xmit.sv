`include "inc.h"
`timescale 10ns/10ps

module uxmit(sys_clk,sys_rst_l,xmitH, xmit_dataH, xmit_doneH, xmit_active, uart_XMIT_dataH);
input sys_clk;
input sys_rst_l;
input xmitH;
input [`word_len - 1: 0] xmit_dataH;
output reg xmit_doneH;
output reg xmit_active;
output reg uart_XMIT_dataH;
reg [3:0] bit_cnt;
wire uart_clk;
reg [`word_len - 1 : 0] len;
reg [`word_len - 1 : 0] tmp_reg;
baud au(sys_clk, sys_rst_l, uart_clk);

localparam idle = 2'b00, start = 2'b01, trans = 2'b10, stop = 2'b11;
reg[1:0] st, nxt; 

always@(posedge uart_clk or negedge sys_rst_l) begin
    if(!sys_rst_l) 
        st <= idle;
    else
        st <= nxt;
end

always@(*) begin
    nxt = st;
    case(st)
        idle: begin
            if(xmitH) begin
                    nxt = start;
            end
            else
                    nxt = idle;
        end

        start: begin
            if(bit_cnt >= 15) begin
                    nxt = trans;
            end
            else
                    nxt = start;
        end

        trans: begin
                if(len >= (`word_len - 1) && bit_cnt >= 15) begin
                    nxt = stop;
                end
                else
                    nxt = trans;
        end

        stop: begin
                if(bit_cnt >= 15) begin
                if(xmitH)
                    nxt = start;
                else
                    nxt = idle;
                end
                else 
                    nxt = stop;
        end
    endcase
end

always @(posedge uart_clk or negedge sys_rst_l) begin
    if(!sys_rst_l) begin
        uart_XMIT_dataH <=1'b1;
        bit_cnt <= 0;
        xmit_doneH <= 1'b1;
        xmit_active <= 1'b0;
        len <= 0;
        tmp_reg <= 0;
    end
    else begin

         if (bit_cnt >= 4'd15) begin
                bit_cnt <= 4'd0;
            end else begin
                bit_cnt <= bit_cnt + 4'd1;
            end
        case(st)
            idle: begin
                    uart_XMIT_dataH <= 1'b1;
                    xmit_doneH <= 1'b0;
                    xmit_active <= 1'b0;
                    len <= 0;
                    tmp_reg <= 0;
                    if(xmitH) begin
                        tmp_reg <= xmit_dataH;
                        bit_cnt <= 0;
                    end
            end

            start: begin
                if(bit_cnt < 15) begin
                     uart_XMIT_dataH <=1'b0;
                     xmit_active <= 1'b1;
                     xmit_doneH <= 1'b0;
                end
                else
                    len <= 0;
            end

            trans: begin
                xmit_active <= 1'b1;
                xmit_doneH <= 1'b0;
                uart_XMIT_dataH <= tmp_reg[len];
                if(len < `word_len) begin
                    if(bit_cnt >= 15) begin
                        len <= len + 1;
                    end
                end
            end

            stop: begin
                xmit_active <= 1'b1;
                uart_XMIT_dataH <= 1'b1;
                if(bit_cnt == 14)
                        xmit_doneH <= 1'b1;
                if(bit_cnt >= 15) begin
                        if (xmitH) begin
                            tmp_reg <= xmit_dataH;
                        end
                end else begin
                end
            end
        endcase

    end
end

endmodule
