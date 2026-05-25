`define word_len     8
`define sys_clk_freq 100000000 
`define baud_rate    2400   

`define CW           (`sys_clk_freq / (`baud_rate * 32))
`define CWR          ($clog2(`CW))
