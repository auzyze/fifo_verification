`timescale 1ns/100ps

interface fifo_if (input bit clk);

logic reset;

logic wr_en;
logic [31:0] wr_data;

logic rd_en;
logic [31:0] rd_data;

logic full;
logic empty;
logic afull;
logic aempty;


clocking cb @(posedge clk);
  default input #1 output #1;  
  output  reset;
  output  wr_en;
  output  wr_data;
  output  rd_en;
  
  input   rd_data;
  input   full;
  input   empty;
  input   afull;
  input   aempty;
endclocking

modport TB(clocking cb, output reset);

modeport DUT(input clk,reset,wr_en,wr_data,rd_en,
             output rd_data,full,empty,afull,aempty);

endinterface
  
