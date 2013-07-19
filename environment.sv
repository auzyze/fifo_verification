

class Environment;

  Generator     gen;
  
  mailbox       gen2drv_m;
  mailbox       drv2scb_m;
  mailbox       mon2scb_m;
  
  event         drv2gen_e;
  
  Driver        drv;
  Monitor       mon;
  Scoreboard    scb;
  Coverage      cov;
  
  Config        cfg;          //used to configure TB
  
  CPU_driver    cpu;          //driver used to configure DUT

  vFifo_TB      test_intf;    //virtual interface
  vCPU_T        cfg_intf;     //virtual interface
  
  extern function new(input vFifo_TB  test_intf,
                      input vCPU_T    cfg_intf
                      );
  
  extern virtual function void gen_cfg();
  extern virtual function void build();
  extern virtual task run();
  extern virtual function void wrap_up();
  
endclass: Environment

///////////////////////////////////////////////////
//construct an environment instance
function Environment::new(input vFifo_TB  test_intf,
                          input vCPU_T    cfg_intf
                          );
  this.test_intf = test_intf;
  this.cfg_intf = cfg_intf;  
  cfg = new();
endfunction : new
  

///////////////////////////////////////////////////
//configure ??
function void Environment::gen_cfg();
  assert(cfg.randomize());
  cfg.display();
endfunction : gen_cfg


//////////////////////////////////////////////////
//Build the environment objects
function void Environment::build();
  cpu = new(cfg_intf,cfg);            //construct CPU driver with cfg info
  
  gen = new(gen2drv_m, drv2gen_e);
  drv = new(gen2drv_m, drv2gen_e, drc2scb_m);
  
  gen2drv_m = new();                  //mailbox X 3
  drv2scb_m = new();
  mon2scb_m = new();
  
  drv2gen_e = new();                  //event
  
  scb = new(cfg);                     //construct scoreboard with cfg info
  cov = new();
  mon = new(mon2scb_m);  
  
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
  
  //wait for data to flow through DUT, monitor and scoreboard
  repeat (10000)@(test_intf.cb);
  
endtask : run
  
  
  
///////////////////////////////////////////
//Post-run cleanup / reporting
function void Environment::wrap_up();
  $display("@%0t: End of sim, %0d errors, %0d warnings",
            $time, cfg.nErrors, cfg.nWarnings);
  scb.wrap_up;
endfunction : wrap_up



////////////////////////////////////////////////
//Define fifo operation (Transaction)
class fifo_op;
  rand bit [1:0]  op_type;      //op_type[1]=1 means write, [0]=1 mean read
  rand bit [15:0] op_len;       //duration of write, or read, or both
  
  rand bit [31:0] wr_data[];
    constraint wr_c {wr_data.size == op_len;};
    
  bit [31:0] rd_data;
  bit full;
  bit empty;
  bit afull;
  bit aempty;

  //static bit [15:0] wr_count;
  //static bit [15:0] rd_count;

  //extern function new();
  //extern function void post_randomize();
  
  virtual function copy_data(input fifo_op tr);
    tr.op_type  = op_type;
    tr.op_len   = op_len;
    tr.wr_data  = wr_data;
    tr.rd_data  = rd_data;
    tr.full     = full;
    tr.empty    = empty;
    tr.afull    = afull;
    tr.aempty   = aempty;
  endfunction : copy_data
    
  virtual function fifo_op copy();
    copy = new();
    copy_data(copy);
  endfunction
    
endclass : fifo_op



///////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////
//FIFO Operation Generator
class Generator;

  fifo_op blueprint;
  mailbox gen2drv_m;
  event   drv2gen_e;
  int     op_num;
  
  function new(input mailbox gen2drv_m,
               input event drv2gen_e,
               input int op_num);
    this.gen2drv = gen2drv_m;
    this.drv2gen = drv2gen_e;
    this.op_num = op_num;
    blueprint = new();                      //constructed in "new", but used in "run" task
  endfunction : new
  
  //separate construction and use of "blueprint",
  //then additional code can be added between "env.build" and "env.run",
  //so, this is a "hook" for new transaction extended from base one.
  
  task run();
    fifo_op gen_op;
    repeat (op_num) begin
      assert (blueprint.randomize());
      $cast(gen_op, blueprint.copy());      //"copy" method must be defined in "fifo_op" class
      //gen_op = blueprint.copy();          //"gen_op=blueprint" will not work, as only handle copied
      gen2drv_m.put(gen_op);    
      
      @drv2gen_e; //Wait for driver to finish
    end
  endtask : run
  
endclass : Generator



