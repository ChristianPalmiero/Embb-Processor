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

--* @id $Id: mss_responses_fifo.vhd 2017-05-01 cpalmiero $
--* @brief MSS outgoing responses FIFO.
--* @author Christian Palmiero (palmiero@eurecom.fr)
--* @date 2017-05-01
--*
--* MSS responses FIFO located between the internals of MSS and the host system. Up to DEPTH incoming responses are stored in the FIFO.
--* On the host system side, the first received and not yet transmitted response, if any, is output on RSP_OUT. 
--* When acknowledged (HST_BREADY or HST_RREADY input asserted), it is removed from the FIFO and the next response, if any, is output on RSP_OUT. 
--* The most important criteria for this design is the delay between internal registers and RSP_OUT. As a
--* consequence, RSP_OUT is directly wired to the first stage of the FIFO (RESPONSES(0)). The incoming responses are stored at the first available location
--* starting from this same stage. To avoid long combinatorial pathes, the ACK signal does not
--* depend on HST_BREADY or HST_RREADY.
--* 

library ieee;
use ieee.std_logic_1164.all;

library global_lib;
use global_lib.global.all;
use global_lib.utils.all;
use global_lib.axi4lite_pkg.all;

use work.css_pkg.all;

entity mss_responses_fifo is
  generic(depth: positive := 6);
  port(
    clk:        in  std_ulogic;                --* Master clock
    srstn:      in  std_ulogic;                --* Synchronous active low reset
    ce:         in  std_ulogic;                --* Chip enable
    mss2rsp:    in  axi4lite_response_type;    --* AXI4Lite incoming response from MSS
    hst_bready: in  std_ulogic;                --* AXI4Lite bready signal from host system
    hst_rready: in  std_ulogic;                --* AXI4Lite rready signal from host system
    mss_bready: out std_ulogic;                --* AXI4Lite bready signal to MSS
    mss_rready: out std_ulogic;                --* AXI4Lite rready signal to MSS
    rsp_out:    out axi4lite_response_type;    --* AXI4Lite outgoing response to host system
    ack:        out natural range 0 to depth); --* Number of free places in FIFO
end entity mss_responses_fifo;

architecture rtl of mss_responses_fifo is

  --* Responses FIFO; inputs at DEPTH - 1, output at 0
  signal responses: axi4lite_response_vector(0 to depth - 1);
  signal ack_local: natural range 0 to depth;
  signal rsp_in: axi4lite_response_type;
  signal rsp_in_local: axi4lite_response_type;
  signal mss_bready_local, mss_rready_local: std_ulogic;

begin

  process(clk)
    variable responsesv: axi4lite_response_vector(0 to depth - 1);
    variable valv: std_ulogic;
    variable ri, ro: boolean;
  begin
    if rising_edge(clk) then
      if srstn = '0' then
        for i in 0 to depth - 1 loop
          responsesv(i) := axi4lite_response_none;
        end loop;
        ack_local <= depth;
      elsif ce = '1' then
        responsesv := responses;
        valv       := rsp_in.w_resp.bvalid or rsp_in.r_data.rvalid;
        ri         := false;
        ro         := false;
        if (hst_bready = '1' and responsesv(0).w_resp.bvalid = '1') or
          (hst_rready = '1' and responsesv(0).r_data.rvalid = '1') then -- Current outgoing response acknowledged
          for i in 0 to depth - 2 loop -- Move FIFO ahead but not inactive places (to save power)
            if responsesv(i + 1).w_resp.bvalid = '1' or responsesv(i + 1).r_data.rvalid = '1' then
              responsesv(i) := responsesv(i + 1);
            end if;
            responsesv(i).w_resp.bvalid := responsesv(i + 1).w_resp.bvalid;
            responsesv(i).r_data.rvalid := responsesv(i + 1).r_data.rvalid;
          end loop;
          responsesv(depth - 1).w_resp.bvalid := '0';
          responsesv(depth - 1).r_data.rvalid := '0';
          ro := true;
        end if;
        for i in 0 to depth - 1 loop
          if valv = '1' and ack_local /= 0 and responsesv(i).w_resp.bvalid = '0' and responsesv(i).r_data.rvalid = '0' then -- Can accept incoming response
            responsesv(i)  := rsp_in; -- Store incoming response
            valv           := '0';    -- Clear incoming response
            ri             := true;
          end if;
        end loop;
        if ri and not ro then
          ack_local <= ack_local - 1;
        elsif not ri and ro then
          ack_local <= ack_local + 1;
        end if;
      end if;
      responses <= responsesv;
    end if;
  end process;
  
  --* Send responses to the responses FIFO
  process(mss2rsp, mss_bready, mss_rready)
  begin
    rsp_in_local <= axi4lite_response_none; -- By default do not send a response
    if (mss2rsp.w_resp.bvalid and mss_bready) or (mss2rsp.r_data.rvalid and mss_rready) then -- if there is an active request from MSS and there is an handshake
      rsp_in_local  <= mss2rsp;
    end if;
  end process;
  
  --* mss_rready and mss_bready are asserted if there is at least one free spot in the FIFO and the chip enable is asserted
  process(responses, ce)
    variable tmp: std_ulogic_vector(0 to depth - 1);
  begin
    for i in 0 to depth - 1 loop
      tmp(i) := responses(i).r_data.rvalid or responses(i).w_resp.bvalid;
    end loop;
    mss_bready_local <= (not and_reduce(tmp)) and ce;
    mss_rready_local <= (not and_reduce(tmp)) and ce;  
  end process;
  
  rsp_in  <= rsp_in_local;
  ack     <= ack_local;
  rsp_out <= responses(0);
  mss_bready <= mss_bready_local;
  mss_rready <= mss_rready_local;
  
end architecture rtl;
