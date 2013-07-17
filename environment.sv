class Environment;

  OP_generator  gen[];
  mailbox       gen2drv[];
  event         drv2gen[];
  Driver        drv[];
  Monitor       mon[];
  Config        cfg;
  Scoreboard    scb;
  Coverage      cov;
  
  virtual fifo_if.TB test_if[];
  virtual cpu_if.Cfg mif;
  
  CPU_driver cpu;
  
  extern function new(test_if);
  
  extern virtual function void gen_cfg();
  extern virtual function void build();
  extern virtual task run();
  extern virtual function void wrap_up();
  
endclass: Environment
