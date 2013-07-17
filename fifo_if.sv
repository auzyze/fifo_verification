`timescale 1ns/100ps

interface fifo_if;

logic rst,clk;

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
  
  output  wr_en;
  output  wr_data;
  output  rd_en;
  
  input   rd_data;
  input   full;
  input   empty;
  input   afull;
  input   aempty;
endclocking

modport TB(clocking cb, output rst);

modeport DUT(input clk,rst,wr_en,wr_data,rd_en,
             output rd_data,full,empty,afull,aempty);

endinterface

  
typedef virtual fifo_if vFifo_if;
typedef virtual fifo_if.TB vFifo_TB;

