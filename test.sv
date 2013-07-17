program automatic test(fifo_if.TB test_if,
                       cpu_if.Cfg cfg_if);

`include "environment.sv"
Environment env;

initial begin
  env = new(test_if);
  
  env.gen_cfg();
  env.build();
  env.run();
  env.wrap_up();
end

endprogram
  
