////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016, University of British Columbia (UBC)  All rights reserved. //
//                                                                                //
// Redistribution  and  use  in  source   and  binary  forms,   with  or  without //
// modification,  are permitted  provided that  the following conditions are met: //
//   * Redistributions   of  source   code  must  retain   the   above  copyright //
//     notice,  this   list   of   conditions   and   the  following  disclaimer. //
//   * Redistributions  in  binary  form  must  reproduce  the  above   copyright //
//     notice, this  list  of  conditions  and the  following  disclaimer in  the //
//     documentation and/or  other  materials  provided  with  the  distribution. //
//   * Neither the name of the University of British Columbia (UBC) nor the names //
//     of   its   contributors  may  be  used  to  endorse  or   promote products //
//     derived from  this  software without  specific  prior  written permission. //
//                                                                                //
// THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" //
// AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE //
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE //
// DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE //
// FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL //
// DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR //
// SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER //
// CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, //
// OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE //
// OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//              clkd2clkd_fifo.v: clkd -> clkd fifo top-level module              //
//          Authors: Brad Quinton and Ameer Abdelhadi (ameer@ece.ubc.ca)          //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
// >-----------------------------.  .-----------------------------------.         //
// reset                         |  |put_token                          |         //
//                               |  |  .------------------------------. |         //
//                               |  |  |get_token                     | |         //
// >--------------------------.  |  |  |  .---------------------------|-|-------< //
// clk_put       __           |  |  |  |  |                    __     | | clk_get //
// >------------|  \  en_put  |  |  |  |  |           en_get  /  |----|-|-------< //
// req_put      |AND)------.  |  |  |  |  |  .---------------(AND|    | | req_get //
//        .-----|__/       |  |  |  |  |  |  |                \__|--. | |         //
//        |               _V__V__V__V__V__V__V_                     | | |         //
//        |   .=========>| |  |  | STAGE  |  | |>===========.       | | |         //
//        |   ||         | |  |  |   n-1  |  | |dataout_tmp||       | | |         //
//        |   ||  .-----<|_|__|__|________|__|_|>-----.    ||       | | |         //
//        |   ||  |write_  |  |  |  V  V  |  |  read_ |    ::       | | |         //
//        |   ||  |enable  |  |  |  |  |  |  |  enable|    ::       | | |         //
//        |   ::  |        :  :  :  :  :  :  :        :    ||       | | |         //
//        |   ::  |        :  :  :  :  :  :  :        :    ||       | | |         //
//        |   ||  |        |  |  |  |  |  |  |        |    ||       | | |         //
//        |   ||  |       _V__V__V__|__|__V__V_       |    ||       | | |         //
//        |   |+==|=====>| |  |  |        |  | |>=====|==. ||       | | |         //
//        |   ||  |      | |  |  |STAGE 1 |  | |      | || ||       | | |         //
//        |   ||  | .---<|_|__|__|________|__|_|>---. | || ||       | | |         //
//        |   ||  | |      |  |  |  V  V  |  |      | | || ||       | | |         //
//        |   ||  | |      |  |  |  |  |  |  |      | | || ||       | | |         //
//        |   ||  | |      |  |  |  |  |  |  |      | | || ||  __   | | |         //
//        |   ||  | |      |  |  |  |  |  |  |      | | || '==\  \  | | |         //
//        |   ||  | |     _V__V__V__V__V__V__V_     | | '======)OR)=|=|=|=======> //
// >======|====+==|=|===>|                     |>===|=|=======/__/  | | | dataout //
// datain |   __  | |    |        STAGE 0      |    | |        __   | | |         //
//        |  /  /-' | .-<|_____________________|>-. | '-------\  \  | | |         //
// <------+-(OR(----' |             V  V          | '----------)OR)-+-|-|-------> //
// spaceav   \__\-----'             |  |          '-----------/__/    | |   datav //
//                                  |  '------------------------------' |         //
//                                  '-----------------------------------'         //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

