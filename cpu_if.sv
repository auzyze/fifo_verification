interface cpu_if;

logic CS;                       //chip selection
logic Rd_Wr;                    //1-read, 0-write
logic [3:0] Addr;               //accessing address
logic [7:0] DataIn, DataOut;    //data

//"local bus" : asynchoronous intel mode, no clocking needed
modport CFG
        (output CS, Rd_Wr, Addr, DataIn,
         input  DataOut);
         
         
endinterface

typedef virtual cpu_if.CFG vCPU_T;
