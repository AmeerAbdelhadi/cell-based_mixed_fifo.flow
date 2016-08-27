#!/usr/bin/perl -w

####################################################################################
## Copyright (c) 2016, University of British Columbia (UBC)  All rights reserved. ##
##                                                                                ##
## Redistribution  and  use  in  source   and  binary  forms,   with  or  without ##
## modification,  are permitted  provided that  the following conditions are met: ##
##   * Redistributions   of  source   code  must  retain   the   above  copyright ##
##     notice,  this   list   of   conditions   and   the  following  disclaimer. ##
##   * Redistributions  in  binary  form  must  reproduce  the  above   copyright ##
##     notice, this  list  of  conditions  and the  following  disclaimer in  the ##
##     documentation and/or  other  materials  provided  with  the  distribution. ##
##   * Neither the name of the University of British Columbia (UBC) nor the names ##
##     of   its   contributors  may  be  used  to  endorse  or   promote products ##
##     derived from  this  software without  specific  prior  written permission. ##
##                                                                                ##
## THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ##
## AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE ##
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE ##
## DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE ##
## FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL ##
## DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR ##
## SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER ##
## CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, ##
## OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE ##
## OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. ##
####################################################################################

####################################################################################
##                          Final report generator                                ##
##                  Author: Ameer Abdelhadi (ameer@ece.ubc.ca)                    ##
##  Cell-based Mixed FIFOs :: University of British Columbia  (UBC) :: July 2016  ##
####################################################################################

use strict;   # Install all strictures
use warnings; # Show warnings
$|++;         # Force auto flush of output buffer

# global variables
my $logdir        = $ENV{'LOGDIR'       };
my $repdir        = $ENV{'REPDIR'       };
my $pwrdir        = $ENV{'PWRDIR'       };
my $dataln        = $ENV{'SIMDATALN'    };
my $clkdSynFrqScl = $ENV{'CLKDSYNFRQSCL'};
my $asynSynFrqScl = $ENV{'ASYNSYNFRQSCL'};
my $simPutPerScl  = $ENV{'SIMPUTPERSCL' };
my $simGetPerScl  = $ENV{'SIMGETPERSCL' };

# print report header
print "                                           Pipelined  F r e q u e n c y   ( M h z )  Gate-level Simulation %   T o t a l   C e l l   C o u n t  T o t a l  C e l l  A r e a  (um^2)  T o t a l D e v i c e C o u n t  D i s s i p a t e d   P o w e r   ( w )  Latency (ps), Performance & Bitrate   \n";
print "                                           ---------  -----------------------------  ------------------------  -------------------------------  -----------------------------------  -------------------------------  ---------------------------------------  -----------------------------------  T o t a l   W i r e   L e n g t h  ( u m )  Run- \n";
print "Sender    Receiver  Stages  Data    Sync.  spa- dat-  Requ-  Synthesis  Simulation   FAST RAND EMPT HALF FULL  Combin- Sequen- Synchr- Total    Combin-  Sequen-  Synchr-  Total     Combin- Sequen- Synchr- Total    Net       Cell      Cell      Total      Forward  Backward Performa- Bitrate  ------------------------------------------  Time \n";
print "Protocol  Protocol  Number  Width   Depth  ceav av    ired  Clkd   Asyn  put   get   Test Test Test Test Test  atoril  tial    onizers Cells    atorial  tial     onizers  Area      atoril  tial    onizers Devices  Switching Dynamic   Leakage   Power      Latency  Latency  nce (Mhz) Gbit/s   Metal1 Metal2 Metal3 Metal4 Metal5 TotalWL  (Min)\n";
print "========  ========  ======  ======  =====  ==== ====  ===== ===== ===== ===== =====  ==== ==== ==== ==== ====  ======= ======= ======= =======  ======== ======== ======== ========  ======= ======= ======= =======  ========= ========= ========= =========  ======== ======== ========= =======  ====== ====== ====== ====== ====== =======  =====\n";

