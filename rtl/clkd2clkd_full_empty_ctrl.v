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
//  clkd2clkd_full_empty_ctrl.v: clkd -> clkd stage full/empty controller module  //
//          Authors: Brad Quinton and Ameer Abdelhadi (ameer@ece.ubc.ca)          //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
// clk_  .----------------------.                                                 //
// get   |              ____    |    ____    ____       ____                      //
// >-----|-+--------.  |    |   |   |    |  |    |     |    |                     //
// reset | |        '->|CLK |   '-->|CLK-|->|CLK-|-..->|CLK |                     //
// >---+-|-|--------.  |    |       |    |  |    |     |    |                     //
// read| | |     __ '->|RST-|------>|RST-|->|RST-|-..->|RST | read_               //
// >---|-|-|---\\ X\   |    |read_r |    |  |    |     |    | r_sync  ____        //
//     | | |    ))OR)->|D _Q|---+-->|D _Q|->|D _Q|-..->|D _Q|--------\\   \  full //
//     | | | .-//__/   |_/  |   |   |_/  |  |_/  |     |_/  |         ))XOR)----> //
//     | | | |         |____|   |   |____|  |____|     |____|      .-//___/       //
//     | | | |                  |                                  |              //
//     | | | '------------------+--------------------------------. |              //
//     | | |                                                     | |              //
//     | | '--------------------.                                | |              //
// clk_| |              ____    |    ____    ____       ____     | |              //
// >---|-+----------.  |    |   |   |    |  |    |     |    |    | |              //
// put |            '->|CLK |   '-->|CLK-|->|CLK-|-..->|CLK |    | |              //
//     '------------.  |    |       |    |  |    |     |    |    | |  ____        //
// write         __ '->|RST-|------>|RST-|->|RST-|-..->|RST |    '-|-\\ X \ empty //
// >-----------\\ X\   |    |write_r|    |  |    |     |    |write |  ))NOR)O---> //
//              ))OR)->|D _Q|---+-->|D _Q|->|D _Q|-..->|D _Q|------|-//___/       //
//           .-//__/   |_/  |   |   |_/  |  |_/  |     |_/  |r_sync|              //
//           |         |____|   |   |____|  |____|     |____|      |              //
//           |                  |                                  |              //
//           '------------------+----------------------------------'              //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

module clkd2clkd_full_empty_ctrl
  #( parameter SYNCD = 3 )  // brute-force synchronizer depth
   ( input     reset     ,  // global reset
     input     clk_get   ,  // clock for receiver domain
     input     clk_put   ,  // clock for sender domain
     input     write     ,  // record write
     output    empty     ,  // fifo is empty
     input     read      ,  // record read
     output    full      ); // fifo is full

  // local wires/regs
  reg             read_r      ;
  reg             write_r     ;
  reg [SYNCD-1:0] write_r_sync;
  reg [SYNCD-1:0] read_r_sync ;
  
  // read flop
  always@(posedge clk_get or posedge reset)
    if (reset) read_r <= 1'b0                   ;
    else       read_r <= read ? ~read_r : read_r;
  
  // write flop
  always@(posedge clk_put or posedge reset)
    if (reset) write_r <= 1'b0                      ;
    else       write_r <= write ? ~write_r : write_r;

  // synchronize write flops into read clock domain
  always@(posedge clk_get or posedge reset)
    if (reset) write_r_sync <= {SYNCD{1'b0}                    };
    else       write_r_sync <= {write_r_sync[SYNCD-2:0],write_r};

  // synchronize read flops into write clock domain
  always@(posedge clk_put or posedge reset)
    if (reset) read_r_sync <= {SYNCD{1'b0}                  };
    else       read_r_sync <= {read_r_sync[SYNCD-2:0],read_r};  
  
  // assign outputs
  assign empty = ~(read_r               ^ write_r_sync[SYNCD-1]);
  assign full  =  (read_r_sync[SYNCD-1] ^ write_r              );
   
endmodule // clkd2clkd_full_empty_ctrl

