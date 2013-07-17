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

///////////////////////////////////////////////////
//construct an environment instance
function Environment::new(input test_if);
  this.test_if = test_if;
  
  if ($test$plusargs("ntb_random_seed")) begin
    int seed;
    $value$plusargs("ntb_random_seed=%d",seed);
    $display("Simulation run with random seed=%d",seed);
  end
  else
    $display("Simulation run with default random seed");
endfunction : new


///////////////////////////////////////////////////
//Randomize the configuration descriptor
function void Environment::gen_cfg();
  assert(cfg.randomize());
  cfg.display();
endfunction : gen_cfg


//////////////////////////////////////////////////
//Build the environment objects
function void Environment::build();
  cpu = new(mif,cfg);
  gen = new();
  drv = new();
  gen2drv = new;
  drv2gen = new;
  scb = new(cfg);
  cov = new();
  mon = new();  
  
  //Connect scoreboard to drvier & monitor with callbacks
  begin
    Scb_Driver_cbs sdc = new(scb);
    Scb_Monitor_cbs smc = new(scb);
    drv.cbsq.push_back(sdc);
    mon.cbsq.push_back(smc);
  end
  
  //connect coverage to monitor with callbacks
  begin
    Cov_Monitor_cbs smc = new(cov);
    mon.cbsq.push_back(smc);
  end

endfunction : build


//////////////////////////////////////////////////////
//Start the transactions: generator, driver, monior
task Environment::run();
  
  //The CPU interface initializes before anyone else
  cpu.run();
  
  //Generator and Driver
  gen.run();
  drv.run();
  
  //Monitor
  mon.run();
  
  repeat (10000)@(test_if.cb);
  
endtask : run
  
  
  
///////////////////////////////////////////
//Post-run cleanup / reporting
function void Environment::wrap_up();
  $display("@%0t: End of sim, %0d errors, %0d warnings",
            $time, cfg.nErrors, cfg.nWarnings);
  scb.wrap_up;
endfunction : wrap_up



///////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////
//FIFO OPeration Generator
class OP_generator;
  fifo_OP blueprint; //Blueprint for generator
  mailbox gen2drv;
  event   drv2gen;
  
  int n_Ops     //num of operations
  
  function new(input mailbox gen2drv,
               input event drv2gen,
               input int nOps);
    this.gen2drv = gen2drv;
    this.drv2gen = drv2gen;
    this.nOps = nOps;
    blueprint = new();
  endfunction : new
  
  task run();
    fifo_OP operation;
    repeat (nOps) begin
      assert (blueprint.randomize());
      $cast(operation, blueprint.copy());
      gen2drv.put(operation);
      @drv2gen; //Wait for driver to finish with it
    end
  endtask : run

endclass : OP_generator


class fifo_OP extends BaseOP;
...

endclass



//////////////////////////////////////////////////////
////////////////////////////////////////////////////////
//Driver
class Driver;
  mailbox gen2drv;
  event   drv2gen;
  test_if op_intf;    //virtual interface for operation transimitting
  
  extern function new(input mailbox gen2drv,
                      input event drv2gen,
                      input test_if op_intf);
  extern task run();
  extern task send (input fifo_OP operation);
  
endclass : Driver

//
function Driver::new(input mailbox gen2drv,
                     input event drv2gen,
                     input test_if op_intf);
  this.gen2drv = gen2drv;
  this.drv2gen = drv2gen;
  this.op_intf = op_intf;
endfunction : new

//run() : run the driver
task Driver::run();
  fifo_OP operation;
  bit drop = 0;
  
  //Initialize ports
  op_intf.cb.wr_en <= 0;
  op_intf.cb.wr_data <= 0;
  op_intf.cb.rd_en <= 0;
  
  forever begin
    gen2drv.put(operation);
    send(operation);
    gen2drv.get(operation);
    ->drv2gen;
  end
endtask : run

//send() : Send a operation into DUT
task Driver::send(input fifo_OP operation);
  for (int i=0; i<=op_len; i++) begin
    if (op_type == WRITE) begin
      ...
    end
    else if (op_type == READ) begin
      ...
    end
    @(op_intf.cb);
  end
  op_intf.cb.wr_en <= `z;
  op_intf.cb.rd_en <= `z;
  op_intf.cb.wr_data <= 32'bx;

endtask