//////////////////////////////////////////////////////
////////////////////////////////////////////////////////
//Driver
class Driver;
  mailbox   gen2drv_m;
  mailbox   drv2scb_m;
  event     drv2gen_e;
  vFifo_TB  test_intf;     //virtual interface for operation transimitting
  
  extern function new(input mailbox gen2drv_m,
                      input mailbox drv2scb_m,
                      input event drv2gen_e,
                      input vFifo_TB test_intf);
  extern task run();
  extern task send (input fifo_op gen_op);
  
endclass : Driver

//
function Driver::new(input mailbox gen2drv_m,
                     input mailbox drv2scb_m,
                     input event drv2gen_e,
                     input vFifo_TB test_intf);
  this.gen2drv_m = gen2drv_m;
  this.drv2scb_m = drv2scb_m;
  this.drv2gen_e = drv2gen_e;
  this.test_intf = test_intf;
endfunction : new

//run() : run the driver
task Driver::run();
  fifo_op gen_op;
  
  //Initialize ports
  test_intf.cb.wr_en <= 0;
  test_intf.cb.wr_data <= 0;
  test_intf.cb.rd_en <= 0;
  
  forever begin
    gen2drv_m.peek(gen_op);      //"peek" task gets a copy of data in mailbox but doesn't remove it
    send(gen_op);
    drv2scb_m.put(gen_op);       // ????
    gen2drv_m.get(gen_op);       //remove the data with "get" task after operation has been sent
    
    ->drv2gen_e;                 //tell generator to make next transaction
  end
endtask : run

//send() : Send a operation into DUT
task Driver::send(input fifo_op gen_op);
  for (i=0; i<gen_op.op_len; i++) begin
    case (op_type)
      2'b00: begin
        test_intf.wr_en <= 0;
        test_intf.rd_en <= 0;
        test_intf.wr_data <= 0;
      end
      2'b01: begin
        test_intf.wr_en <= 0;
        test_intf.rd_en <= 1;
        test_intf.wr_data <= 0;      
      end
      2'b10: begin
        test_intf.wr_en <= 1;
        test_intf.rd_en <= 0;
        test_intf.wr_data <= gen_op.wr_data[i];  // ?????
      end
      2'b11: begin
        test_intf.wr_en <= 1;
        test_intf.rd_en <= 1;
        test_intf.wr_data <= gen_op.wr_data[i];  // ?????
      end
    endcase
    @test_intf.cb;
  end    
endtask : send



/////////////////////////////////////////////////////////////
//Monitor
class Monitor;
  mailbox   mon2scb_m;
  vFifo_TB  test_intf;
  
  extern function new(input vFifo_TB test_intf,
                      input mailbox  mon2scb_m);
  extern task run();
  extern task receive(output fifo_op mon_op);
endclass : Monitor

//new
function Monitor::new(input vFifo_TB test_intf,
                      input mailbox mon2scb_m);
  this.test_intf = test_intf;
  this.mon2scb_m = mon2scb_m;
endfunction


task Monitor::run();
  fifo_op mon_op;
  
  forever begin
    receive(mon_op);
    mon2scb_m.put(mon_op);
  end
endtask : run


//receive task
task Monitor::receive(output fifo_op mon_op)
  while (test_intf.rd_en != 0) begin
    fork
      @test_intf.cb;
      @test_intf.cb;
      mon_op.rd_data = test_intf.rd_data;
    join
    @test_intf.cb;
  end
endtask : receive



///////////////////////////////////////////////////
///////////////////////////////////////////////////
//the scoreboard class
class Scoreboard;
  mailbox   drv2scb_m;
  mailbox   mon2scb_m;
  
  bit [31:0] expt[$];   //used to save expect data
  bit [31:0] actl[$];   //used to save actual data

  extern function new(input mailbox drv2scb_m,
                      input mailbox mon2scb_m);
                      
  extern task run();  
  
  extern task save_expect(input fifo_op gen_op);
  
  extern task save_actual(input fifo_op mon_op);
  
  extern task check();
  
endclass : Scoreboard


function Scoreboard::new(input mailbox drv2scb_m,
                         input mailbox mon2scb_m);
  this.drv2scb_m = drv2scb_m;
  this.mon2scb_m = mon2scb_m;
endfunction : new

//
task Scoreboard::run();
  fifo_op gen_op;
  fifo_op mon_op;
  
  forever begin
    fork
      drv2scb_m.get(gen_op);
      save_expect(gen_op);      
      mon2scb_m.get(mon_op);
      save_actual(mon_op);
    join
  end
endclass : run


//
task Scoreboard::save_expect(input fifo_op gen_op);
  while (gen_op.op_type[1] = 1) begin
    expt[$] = gen_op.wr_data;
  end
endtask : save_expect


//
task Scoreboard::save_actual(input fifo_op mon_op);
  actl[$] = mon_op.rd_data;
endtask : save_actual


//
task Scoreboard::check();
  ...
endtask : check



//////////////////////////////////////////////


