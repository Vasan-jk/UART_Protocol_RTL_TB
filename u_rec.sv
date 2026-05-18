`include "inc.h"
`timescale 10ns/10ps
module u_rec(uart_clk,sys_rst_l,uart_REC_dataH, rec_dataH, rec_readyH, rec_busy);

input uart_clk;
input sys_rst_l;
input uart_REC_dataH;
output reg [`word_len-1:0] rec_dataH;
output reg rec_readyH;
output reg rec_busy;
reg [`word_len - 1: 0] len;
reg [`word_len - 1: 0] dt;
//wire uart_clk;
reg [3:0] bit_cnt;
reg [1:0] st, nxt;
reg tmp_1, uart_REC_data;
localparam idle = 2'b00, start = 2'b01, trans = 2'b10, stop = 2'b11;

//baud au(sys_clk, sys_rst_l, uart_clk);

always@(posedge uart_clk or negedge sys_rst_l) begin
    if(!sys_rst_l)begin
        tmp_1 <= 1;
        uart_REC_data <= 1;
    end
    else begin
        tmp_1 <=  uart_REC_dataH;
        uart_REC_data <= tmp_1;
    end
end

always@(posedge uart_clk or negedge sys_rst_l) begin
    if(!sys_rst_l) begin
        st <= idle;
    end
    else begin
        st <= nxt;
    end
end

always@(*) begin
    nxt = st;
    case(st)
        idle: begin
                if(!uart_REC_data)
                nxt = start;
            else
                nxt = idle;
        end
        start: begin
            if(bit_cnt == 8 && uart_REC_data == 1'b1) begin
                nxt = idle;
            end

            else if(bit_cnt >= 15)
                nxt = trans;
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
            if(uart_REC_data == 0 && bit_cnt == 8) begin
                nxt = idle;
            end

           // if(bit_cnt >= 15) begin
              //  nxt = idle;
           // end
          //  else if(!uart_REC_data) begin
             //   nxt = start;
           // end
            //else
             //   nxt = stop;
        end
    endcase
end

always@(posedge uart_clk or negedge sys_rst_l) begin
    if(!sys_rst_l) begin
        rec_readyH <= 1'b1;
        rec_dataH <= 'b0;
        rec_busy <= 1'b0;
        bit_cnt <= 'b0;
        len <= 0;
        dt <= 0;
    end
    else begin
        if (bit_cnt >= 4'd15) begin
            bit_cnt <= 4'd0;
            end else begin
                bit_cnt <= bit_cnt + 4'd1;
        end
        case(st)
            idle: begin
                rec_readyH <= 1'b1; 
                rec_busy <= 1'b0;
                if(!uart_REC_data)
                    bit_cnt <= 0;
                   
            end

            start: begin
                if(bit_cnt < 15) begin
                    rec_readyH <= 1'b0;
                    rec_busy <= 1'b1;
                   // rec_dataH <= 'b0;
                end
                else begin
                    dt <= 'b0;
                    len <= 0;
                    bit_cnt <= 0;
                end
            end

            trans: begin
               
                //rec_dataH <= 'b0;
                if(len < `word_len) begin
                    if(bit_cnt == 8) begin
                        dt <= {uart_REC_data, dt[7:1]};
                        //rec_readyH<= 1'b0;
                        //rec_busy <= 1'b1;
                    end
                    if(bit_cnt == 15) begin
                            len <= len + 1;
                    end 
                end
            end

            stop: begin
                
                if(bit_cnt == 8) begin
                    rec_busy <= 1'b0;
                    rec_readyH <= 1'b1;
                    if(uart_REC_data) 
                        rec_dataH <= dt;            
                end
            end
        endcase
    end
end
endmodule