program automatic fifo_test(fifo_if.TB op_intf,
                            cpu_if.CFG cfg_intf,
                            input logic rst,clk);

`include "environment.sv"
Environment env;

initial begin
  env = new(op_intf,cfg_intf);
  env.gen_cfg();
  env.build();
  
  /*A method to use new transaction extended from base "fifo_op" */
  //begin
  //  fifo_op_ext new_op = new();
  //  env.gen.blueprint = new_op;
  //end
  
  env.run();
  env.wrap_up();
end

endprogram
  
