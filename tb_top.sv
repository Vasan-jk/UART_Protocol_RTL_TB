`include "inc.h"
`include "uart_reference_model.sv"
`include "ref_baud.sv"
`include "uart.sv"

module tb_top;

    reg sys_clk, sys_rst_l, xmitH;
    reg [`word_len-1:0] xmit_dataH;
    
    // =========================================================
    // THE STIMULUS MUX (For Error Injection)
    // =========================================================
    reg loopback_en;
    reg manual_rx_stimulus;
    wire uart_REC_dataH;
    
    // Switch between perfect loopback and malicious manual injection


    // DUT Wires
    wire uart_XMIT_dataH_dut, xmit_doneH_dut, rec_readyH_dut, xmit_active_dut, rec_busy_dut;
    wire [`word_len-1:0] rec_dataH_dut;
    
    // REF Wires
    wire uart_XMIT_dataH_ref, xmit_doneH_ref, rec_readyH_ref, xmit_active_ref, rec_busy_ref;
    wire [`word_len-1:0] rec_dataH_ref;

    // Clock Generation
    wire uart_clk;
    baud au(sys_clk, sys_rst_l, uart_clk);
    assign uart_REC_dataH = loopback_en ? uart_XMIT_dataH_dut : manual_rx_stimulus;
    uart dut(sys_clk, sys_rst_l, xmitH, xmit_dataH, uart_REC_dataH, uart_XMIT_dataH_dut, xmit_doneH_dut, rec_dataH_dut, rec_readyH_dut, xmit_active_dut, rec_busy_dut);
    //uart_ref refs(sys_clk, sys_rst_l, xmitH, xmit_dataH, uart_REC_dataH, uart_XMIT_dataH_ref, xmit_doneH_ref, rec_dataH_ref, rec_readyH_ref, xmit_active_ref, rec_busy_ref);
    uart_ref refs(
        .sys_clk(sys_clk), 
        .sys_rst_l(sys_rst_l), 
        .xmitH(xmitH), 
        .xmit_dataH(xmit_dataH), 
        .uart_REC_dataH(uart_REC_dataH), 
        
        .uart_XMIT_dataH(uart_XMIT_dataH_ref), 
        .xmit_doneH(xmit_doneH_ref), 
        .rec_dataH(rec_dataH_ref),      // 8-bit safely mapped to 8-bit
        .rec_readyH(rec_readyH_ref),    // 1-bit safely mapped to 1-bit
        .xmit_active(xmit_active_ref),  
        .rec_busy(rec_busy_ref)         
    );
    initial sys_clk = 0;
    always #10 sys_clk = ~sys_clk;

    reg enable_scoreboard = 1; 

   
    task drive_xmit(input [7:0] payload);
        begin
            @(negedge uart_clk); 
            xmit_dataH = payload;
            xmitH      = 1;
            
            wait(xmit_active_dut == 1'b1 || xmit_active_ref == 1'b1);

            @(negedge uart_clk);
            xmitH      = 0;

            wait(xmit_active_dut == 1'b0 && xmit_active_ref == 1'b0);
            repeat(5) @(posedge uart_clk); 
        end
    endtask


    task run_reset_tests;
        begin
            $display("Asynchronous Reset during Idle");
            sys_rst_l = 0;
            #2000; 
            sys_rst_l = 1;
            repeat(5) @(posedge uart_clk);

            $display("Testing Reset During Operation");
            @(negedge uart_clk);
            xmit_dataH = 8'hAA;
            xmitH = 1;
            @(negedge uart_clk); xmitH = 0;
            
            wait(xmit_active_dut == 1'b1);
            repeat(50) @(posedge uart_clk); 
            
            sys_rst_l = 0; 
            #2000; 
            sys_rst_l = 1;
            repeat(10) @(posedge uart_clk);
        end
    endtask

    task run_tx_data_tests;
        begin
            $display("Transmitting All Zeros");
            drive_xmit(8'h00);
            $display("Transmitting All Ones");
            drive_xmit(8'hFF);
            $display("Transmitting Valid Mixed Word");
            drive_xmit(8'h5A);
        end
    endtask

    task run_tx_edge_cases;
        begin
            $display("Holding xmitH HIGH continuously");
            @(negedge uart_clk);
            xmit_dataH = 8'hC3;
            xmitH = 1; 
            
            wait(xmit_doneH_dut == 1'b1);
            @(negedge uart_clk);
            xmit_dataH = 8'hA5; 
            
            wait(xmit_doneH_dut == 1'b1);
            @(negedge uart_clk);
            xmitH = 0; 
            wait(xmit_active_dut == 1'b0);
        end
    endtask

    task run_rx_error_tests;
        integer i;
        begin
            $display("RX Framing Error (Missing Stop Bit)");
            loopback_en = 0; 
            
            @(negedge uart_clk);
            manual_rx_stimulus = 0; 
            repeat(16) @(posedge uart_clk);

            for (i = 0; i < 8; i = i + 1) begin
                manual_rx_stimulus = i % 2; 
                repeat(16) @(posedge uart_clk);
            end

            manual_rx_stimulus = 0; 
            repeat(16) @(posedge uart_clk);
            
            manual_rx_stimulus = 1; // Return to idle
            repeat(20) @(posedge uart_clk);
            loopback_en = 1; // Reattach the cable
        end
    endtask


    initial begin
        sys_rst_l  = 0;
        xmitH      = 0;
        xmit_dataH = 8'h00;
        loopback_en = 1;      
        manual_rx_stimulus = 1; 
        enable_scoreboard = 1;

        #5000;
        sys_rst_l = 1;
        repeat(10) @(posedge uart_clk);
        
        drive_xmit(8'hA6);
        drive_xmit(8'h33); 
        
        #5000;
        run_tx_data_tests();
        run_tx_edge_cases();

        enable_scoreboard = 0; 
        run_rx_error_tests();
        run_reset_tests();
        
        #5000;
        $display("=== SIMULATION COMPLETE ===");
        $stop;
    end
/*
    always @(negedge uart_clk) begin
        if (sys_rst_l == 1'b1 && enable_scoreboard == 1'b1) begin 
            if (uart_XMIT_dataH_dut !== uart_XMIT_dataH_ref) $display("[%0t] [ERROR] TX Line MISMATCH!", $time);
            if (xmit_active_dut !== xmit_active_ref) $display("[%0t] [ERROR] TX Active MISMATCH!", $time);
            if (xmit_doneH_dut !== xmit_doneH_ref) $display("[%0t] [ERROR] TX Done MISMATCH!", $time);
            if (rec_busy_dut !== rec_busy_ref) $display("[%0t] [ERROR] RX Busy MISMATCH!", $time);
            if (rec_readyH_dut !== rec_readyH_ref) $display("[%0t] [ERROR] RX Ready MISMATCH!", $time);
            if (rec_dataH_dut !== rec_dataH_ref) $display("[%0t] [ERROR] RX Data MISMATCH! DUT: %h | REF: %h", $time, rec_dataH_dut, rec_dataH_ref);
        end
    end
*/
    // 2. Transaction-Level Monitor
    always @(posedge rec_readyH_dut) begin
        if (sys_rst_l == 1'b1) begin 
            if (rec_dataH_dut === xmit_dataH && rec_dataH_dut === rec_dataH_ref) begin
                $display("[%0t] [SUCCESS] Full-Duplex Loopback Verified: Byte %h", $time, rec_dataH_dut);
            end else if (enable_scoreboard) begin
                $display("[%0t] [FAIL] Loopback Failed! Sent: %h | Received: %h", $time, xmit_dataH, rec_dataH_dut);
            end
        end
    end

endmodule