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
//          asps_put.v: asp* put interface and token propagation module           //
//          Authors: Brad Quinton and Ameer Abdelhadi (ameer@ece.ubc.ca)          //
//  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
//                                                                                //
// reset >------------------------.                                               //
//                            ____|_____                                          //
//                           | RST/SET | (STAGE=0 ? SET : RST)                    //
// req_put >---------+-------|CLK __   |                                          //
//                   |       |     |  Q|-------> put_token_out                    //
// put_token_in >----|---+---|D    v__ |                                          //
//                   |   |   |_________|                                          //
//                   |   |    ____                                                //
//                   |   '---|    \            .-----> ack_put                    //
//                   |       |     \  and_tmp  |                                  //
//                   '-------| AND  )----------+                                  //
//                           |     /           |                                  //
// empty >-------------------|____/            '-------> write                    //
//                                                                                //
////////////////////////////////////////////////////////////////////////////////////

module asps_put
  #( parameter  STAGE = 0    )  // stage index
   ( input      reset        ,  // global reset
     input      req_put      ,  // request put
     output     ack_put      ,  // acknowledge put
     input      put_token_in ,  // put token ring in
     output reg put_token_out,  // put token ring out
     output     write        ,  // write indicator to current stage
     input      empty        ); // current stage is empty

  // local wires 
  wire and_tmp;
  
  // flop to hold token state
  always@(negedge req_put or posedge reset)
    if (reset)
      if (STAGE == 0) put_token_out <= 1'b1;
      else            put_token_out <= 1'b0;
    else
      put_token_out <= put_token_in;

  // assign outputs
  assign and_tmp = req_put & put_token_in & empty;
  assign write   = and_tmp;
  assign ack_put = and_tmp;

endmodule // asps_put

