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

--* @id $Id: responses_fifo.vhd 4180 2012-07-27 12:08:32Z rpacalet $
--* @brief Outgoing responses FIFO.
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2011-05-25
--*
--* Responses FIFO located between the internals of CSS and the host system. Up to DEPTH incoming responses are stored in the FIFO.
--* On the host system side, the first received and not yet transmitted response, if any, is output on RSP_OUT. 
--* When acknowledged (BREADY or RREADY input asserted), it is removed from the FIFO and the next response, if any, is output on RSP_OUT. 
--* The most important criteria for this design is the delay between internal registers and RSP_OUT. As a
--* consequence, RSP_OUT is directly wired to the first stage of the FIFO (RESPONSES(0)). The incoming responses are stored at the first available location
--* starting from this same stage. To avoid long combinatorial pathes, the ACK signal does not
--* depend on BREADY or RREADY.
--* 
--* Changes log
--* - 2011-07-19 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--* - removed use of vciinterface_pkg
--* - 2017-03-01 by Christian Palmiero (palmiero@eurecom.fr): 
--* - responses_fifo has been redesigned (from VCI to AXI4Lite)

library ieee;
use ieee.std_logic_1164.all;

library global_lib;
use global_lib.global.all;
use global_lib.utils.all;
use global_lib.axi4lite_pkg.all;

use work.css_pkg.all;

entity responses_fifo is
  generic(depth: positive := 6);
  port(
    clk:      in  std_ulogic;    --* Master clock
    srstn:    in  std_ulogic;    --* Synchronous active low reset
    ce:       in  std_ulogic;    --* Chip enable
    ctrl2rsp: in  ctrl2rsp_type; --* Inputs from CTRL
    en:	      in  std_ulogic;    --* Enable from requests FIFO
    rnw:      in  std_ulogic;    --* ReadNotWrite from requests FIFO
    err:      in  std_ulogic;    --* Error from requests FIFO
    bready:   in  std_ulogic;                --* AXI4Lite bready signal
    rready:   in  std_ulogic;                --* AXI4Lite rready signal
    rsp_out:  out axi4lite_response_type;    --* AXI4Lite outgoing response (to host system)
    ack:      out natural range 0 to depth); --* Number of free places in FIFO
end entity responses_fifo;

architecture rtl of responses_fifo is

  --* Responses FIFO; inputs at DEPTH - 1, output at 0
  signal responses: axi4lite_FIFO_response_vector(0 to depth - 1);
  signal ack_local: natural range 0 to depth;
  signal rsp_in: axi4lite_FIFO_response_type;
  signal rsp_in_local: axi4lite_FIFO_response_type;

begin

  process(clk)
    variable responsesv: axi4lite_FIFO_response_vector(0 to depth - 1);
    variable valv: std_ulogic;
    variable ri, ro: boolean;
  begin
    if rising_edge(clk) then
      if srstn = '0' then
        for i in 0 to depth - 1 loop
          responsesv(i) := axi4lite_FIFO_response_none;
        end loop;
        ack_local <= depth;
      elsif ce = '1' then
        responsesv := responses;
        valv       := rsp_in.bvalid or rsp_in.rvalid or err;
        ri         := false;
        ro         := false;
        if (bready = '1' and responsesv(0).bvalid = '1') or
          (rready = '1' and responsesv(0).rvalid = '1') then -- Current outgoing response acknowledged
          for i in 0 to depth - 2 loop -- Move FIFO ahead but not inactive places (to save power)
            if responsesv(i + 1).bvalid = '1' or responsesv(i + 1).rvalid = '1' then
              responsesv(i) := responsesv(i + 1);
            end if;
            responsesv(i).bvalid := responsesv(i + 1).bvalid;
            responsesv(i).rvalid := responsesv(i + 1).rvalid;
          end loop;
          responsesv(depth - 1).bvalid := '0';
          responsesv(depth - 1).rvalid := '0';
          ro := true;
        end if;
        for i in 0 to depth - 1 loop
          if valv = '1' and ack_local /= 0 and responsesv(i).bvalid = '0' and responsesv(i).rvalid = '0' then -- Can accept incoming response
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
  process(ctrl2rsp, en, rnw, err)
  begin
    rsp_in_local <= axi4lite_FIFO_response_none; -- By default do not send a response
    if en = '1' then -- if there is an active request to CTRL (response in the same clock cycle)
      if rnw = '1' then
        rsp_in_local.rvalid   <= ctrl2rsp.ack;
        rsp_in_local.rdata    <= ctrl2rsp.rdata;
        rsp_in_local.resp(1)  <= ctrl2rsp.oor;
        rsp_in_local.resp(0)  <= '0';
        rsp_in_local.bvalid   <= '0';
      else
        rsp_in_local.bvalid   <= ctrl2rsp.ack;
        rsp_in_local.rdata    <= (others => '0');
        rsp_in_local.resp(1)  <= ctrl2rsp.oor;
        rsp_in_local.resp(0)  <= '0';
        rsp_in_local.rvalid   <= '0';
      end if;
    elsif err = '1' then -- if there is an erroneous request to CTRL (store the erroneous response in the same clock cycle)
      if rnw = '1' then 
	rsp_in_local.bvalid   <= '0';
        rsp_in_local.rdata    <= (others => '0');
        rsp_in_local.resp     <= "10";
        rsp_in_local.rvalid   <= '1';
      else
	rsp_in_local.bvalid   <= '1';
        rsp_in_local.rdata    <= (others => '0');
        rsp_in_local.resp     <= "10";
        rsp_in_local.rvalid   <= '0';
      end if;
    end if;
  end process;
  
  rsp_in  <= rsp_in_local;
  ack     <= ack_local;
  rsp_out <= FIFO_to_rsp(responses(0));

end architecture rtl;
