interface cpu_if;

logic CS;                       //chip selection
logic Rd_Wr;                    //1-read, 0-write
logic [3:0] Addr;               //accessing address
logic [7:0] DataIn, DataOut;    //data


modport Peripheral
        (input CS, Rd_Wr, Addr, Datain,
         output DataOut);

modport Cfg
        (output CS, Rd_Wr, Addr, DataIn,
         input  DataOut);
         
         
endinterface