// include configuration file; generated by scr/do; defines DATAWD, STAGES &  SYNCDP
`include "config.h"

module clkd2clkd_fifo
  #( parameter               DATAWD = `DATAWD,  // data bus width
     parameter               STAGES = `STAGES,  // number of fifo stages
     parameter               SYNCDP = `SYNCDP,  // brute-force synchronizer depth
     parameter               PIPESA = `PIPESA,  // pipeline spaceav (FIFO not full ) signale
     parameter               PIPEDV = `PIPEDV)  // pipeline datav   (FIFO not empty) signal
   ( input                   reset           ,  // global reset 
     input                   clk_put         ,  // clocked sender  : clock for sender domain
     input                   req_put         ,  // clocked sender  : request put
     output                  spaceav         ,  // clocked sender  : space available indicator
     input  [DATAWD-1:0]     datain          ,  // clocked sender  : data in
     input                   clk_get         ,  // clocked receiver: clock for receiver domain
     input                   req_get         ,  // clocked receiver: request get
     output                  datav           ,  // clocked receiver: data valid indicator
     output reg [DATAWD-1:0] dataout         ); // clocked receiver: data out

  // local registers and wires
  wire              en_put                  ;
  wire              en_get                  ;
  wire [STAGES-1:0] write_enable            ;
  wire [STAGES-1:0] read_enable             ;
  wire [DATAWD-1:0] dataout_tmp [STAGES-1:0];
  wire [STAGES  :0] put_token_in_tmp        ;
  wire [STAGES  :0] get_token_in_tmp        ;
  integer           j                       ;

  // create 'spaceav' signal
  generate
    if (PIPESA) begin : PIPELINEDSPACEAV
      spaceav_datav_pipe    #(.STAGES           (STAGES      ))  // number of FIFO stages
      clkd2clkd_spaceav_pipe (.reset            (reset       ),  // global reset 
                              .clk_put_get      (clk_put     ),  // clock for sender domain
                              .en_put_get       (en_put      ),  // enable put
                              .write_read_enable(write_enable),  // write enables (for each stage)
                              .spaceav_datav    (spaceav     )); // spaveav pipelined signals
    end
    else begin : NOTPIPELINEDSPACEAV
      assign spaceav = |write_enable; 
    end
  endgenerate

  // create internal 'en_put' signal
  assign en_put = spaceav && req_put;

  // loopback tokens
  assign put_token_in_tmp[0] = put_token_in_tmp[STAGES];
  assign get_token_in_tmp[0] = get_token_in_tmp[STAGES];
  
  // create FIFO stages
  genvar i;
  generate for (i=0; i < STAGES; i=i+1)
    begin : stage_gen
      clkd2clkd_stage   #( .DATAW         (DATAWD               ),  // param : data bus width
                           .STAGE         (i                    ),  // param : stage index
                           .SYNCD         (SYNCDP               ))  // param: brute-force synchronizer depth
      clkd2clkd_stage_i  ( .reset         (reset                ),  // global reset
                           .clk_put       (clk_put              ),  // input : clocked sender  : clock for sender domain
                           .datain        (datain               ),  // input : clocked sender  : data in
                           .en_put        (en_put               ),  // input : clocked sender  : enable put
                           .write_enable  (write_enable[i]      ),  // output: clocked sender  : writing enable
                           .put_token_in  (put_token_in_tmp[i]  ),  // input : fifo ring       : put token in
                           .put_token_out (put_token_in_tmp[i+1]),  // output: fifo ring       : put token out
                           .get_token_in  (get_token_in_tmp[i]  ),  // input : fifo ring       : get token in
                           .get_token_out (get_token_in_tmp[i+1]),  // output: fifo ring       : get token out
                           .clk_get       (clk_get              ),  // input : clocked receiver: clock for receiver domain
                           .en_get        (en_get               ),  // input : clocked receiver: enable get
                           .read_enable   (read_enable[i]       ),  // output: clocked receiver: enable reading
                           .dataout       (dataout_tmp[i])      );  // output: clocked receiver: data out
    end // block: stage_gen
  endgenerate
 
  // or together the dataout busses..
  always @* begin
      dataout = {DATAWD{1'b0}};
      for (j=0; j< STAGES; j=j+1)
        dataout = dataout | dataout_tmp[j];
  end


  // create 'datav' signal
  generate
    if (PIPEDV) begin : PIPELINEDDATAV
      spaceav_datav_pipe  #(.STAGES           (STAGES     ))  // number of FIFO stages
      clkd2clkd_datav_pipe (.reset            (reset      ),  // global reset 
                            .clk_put_get      (clk_get    ),  // clock for receiver domain
                            .en_put_get       (en_get     ),  // enable get
                            .write_read_enable(read_enable),  // read enables (for each stage)
                            .spaceav_datav    (datav      )); // datav pipelined signals
    end
    else begin : NOTPIPELINEDDATAV
      assign datav = |read_enable; 
    end
  endgenerate

  // create internal signals
  assign en_get = datav & req_get;
  
endmodule // clkd2clkd_fifo

