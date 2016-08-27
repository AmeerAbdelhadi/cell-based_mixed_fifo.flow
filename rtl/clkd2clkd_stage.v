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
//                clkd2clkd_stage.v: clkd -> clkd fifo stage module               //
//          Authors: Brad Quinton and Ameer Abdelhadi (ameer@ece.ubc.ca)          //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
//                put_token_out                     get_token_out                 //
//                     ^                                 ^                        //
//                     |                                 |                        //
//                  ___|___          _______          ___|___                     //
//                 |       |        |       |        |       |                    //
// reset   ------->|-------|------->|-------|------->|       |                    //
//                 |       |        |       |        |       |                    //
// clk_put ---+--->|-------|------->|       |<-------|-------|<---------- clk_get //
//            |    |       | full   | clkd_ |  empty |       |                    //
// en_put  ---|--->|       |<-------| full_ |------->|       |<----------- en_get //
//            |    | clkd  | write  | empty |  read  | clkd  |                    //
// write_ <---|----| _put  |-----+->| _ctrl |<-------| _get  |------> read_enable //
// enable     |    |_______|     |  |_______|        |_______|                    //
//            |        ^         |                       ^                        //
//            |        |    _____|_____                  |                        //
//            |        |   |    ENB    |                 |      ____              //
//            '--------|---|CLK        |                 +--|==|    \             //
//                     |   |  _     _  | dataout_tmp     |     | AND )==> dataout //
// datain >============|===|D  |___|  Q|=======================|____/             //
//                     |   |___________|                 |                        //
//                     |                                 |                        //
//                     |                                 |                        //
//                put_token_in                      get_token_in                  //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

module clkd2clkd_stage
  #(  parameter DATAW = 32            ,  // data bus width
      parameter STAGE = 0             ,  // stage index
      parameter SYNCD = 3             )  // brute-force synchronizer depth
   (  input              reset        ,  // global reset
      input              clk_put      ,  // clocked sender  : clock for sender domain
      input              en_put       ,  // clocked sender  : enable put
      output             write_enable ,  // clocked sender  : writing enable
      input  [DATAW-1:0] datain       ,  // clocked sender  : data in
      input              put_token_in ,  // fifo ring       : put token in
      output             put_token_out,  // fifo ring       : put token out
      input              get_token_in ,  // fifo ring       : get token in
      output             get_token_out,  // fifo ring       : get token out
      input              clk_get      ,  // clocked receiver: clock for receiver domain
      input              en_get       ,  // clocked receiver: enable get
      output             read_enable  ,  // clocked receiver: enable reading
      output [DATAW-1:0] dataout      ); // clocked receiver: data out

  // local registers and wires
  reg    [DATAW-1:0] dataout_tmp;
  wire               write      ;
  wire               read       ;
  wire               empty      ;
  wire               full       ;
  
  // clkd_put.v: clocked put interface and token propagation module
  clkd_put   #( .STAGE         (STAGE        ))  // param : stage index 
  clkd_put_i  ( .reset         (reset        ),  // input : global reset
                .clk_put       (clk_put      ),  // input : clock for sender domain
                .en_put        (en_put       ),  // input : enable put
                .write_enable  (write_enable ),  // output: enable writting
                .put_token_in  (put_token_in ),  // input : put token ring in
                .put_token_out (put_token_out),  // output: put token ring out
                .write         (write        ),  // output: write indicator to current stage
                .full          (full         )); // input : current stage is full

  // clkd_get.v: clocked interface and get token propagation module
  clkd_get   #( .STAGE         (STAGE        ))  // param : stage index 
  clkd_get_i  ( .reset         (reset        ),  // input : global reset
                .clk_get       (clk_get      ),  // input : clock for receiver domain
                .en_get        (en_get       ),  // input : enable get
                .read_enable   (read_enable  ),  // output: enable reading
                .get_token_in  (get_token_in ),  // input : get token ring in
                .get_token_out (get_token_out),  // output: get token ring out
                .read          (read         ),  // output: read indicator to current stage
                .empty         (empty        )); // input : current stage is ful

  // clkd2clkd_full_empty_ctrl.v: clkd -> clkd stage full/empty controller module
  clkd2clkd_full_empty_ctrl   #( .SYNCD   (SYNCD  ))  // param : brute-force synchronizer depth
  clkd2clkd_full_empty_ctrl_i  ( .reset   (reset  ),  // input : global reset
                                 .clk_get (clk_get),  // input : clock for receiver domain
                                 .clk_put (clk_put),  // input : clock for sender domain
                                 .write   (write  ),  // input : record write
                                 .empty   (empty  ),  // output: fifo is empty
                                 .read    (read   ),  // input : record read
                                 .full    (full   )); // output: fifo is full

  // latch data
always@(clk_put or datain)
    if (~clk_put)
      if (write)
        dataout_tmp <= datain;

  // gate invalid data for OR-tree
  assign dataout = dataout_tmp & {DATAW{get_token_in}};

endmodule // clkd2clkd_stage


  
  
  
