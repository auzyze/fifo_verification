class Environment;

  Generator     gen;
  
  mailbox       gen2drv;
  mailbox       drv2scb;
  mailbox       mon2scb;
  
  event         drv2gen;
  
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
  gen = new();
  drv = new();
  
  gen2drv = new();                    //mailbox X 3
  drv2scb = new();
  mon2scb = new();
  
  drv2gen = new();                    //event
  
  scb = new(cfg);                     //construct scoreboard with cfg info
  cov = new();
  mon = new();  
  
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
//Define fifo transaction
class fifo_op;
  rand bit [1:0]  op_type;      //op_type[1]=1 means write, [0]=1 mean read
  rand bit [15:0] op_len;       //duration of write, or read, or both
  
  rand bit [31:0] wr_data [];   //how to randomize a dynamic array??
    
  bit [31:0] rd_data;
  bit full;
  bit empty;
  bit afull;
  bit aempty;

  //static bit [15:0] wr_count;
  //static bit [15:0] rd_count;

  //extern function new();
  //extern function void post_randomize();
    
endclass : fifo_op



///////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////
//FIFO Operation Generator
class Generator;
  fifo_op gen_op;
  mailbox gen2drv;
  event   drv2gen;
  
  int     op_num;
  
  function new(input mailbox gen2drv,
               input event drv2gen,
               input int op_num);
    this.gen2drv = gen2drv;
    this.drv2gen = drv2gen;
    this.op_num = op_num;
    gen_op = new();
  endfunction : new
  
  task run();
    repeat (op_num) begin
      assert (gen_op.randomize());
      gen2drv.put(gen_op);
      @drv2gen; //Wait for driver to finish with it
    end
  endtask : run
  
endclass : Generator



//////////////////////////////////////////////////////
////////////////////////////////////////////////////////
//Driver
class Driver;
  mailbox gen2drv;
  mailbox drv2scb;
  event   drv2gen;
  vFifo_TB test_intf;     //virtual interface for operation transimitting
  
  extern function new(input mailbox gen2drv,
                      input mailbox drv2scb,
                      input event drv2gen,
                      input vFifo_TB test_intf);
  extern task run();
  extern task send (input fifo_op gen_op);
  
endclass : Driver

//
function Driver::new(input mailbox gen2drv,
                     input event drv2gen,
                     input vFifo_TB test_intf);
  this.gen2drv = gen2drv;
  this.drv2gen = drv2gen;
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
    gen2drv.peek(gen_op);      //"peek" task gets a copy of data in mailbox but doesn't remove it
    send(gen_op);
    gen2drv.get(gen_op);       //remove the data with "get" task after operation has been sent
    drv2scb.put(gen_op);       // ????
    ->drv2gen;
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
        test_intf.wr_data <= gen_op.wr_data[];  // ?????
      end
      2'b11: begin
        test_intf.wr_en <= 1;
        test_intf.rd_en <= 1;
        test_intf.wr_data <= gen_op.wr_data[];  // ?????
      end
    endcase
    @test_intf.cb;
  end
  
endtask : Driver



/////////////////////////////////////////////////////////////
//Monitor

class Monitor;
  mailbox   mon2scb;
  vFifo_TB  test_intf;
  
  extern function new(input vFifo_TB test_intf,
                      input mailbox  mon2scb);
  extern task run();
  extern task receive(output fifo_op mon_op);
endclass : Monitor

//new
function Monitor::new(input vFifo_TB test_intf,
                      input mailbox mon2scb);
  this.test_intf = test_intf;
  this.mon2scb = mon2scb;
endfunction


task Monitor::run();
  fifo_op mon_op;
  
  forever begin
    receive(mon_op);
    @rcv_ok;                  //event
    mon2scb.put(mon_op);
  end
  
endtask : run


//receive task
task Monitor::receive(output fifo_op mon_op)
  int index = 0;
  while (test_intf.rd_en != 0) begin
    mon_op.rd_data[index] = test_intf.rd_data;
    index++;
    @test_intf.cb;
  end
  ->rcv_ok;                   //event
endtask : receive



///////////////////////////////////////////////////
///////////////////////////////////////////////////
//the scoreboard class
class Scoreboard;
  mailbox   drv2scb;
  mailbox   mon2scb;
  
  bit [31:0] expt[$];   //used to save expect data
  bit [31:0] actl[$];   //used to save actual data

  extern function new(input mailbox drv2scb,
                      input mailbox mon2scb);
                      
  extern task run();  
  
  extern task save_expect(input fifo_op gen_op);
  
  extern task save_actual(input fifo_op mon_op);
  
  extern task check();
  
endclass : Scoreboard


function Scoreboard::new(input mailbox drv2scb,
                         input mailbox mon2scb);
  this.drv2scb = drv2scb;
  this.mon2scb = mon2scb;
endfunction : new

//
task Scoreboard::run();
  fifo_op gen_op;
  fifo_op mon_op;
  
  forever begin
    fork
      drv2scb.get(gen_op);
      save_expect(gen_op);      
      mon2scb.get(mon_op);
      save_actual(mon_op);
    join
  end
endclass : run


//
task Scoreboard::save_expect(input fifo_op gen_op);
  while (gen_op.op_type[1] = 1) begin
    expt[$] = gen_op.wr_data;
    //@test_intf.cb
  end
endtask : save_expect


//
task Scoreboard::save_actual(input fifo_op mon_op);
  while (mon_op.op_type[0] = 1) begin
    actl[$] = mon_op.rd_data;
    //@test_intf.cb
  end
endtask : save_actual


//
task Scoreboard::check();
  ...
endtask : check



//////////////////////////////////////////////


