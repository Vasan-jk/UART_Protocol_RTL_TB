`include "inc.h"

module uart_ref(
    input sys_clk, 
    input sys_rst_l, 
    input xmitH, 
    input [`word_len-1:0] xmit_dataH, 
    input uart_REC_dataH,
    
    output reg uart_XMIT_dataH, 
    output reg xmit_doneH, 
    output reg rec_readyH, 
    output reg xmit_active, 
    output reg rec_busy,
    output reg [`word_len-1:0] rec_dataH
);
    
    // We generate the baud clock internally to perfectly match the DUT
    wire uart_clk;
    baud au(sys_clk, sys_rst_l, uart_clk);

    // ==========================================
    // TX ENGINE (Matches FSM State Transitions)
    // ==========================================
    initial begin
        uart_XMIT_dataH = 1'b1; 
        xmit_active     = 1'b0;
        xmit_doneH      = 1'b1; 

        forever begin
            if (xmitH == 1'b1) begin
                transmit(xmit_dataH); 
            end else begin
                // 'idle' state outputs
                xmit_active <= 1'b0;
                xmit_doneH  <= 1'b1;
                @(posedge uart_clk);
            end
        end
    end

    // ==========================================
    // RX ENGINE (Matches FSM State Transitions)
    // ==========================================
    initial begin
        rec_readyH = 1'b1; 
        rec_busy   = 1'b0;
        rec_dataH  = 8'h00;
        
        forever begin
            receive(); 
        end
    end

    // ==========================================
    // 1-to-1 CYCLE ACCURATE TRANSMIT TASK
    // ==========================================
    task transmit(input [7:0] dta);
        integer bit_idx;
        begin
            // Cycle 1: Enter 'start' state. DUT drops done flag.
            @(posedge uart_clk); 
            xmit_doneH <= 1'b0;
            
            // Cycle 2: DUT asserts active flag and starts pulling line low
            @(posedge uart_clk); 
            xmit_active <= 1'b1;
            uart_XMIT_dataH <= 1'b0; 
            
            // Wait remaining 15 cycles of the Start state
            repeat(15) @(posedge uart_clk); 

            // Transmit Data Bits
            for (bit_idx = 0; bit_idx < `word_len; bit_idx = bit_idx + 1) begin
                uart_XMIT_dataH <= dta[bit_idx];
                repeat(16) @(posedge uart_clk);
            end

          
            uart_XMIT_dataH <= 1'b1; 
            
           
            repeat(14) @(posedge uart_clk); 
            xmit_doneH <= 1'b1; 
            
            
            @(posedge uart_clk); 
        end
    endtask

   
    task receive; 
        integer cn;         
        reg [7:0] dt_ref;
        reg sampled_stop_bit;
        begin
            // Raw line drops
            @(negedge uart_REC_dataH);
            
            // 4 Cycles Exact Delay: 
            // 2 for synchronizer + 1 to register idle->start + 1 for outputs to update
            repeat(4) @(posedge uart_clk);
            
            rec_busy   <= 1'b1;
            rec_readyH <= 1'b0;
            
            // Wait remaining 15 cycles of 'start' state
            repeat(15) @(posedge uart_clk);
            
            // Trans state (16 cycles per bit)
            for (cn = 0; cn < `word_len; cn = cn + 1) begin
                // DUT FSM samples at bit_cnt=8. 
                // Because of the 2-flop sync, it is reading the raw line from bit_cnt=6!
                repeat(7) @(posedge uart_clk);
                dt_ref[cn] = uart_REC_dataH; 
                
                // Wait remaining 9 cycles to complete the bit
                repeat(9) @(posedge uart_clk);
            end
            
           
            repeat(7) @(posedge uart_clk); 
            sampled_stop_bit = uart_REC_dataH;
            
            // Wait to reach tick 8 where DUT registers output
            repeat(2) @(posedge uart_clk); 
            
            rec_busy   <= 1'b0;
            rec_readyH <= 1'b1; 
            if (sampled_stop_bit == 1'b1) begin
                rec_dataH <= dt_ref;
            end
            
            
            repeat(7) @(posedge uart_clk);
        end
    endtask
    
endmodule