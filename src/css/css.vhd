--
-- Embb ( http://embb.telecom-paristech.fr/ ) - This file is part of Embb
-- Copyright (C) - Telecom ParisTech
-- Contacts: contact-embb@telecom-paristech.fr
--
-- This file must be used under the terms of the CeCILL.
-- This source file is licensed as described in the file COPYING, which
-- you should have received as part of this distribution. The terms
-- are also available at
-- http://www.cecill.info/licences/Licence_CeCILL_V2.1-en.txt
--

--* @id $Id: css.vhd 4237 2012-08-29 14:19:32Z rpacalet $
--* @brief Control Sub-System
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2011-07-26
--*
--* Changes log
--*
--* - 2011-08-30 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - Added generic parameters to make MSS, DMA, PSS and UC optional 
--*
--*   - Added generic parameters for debugging
--*
--* - 2012-01-20 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - Added generic parameters n0 and n1 (MSS input and output pipeline depths)
--*
--* - 2017-03-01 by Christian Palmiero (palmiero@eurecom.fr): 
--*   - Rework CSS communication infrastracture (AXI4Lite protocol) 

library ieee;
use ieee.std_logic_1164.all;

library global_lib;
use global_lib.global.all;
use global_lib.axi4lite_pkg.all;

use work.bitfield.all;
use work.css_pkg.all;

entity css is
  generic(
-- pragma translate_off
          debug:     boolean := true;       --* Print debug information
          verbose:   boolean := false;      --* Print more debug information
          name:      string  := "DSP Unit"; --* Name of surrounding DSP Unit
-- pragma translate_on
          n_pa_regs: natural range 0 to 15; --* Number of 64-bits parameters registers
          pa_rmask:  std_ulogic_vector;
          pa_wmask:  std_ulogic_vector;
          with_dma:  boolean := true;
          with_pss:   boolean := true;
          with_mss:  boolean := true;
          n0:        positive := 1;         --* Number of input pipeline registers in MSS, including input registers of RAMs
          n1:        positive := 1;         --* Number of output pipeline registers in MSS, including output registers of RAMs
          neirq:     natural range 0 to 32 := 0); --* Number of extended interrupt requests
  port(clk:      in  std_ulogic;
       srstn:    in  std_ulogic;
       ce:       in  std_ulogic;
       hirq:     in  std_ulogic;
       uirq:     out std_ulogic;      --* Output interrupt request from UC to host system
       pirq:     out std_ulogic;      --* Output interrupt request from PSS to host system
       dirq:     out std_ulogic;      --* Output interrupt request from DMA to host system
       eirq:     out std_ulogic_vector(neirq - 1 downto 0); --* Output interrupt requests to host system
       pss2css:  in  pss2css_type;
       css2pss:  out css2pss_type;
       param:    out std_ulogic_vector(n_pa_regs * 64 - 1 downto 0);
       mss2css:  in  mss2css_type;
       css2mss:  out css2mss_type;
       taxi_in:  in  axi4lite_m2s_type;
       taxi_out: out axi4lite_s2m_type;
       maxi_in:  in  axi4lite_m2s_type;
       maxi_out: out axi4lite_s2m_type;
       iaxi_in:  in  axi4lite_s2m_type;
       iaxi_out: out axi4lite_m2s_type);
  constant wdma: boolean := with_mss and with_dma; -- No DMA if no MSS
  constant wpss:  boolean := with_pss;
  constant wmss: boolean := with_mss;
  --* Depth of target AXI requests FIFO
  constant req_fifo_depth: natural := 2;
  --* Depth of target AXI responses FIFO. Must be deep enough to store responses of all acknowledged requests, that is: REQ_FIFO_DEPTH+N0+N1+2 (the +2
  --* corresponds to the output register of VIA in which access requests to MSS are latched and to the input register of VIA in which MSS read data are latched.
  constant rsp_fifo_depth: natural := req_fifo_depth + 2; -- +n0 + n1;

end entity css;

architecture rtl of css is

  signal ctrl2dma:   ctrl2dma_type;
  signal dma2ctrl:   dma2ctrl_type;
  signal dma2ctrl_w: dma2ctrl_type;
  signal dma2mss_w:  dma2mss_type;
  signal iaxi_out_w: axi4lite_m2s_type;
  signal ctrl2rsp:   ctrl2rsp_type;
  signal req2ctrl:   req2ctrl_type;
  signal ack_rsp:    natural range 0 to rsp_fifo_depth;
  signal mss_ack_rsp:natural range 0 to rsp_fifo_depth;
  signal err:        std_ulogic;

begin

  req: entity work.requests_fifo(rtl)
    generic map(depth => req_fifo_depth)
    port map(clk     => clk,
             srstn   => srstn,
             ce      => ce,
             req_in  => taxi_in.axi4lite_request,
             ack_rsp => ack_rsp,
             ack     => ctrl2rsp.ack,
	     req2ctrl=> req2ctrl,
             err     => err, 
	     awready => taxi_out.awready,
	     wready  => taxi_out.wready,
             arready => taxi_out.arready);

  rsp: entity work.responses_fifo(rtl)
    generic map(depth => rsp_fifo_depth)
    port map(clk     => clk,
             srstn   => srstn,
             ce      => ce,
             ctrl2rsp=> ctrl2rsp,
             en      => req2ctrl.en,
             rnw     => req2ctrl.rnw,
             err     => err,
             rsp_out => taxi_out.axi4lite_response,
             bready  => taxi_in.bready,
             rready  => taxi_in.rready,
             ack     => ack_rsp);

  mss_req: entity work.mss_requests_fifo(rtl)
    generic map(depth => req_fifo_depth)
    port map(clk         => clk,
             srstn       => srstn,
             ce          => ce,
             req_in      => maxi_in.axi4lite_request,
             ack_rsp     => mss_ack_rsp,
             mss_awready => mss2css.mss2rsp.awready,
             mss_wready  => mss2css.mss2rsp.wready,
             mss_arready => mss2css.mss2rsp.arready,
	     req2mss     => css2mss.req2mss.axi4lite_request,
             hst_awready => maxi_out.awready,
             hst_wready  => maxi_out.wready,
             hst_arready => maxi_out.arready);

  mss_rsp: entity work.mss_responses_fifo(rtl)
    generic map(depth => rsp_fifo_depth)
    port map(clk        => clk,
             srstn      => srstn,
             ce         => ce,
             mss2rsp    => mss2css.mss2rsp.axi4lite_response,
             hst_bready => maxi_in.bready,
             hst_rready => maxi_in.rready,
             mss_bready => css2mss.req2mss.bready,
             mss_rready => css2mss.req2mss.rready,
             rsp_out    => maxi_out.axi4lite_response,
             ack        => mss_ack_rsp);
  
ctrl: entity work.ctrl(rtl)
    generic map(
-- pragma translate_off
                debug     => debug,
                verbose   => verbose,
                name      => name,
-- pragma translate_on
                hst_level_interrupts => false,
                uc_level_interrupts  => false,
                n_pa_regs => n_pa_regs,
                pa_rmask  => pa_rmask,
                pa_wmask  => pa_wmask,
                with_dma  => wdma,
                with_pss  => wpss,
                with_uc   => false,
                neirq     => neirq)
    port map(clk      => clk,
             srstn    => srstn,
             ce       => ce,
             req2ctrl => req2ctrl,
             ctrl2rsp => ctrl2rsp,
             hirq     => hirq,
             uirq     => uirq,
             pirq     => pirq,
             dirq     => dirq,
             eirq     => eirq,
             dma2ctrl => dma2ctrl,
             ctrl2dma => ctrl2dma,
             uca2ctrl => uca2ctrl_none,
             ctrl2uca => open,
             uc2ctrl  => uc2ctrl_none,
             ctrl2uc  => open,
             pss2ctrl => pss2css,
             ctrl2pss => css2pss,
             param    => param);

    g_dma: if wdma generate
      dma: entity work.dma(rtl)
      generic map(n0 => n0,
                  n1 => n1)
      port map(clk      => clk,
               ctrl2dma => ctrl2dma,
               dma2ctrl => dma2ctrl_w,
               mss2dma  => mss2css.mss2dma,
               dma2mss  => dma2mss_w,
               axi_in   => iaxi_in,
               axi_out  => iaxi_out_w);
    end generate g_dma;
    dma2ctrl <= dma2ctrl_w when wdma else
                dma2ctrl_none;
    css2mss.dma2mss <= dma2mss_w when wdma else
                       dma2mss_none;
    iaxi_out <= iaxi_out_w when wdma else
                axi4lite_m2s_none;

end architecture rtl;
