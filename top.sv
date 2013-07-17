`timescale 1ns/100ps

module top;

parameter CLK_CYCLE = 100;

bit SystemClock;

fifo_if my_if(SystemClock);    //instantiating interface and passing clock to it

fifo_test my_test(my_if);     //fifo_test if program block

sync_fifo DUT(my_if);         //dut with be SV interface compatible

initial begin
  SystemClock = 0;
  forever begin
    #(CLK_CYCLE/2)
    SystemClock = ~SystemClock;
  end
end

enmodule