my @logfiles  = <$logdir/*.rnd.sim.log>;
my $logfilen  = $#logfiles+1;
my $logfilei  = 0;
foreach my $logfile (@logfiles) {  

  $logfilei++;

  if ($logfile =~ /(clkd|asps)2(clkd|asps)_(\d+)X(\d+)_(\d+)MHz_(\d+)FF_(\d+)_(\d+)\.rnd\.sim\.log/) {
    my ($snd,$rcv,$stg,$wdt,$frq,$syncdp,$pipesa,$pipedv) = ($1,$2,$3,$4,$5,$6,$7,$8);
    my $runnam = "${snd}2${rcv}_${stg}X${wdt}_${frq}MHz_${syncdp}FF_${pipesa}_${pipedv}";

    print STDERR "\($logfilei/$logfilen\)\: Reorting $runnam\n";

    my %tstfiles;
    my @tsts = qw(fst rnd emp mid fll);
    foreach my $tst (@tsts) {
      open(TSTHND,"$logdir/$runnam.$tst.sim.log") || print STDERR "Failed to open simulation file $logdir/$runnam.$tst.sim.log\n";
      my @tstlines = <TSTHND>;
      $tstfiles{$tst} = \@tstlines;
      close(TSTHND);
    }
    
    my $fsttst = -9; if ("@{$tstfiles{'fst'}}" =~ /\((\d+)\%\)/) {$fsttst = $1}
    my $rndtst = -9; if ("@{$tstfiles{'rnd'}}" =~ /\((\d+)\%\)/) {$rndtst = $1}
    my $emptst = -9; if ("@{$tstfiles{'emp'}}" =~ /\((\d+)\%\)/) {$emptst = $1}
    my $midtst = -9; if ("@{$tstfiles{'mid'}}" =~ /\((\d+)\%\)/) {$midtst = $1}
    my $flltst = -9; if ("@{$tstfiles{'fll'}}" =~ /\((\d+)\%\)/) {$flltst = $1}

    my $forLat = -9; if ("@{$tstfiles{'emp'}}" =~ /Forward\D+(\d+)ps/    ) {$forLat = $1               }
    my $bacLat = -9; if ("@{$tstfiles{'fll'}}" =~ /Backward\D+(\d+)ps/   ) {$bacLat = $1               }
    my $perf   = -9; if ("@{$tstfiles{'fst'}}" =~ /Throughput\D+(\d+)Mhz/) {$perf   = $1               }
                     if ("@{$tstfiles{'mid'}}" =~ /Throughput\D+(\d+)Mhz/) {$perf   = $1>$perf?$1:$perf}

    my $cellStatFile = "${repdir}/${runnam}.cellStatistics.pnr.rep"             ;
    my ($comCllCnt,$comCllAre,$comPchCnt,$comNchCnt,$comDevCnt)=(0,0,0,0,0);
    my ($seqCllCnt,$seqCllAre,$seqPchCnt,$seqNchCnt,$seqDevCnt)=(0,0,0,0,0);
    my ($totCllCnt,$totCllAre,$totPchCnt,$totNchCnt,$totDevCnt)=(0,0,0,0,0);
    if (open(my $CELLSTATHAND,$cellStatFile)) {
      foreach my $cellStatLine (<$CELLSTATHAND>) {
        if ($cellStatLine =~ /^COMBINATORIAL\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) { ($comCllCnt,$comCllAre,$comPchCnt,$comNchCnt,$comDevCnt)=($1,$2,$3,$4,$5);next;}
        if ($cellStatLine =~ /^SEQUENTIAL\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/   ) { ($seqCllCnt,$seqCllAre,$seqPchCnt,$seqNchCnt,$seqDevCnt)=($1,$2,$3,$4,$5);next;}
        if ($cellStatLine =~ /^TOTAL\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/        ) { ($totCllCnt,$totCllAre,$totPchCnt,$totNchCnt,$totDevCnt)=($1,$2,$3,$4,$5);next;}
      }
      close($CELLSTATHAND);
    } else {print STDERR "failed to open cells statistics file $cellStatFile\n"}
    
    my $syncStatFile = "${repdir}/${runnam}.syncStatistics.pnr.rep";
    my ($synCllCnt,$synCllAre,$synPchCnt,$synNchCnt,$synDevCnt)=(0,0,0,0,0);
    if (open(my $SYNCSTATHAND,$syncStatFile)) {
      foreach my $syncStatLine (<$SYNCSTATHAND>) {
        if ($syncStatLine =~ /^TOTAL\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)/) {
          ($synCllCnt,$synCllAre,$synPchCnt,$synNchCnt,$synDevCnt)=($1,$2,$3,$4,$5); next;
        }
      }
      close($SYNCSTATHAND);
    } else {print STDERR "failed to open cells statistics file $syncStatFile\n"}

    my $pwrfile = "${pwrdir}/${runnam}.power.rep";
    my ($netSwtPwr,$cllDynPwr,$cllLkgPwr,$totPwr)=(0,0,0,0);
    if (open(my $PWRHND,$pwrfile)) {
      foreach my $pwrline (<$PWRHND>) {
        if ($pwrline =~ /Net Switching Power\s*\=\s*(\S+)\s*\(/) { $netSwtPwr=$1; next;}
        if ($pwrline =~ /Cell Internal Power\s*\=\s*(\S+)\s*\(/) { $cllDynPwr=$1; next;}
        if ($pwrline =~ /Cell Leakage Power\s*\=\s*(\S+)\s*\(/ ) { $cllLkgPwr=$1; next;}
        if ($pwrline =~ /Total Power\s*\=\s*(\S+)\s*\(/        ) { $totPwr   =$1; next;}
      }
      close($PWRHND);
    } else {print STDERR "failed to open power report file $pwrfile\n"}

    my $runtimefile = "${repdir}/${runnam}.runtime.rep";
    my ($runtimeHr,$runtimeMn,$runtimeSc,$runtimeMin)=(0,0,0,0);
    if (open(my $RUNTIMEHND,$runtimefile)) {
      my @runtimelines = <$RUNTIMEHND>;
      if ($runtimelines[0] =~ /(\d*)\:(\d*)\:(\d*)=(\d*\.\d*)min/) { $runtimeHr=$1; $runtimeMn=$2; $runtimeSc=$3; $runtimeMin=$4;}
      close($RUNTIMEHND);
    } else {print STDERR "failed to open runtime report file $runtimefile"}

    my $pnrfile = "${logdir}/${runnam}.pnr.log";
    my ($m1WL,$m2WL,$m3WL,$m4WL,$m5WL,$totWL)=(0,0,0,0,0,0);
    if (open(my $PNRHND,$pnrfile)) {
      foreach my $pnrline (<$PNRHND>) {
        if ($pnrline =~ /\#Total wire length \= (\S+) um\./            ) { $totWL=$1; next;}
        if ($pnrline =~ /\#Total wire length on LAYER M1 \= (\S+) um\./) { $m1WL =$1; next;}
        if ($pnrline =~ /\#Total wire length on LAYER M2 \= (\S+) um\./) { $m2WL =$1; next;}
        if ($pnrline =~ /\#Total wire length on LAYER M3 \= (\S+) um\./) { $m3WL =$1; next;}
        if ($pnrline =~ /\#Total wire length on LAYER M4 \= (\S+) um\./) { $m4WL =$1; next;}
        if ($pnrline =~ /\#Total wire length on LAYER M5 \= (\S+) um\./) { $m5WL =$1; next;}
      }
      close($PNRHND);
    } else {print STDERR "failed to open place & route log file $pnrfile"}

    printf("%-8s  %-8s  %-6u  %-6u  %-5u  %-4u %-4u  ",$snd,$rcv,$stg,$wdt,,$syncdp,$pipesa,$pipedv    );
    printf("%-5.0f %-5.0f %-5.0f %-5.0f %-5.0f  "     ,$frq,$clkdSynFrqScl*$frq,$asynSynFrqScl*$frq,
                                                       $simPutPerScl*$frq ,$simGetPerScl*$frq          );
    printf("%-4d %-4d %-4d %-4d %-4d  "               ,$fsttst,$rndtst,$emptst,$midtst,$flltst         );
    printf("%-7u %-7u %-7u %-7u  "                    ,$comCllCnt,$seqCllCnt,$synCllCnt,$totCllCnt     );
    printf("%-8.1f %-8.1f %-8.1f %-8.1f  "            ,$comCllAre,$seqCllAre,$synCllAre,$totCllAre     );
    printf("%-7u %-7u %-7u %-7u  "                    ,$comDevCnt,$seqDevCnt,$synDevCnt,$totDevCnt     );
    printf("%-9.3e %-9.3e %-9.3e %-9.3e  "            ,$netSwtPwr,$cllDynPwr,$cllLkgPwr,$totPwr        );
    printf("%-8.0f %-8.0f %-8.0f  %-7.4f  "           ,$forLat,$bacLat,$perf,$wdt*$perf/1E3            );
    printf("%-6u %-6u %-6u %-6u %-6u %-7u  %5.2f\n"   ,$m1WL,$m2WL,$m3WL,$m4WL,$m5WL,$totWL,$runtimeMin); 
  }
}
