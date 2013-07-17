`timescale 1ns/100ps

module top;

logic rst, clk;
//System Reset and Clock

initial begin
  rst = 1; clk = 0;
  #5 rst = 0;
  #5 clk = 1;
  #5 rst = 1; clk = 0;
  forever
    #5 clk = ~clk;
end


fifo_if my_if(clk,rst);       //instantiating interface and passing clock to it

fifo_test my_test(my_if);

sync_fifo DUT(my_if);         //dut with be SV interface compatible


enmodule
