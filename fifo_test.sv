program automatic fifo_test(fifo_if.TB op_intf,
                            cpu_if.CFG cfg_intf,
                            input logic rst,clk);

`include "environment.sv"
Environment env;

initial begin
  env = new(op_intf,cfg_intf);
  env.gen_cfg();
  env.build();
  env.run();
  env.wrap_up();
end

endprogram
  
