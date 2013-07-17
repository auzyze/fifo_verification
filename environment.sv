class Environment;

  OP_generator  gen;
  mailbox       gen2drv;
  event         drv2gen;
  Driver        drv;
  Monitor       mon;
  Config        cfg;
  Scoreboard    scb;
  Coverage      cov;
  
  CPU_driver    cpu;

  vFifo_TB      op_intf;      //virtual interface
  vCPU_T        cfg_intf;     //virtual interface
  
  extern function new(input vFifo_TB op_intf,
                      input vCPU_T cfg_intf);
  
  extern virtual function void gen_cfg();
  extern virtual function void build();
  extern virtual task run();
  extern virtual function void wrap_up();
  
endclass: Environment

///////////////////////////////////////////////////
//construct an environment instance
function Environment::new(input vFifo_TB op_intf,
                          input vCPU_T cfg_intf);
  this.op_intf = op_intf;
  this.cfg_intf = cfg_intf;
  
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
  cpu = new(cfg_intf,cfg);
  gen = new();
  drv = new();
  gen2drv = new();
  drv2gen = new();
  scb = new(cfg);
  cov = new();
  mon = new();  
  
  //??????
  //Connect scoreboard to drvier & monitor with callbacks
  begin
    Scb_Driver_cbs sdc = new(scb);
    Scb_Monitor_cbs smc = new(scb);
    drv.cbsq.push_back(sdc);
    mon.cbsq.push_back(smc);
  end
  
  //connect coverage to monitor with callbacks
  begin
    Cov_Monitor_cbs cmc = new(cov);
    mon.cbsq.push_back(cmc);
  end

endfunction : build


//////////////////////////////////////////////////////
//Start the transactors: generator, driver, monior
task Environment::run();
  
  //The CPU interface initializes before anyone else
  cpu.run();
  
  //Generator and Driver
  gen.run();
  drv.run();
  
  //Monitor
  mon.run();
  
  repeat (10000)@(op_intf.cb);
  
endtask : run
  
  
  
///////////////////////////////////////////
//Post-run cleanup / reporting
function void Environment::wrap_up();
  $display("@%0t: End of sim, %0d errors, %0d warnings",
            $time, cfg.nErrors, cfg.nWarnings);
  scb.wrap_up;
endfunction : wrap_up



////////////////////////////////////////////////////////
//fifo operation: write, read or both. suport single or burst
//randomization: operation number, operation length, operation delay ...
//
class fifo_OP extends BaseOP;
  rand bit [15:0] wr_num;
  rand bit [15:0] wr_len;
  rand bit [31:0] rd_data [];
  rand bit        wr_dly [];
  
  rand bit [15:0] rd_num;
  rand bit [15:0] rd_len;
  rand bit        rd_dly [];
  
  
  extern function new();
  extern function void post_randomize();
  extern vitrual function bit compare(input BaseOP to);
  extern virtual function void display(input string prefix="");
  extern virtual function void copy_data(input fifo_OP copy);
  extern virtual function BaseOP copy(input BaseOP to=null);
  
...

endclass



///////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////
//FIFO OPeration Generator
class OP_generator;
  fifo_OP blueprint; //Blueprint for generator, can be replaced with objects derived from fifo_OP
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



//////////////////////////////////////////////////////
////////////////////////////////////////////////////////
//Driver
class Driver;
  mailbox gen2drv;
  event   drv2gen;
  vFifo_TB op_intf;     //virtual interface for operation transimitting
  
  Driver_cbs cbsq[$];     //Queue of callback objects
  
  extern function new(input mailbox gen2drv,
                      input event drv2gen,
                      input vFifo_TB op_intf);
  extern task run();
  extern task send (input fifo_OP operation);
  
endclass : Driver

//
function Driver::new(input mailbox gen2drv,
                     input event drv2gen,
                     input vFifo_TB op_intf);
  this.gen2drv = gen2drv;
  this.drv2gen = drv2gen;
  this.op_intf = op_intf;
endfunction : new

//run() : run the driver
task Driver::run();
  fifo_OP operation;
  
  //Initialize ports
  op_intf.cb.wr_en <= 0;
  op_intf.cb.wr_data <= 0;
  op_intf.cb.rd_en <= 0;
  
  forever begin
    gen2drv.peek(operation);      //"peek" task gets a copy of data in mailbox but doesn't remove it
    send(operation);
    gen2drv.get(operation);       //remove the data with "get" task after operation has been sent
    ->drv2gen;
  end
endtask : run

//send() : Send a operation into DUT
task Driver::send(input fifo_OP operation);
  
  fork begin
    //thread of writing
    //thread of reading
  end
  
endtask




/////////////////////////////////////////////////////////////
//Monitor

class Monitor;
  vFifo_TB op_intf;
  
  extern function new(input vFifo_TB op_intf);
  extern task run();
  extern task receive(output RData output_d);    //what should be received?
endclass : Monitor

//new
function Monitor::new(input vFifo_TB op_intf);
  this.op_intf = op_intf;
endfunction


task Monitor::run();
  RData output_d;
  
  forever begin
    receive(output_d);
  end
  
endtask : run


//receive task
task Monitor::receive(output RData output_d)

.....

endtask : receive



///////////////////////////////////////////////////
//the scoreboard class









