`timescale 1ns/100ps

module top;

bit clk;
//System Clock

//System Reset is not inclued in top, as it should be controllable~

initial begin
  clk = 0;
  forever
    #5 clk = ~clk;
end


fifo_if my_if(clk);

fifo_test my_test(clk,my_if);   //argument is fifo_test can be "fifo_if.TB test_intf"

sync_fifo DUT(clk,my_if);       //argument is sync_fifo can be "fifo_if.DUT dut_intf"


enmodule
