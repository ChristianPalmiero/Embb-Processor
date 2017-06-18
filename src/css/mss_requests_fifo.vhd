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

--* @id $Id: mss_requests_fifo.vhd 2017-05-01 cpalmiero $
--* @brief MSS incoming requests FIFO.
--* @author Christian Palmiero (palmiero@eurecom.fr)
--* @date 2017-05-01
--*
--* MSS requests FIFO located between the host system and the MSS. Up to DEPTH incoming requests are stored in the FIFO. The
--* HST_AWREADY, HST_WREADY and HST_ARREADY sent back to the host system are asserted by default. They are de-asserted in the following scenarios:
--* 1) The FIFO is full -> All the three ready signals are de-asserted;
--* 2) The master is willing to perform a write operation but it does NOT provide at the same time both the HST_AWADDR and the HST_AWDATA -> 
--* If HST_AWVALID is equal to '1' and HST_WVALID is equal to '0', HST_AWREADY is de-asserted; if HST_WVALID is equal to '1' and HST_AWVALID is equal to '0', HST_WREADY is de-asserted.
--*
--* On the MSS side, the first received and not yet transmitted request, if any, is output on REQ2MSS. When acknowledged,
--* it is removed from the FIFO and the next request, if any, is output on REQ2MSS.
--*

library ieee;
use ieee.std_logic_1164.all;

library global_lib;
use global_lib.global.all;
use global_lib.utils.all;
use global_lib.axi4lite_pkg.all;

use work.css_pkg.all;

entity mss_requests_fifo is
  generic(rsp_depth: positive := 6;
  	  depth: positive := 3);
  port(
    clk:          in  std_ulogic;  --* Master clock
    srstn:        in  std_ulogic;  --* Synchronous active low reset
    ce:           in  std_ulogic;  --* Chip enable
    req_in:       in  axi4lite_request_type;  --* AXI4Lite incoming request from host system
    ack_rsp:      in  natural range 0 to rsp_depth;  --* Number of free places in MSS responses FIFO
    mss_awready:  in  std_ulogic;  --* AXI4Lite awready signal from MSS
    mss_wready:   in  std_ulogic;  --* AXI4Lite wready signal from MSS
    mss_arready:  in  std_ulogic;  --* AXI4Lite arready signal from MSS 
    req2mss:      out axi4lite_request_type;  --* AXI4Lite outgoing request to MSS
    hst_awready:  out std_ulogic;  --* AXI4Lite awready signal to host system
    hst_wready:   out std_ulogic;  --* AXI4Lite wready signal to host system
    hst_arready:  out std_ulogic); --* AXI4Lite arready signal to host system
end entity mss_requests_fifo;

architecture rtl of mss_requests_fifo is

  --* MSS requests FIFO; inputs at 0, outputs at DEPTH-1
  signal requests: axi4lite_request_vector(0 to depth-1);
  signal cmdack_local: std_ulogic;
  signal req_out: axi4lite_request_type;
  signal ack_local: std_ulogic;
  signal req2mss_local: axi4lite_request_type;
  signal req_cnt: natural range 0 to depth;

  --* Logarithmic, priority-based selector among a vector of requests. The rightmost request has the highest priority.
  function req_selector(r: axi4lite_request_vector) return axi4lite_request_type is
    constant n: natural := r'length;
    variable rv: axi4lite_request_vector(0 to n-1) := r;
    variable tmpr, tmpl, res: axi4lite_request_type;
  begin
    if n = 0 then      -- if no request...
      res := axi4lite_request_none; -- ...return default request (no request)
    elsif n = 1 then   -- else if one request...
      res := rv(0);    -- ...return that one
    else               -- else if two or more requests
      tmpl := req_selector(rv(0 to n / 2 - 1));         -- highest priority request from the left half
      tmpr := req_selector(rv(n / 2 to n - 1)); -- highest priority request from the right half
      if (is_w(tmpr) or is_r(tmpr)) then -- if request from right half is active...
        res := tmpr;            -- ...return that one
      else                      -- else...
        res := tmpl;            -- ...return the one from the left half
      end if;
    end if;
    return res;
  end function req_selector;

begin

  --* The FIFO of MSS requests. Incoming requests, if any, are always stored in the input place of the FIFO (REQUESTS(0)) if there is at least one free place in the
  --* FIFO. Active requests are always moved ahead from input to output if the next place is free. The current pending request, if any, is always the active
  --* request which place is the closest from the output.
  process(clk)
    variable requestsv: axi4lite_request_vector(0 to depth-1);
    variable ackv: std_ulogic;
    variable ri, ro: boolean;
    variable req_cntv: natural range 0 to depth;
  begin
    if rising_edge(clk) then
      if srstn = '0' then -- if reset active...
        for i in 0 to depth - 1 loop
          requestsv(i) := axi4lite_request_none; -- set all FIFO places to "no request"
        end loop;
        req_cntv := 0;
      elsif ce = '1' then -- reset inactive and chip enabled
        requestsv := requests;
        ackv      := ack_local;
        ri := false;
        ro := false;
        if ack_local = '1' and (is_r(req2mss) or is_w(req2mss)) then -- If there is a FIFO output
          ro := true;
        end if;
        for i in depth - 1 downto 0 loop -- for all FIFO places from output to input
          if ackv = '1' and (is_w(requestsv(i)) or is_r(requestsv(i))) then -- if pending active request acknowledged
            ackv                        := '0'; -- clear acknowledge flag
            requestsv(i).w_addr.awvalid := '0'; -- clear request flag
            requestsv(i).r_addr.arvalid := '0'; -- clear request flag
            requestsv(i).w_data.wvalid  := '0'; -- clear request flag            
          end if;
        end loop;
        -- shift FIFO ahead by one place whenever possible (but save power by not moving inactive requests)
        for i in depth - 1 downto 1 loop -- for all FIFO places from output to input, but the input place
          if (requestsv(i).w_addr.awvalid = '0' and requestsv(i).r_addr.arvalid = '0' and requestsv(i).w_data.wvalid = '0') and
            (is_w(requestsv(i-1)) or is_r(requestsv(i-1))) then -- if current place is empty and previous is active
            requestsv(i) := requestsv(i - 1);     -- shift request
            requestsv(i-1).w_addr.awvalid := '0'; -- clear request flag
            requestsv(i-1).r_addr.arvalid := '0'; -- clear request flag
            requestsv(i-1).w_data.wvalid := '0';  -- clear request flag 
          end if;
        end loop;
        -- If there is at least one free spot in the FIFO
        if cmdack_local = '1' then
          -- If the master is willing to perform BOTH a read and a write operation concurrently
          if (is_wr(req_in)) then
	    -- If all the ready signals are asserted
            if hst_awready and hst_arready and hst_wready then 
              requestsv(0) := req_in; -- store incoming request into the FIFO
              ri := true;
            end if;
          -- If the master is willing to perform a write operation
          elsif (is_w(req_in)) then
	    -- If the required ready signals are asserted
            if hst_awready and hst_wready then
              requestsv(0) := req_in;         -- store incoming write request into the FIFO
              ri := true;
            end if;
          -- If the master is willing to perform a read operation            
	  elsif (is_r(req_in)) then
	    -- If the required ready signal is asserted
	    if hst_arready then
              requestsv(0) := req_in;         -- store incoming read request into the FIFO          
              ri := true;
            end if;
          end if;
        end if;
        if ri and not(ro) then      -- One input, no output
          req_cntv := req_cntv + 1; 
        elsif (not ri) and ro then  -- No input, one output
          req_cntv := req_cntv - 1; 
        end if;
      end if;
      requests <= requestsv;
      req_cnt <= req_cntv;
    end if;
  end process;

  --* Cmdack_local is asserted if there is at least one free spot in the FIFO and the chip enable is asserted
  process(requests, ce)
    variable tmp: std_ulogic_vector(0 to depth - 1);
  begin
    for i in 0 to depth - 1 loop
      tmp(i) := is_w(requests(i)) or is_r(requests(i));
    end loop;
    cmdack_local <= (not and_reduce(tmp)) and ce;
  end process;

  --* If AWVALID is equal to '1' and WVALID is equal to '0', AWREADY is de-asserted; it is asserted again when both AWVALID and WALID are equal to '1' and there is one free spot in the FIFO
  hst_awready  <= (cmdack_local and not(req_in.w_addr.awvalid)) or (cmdack_local and req_in.w_data.wvalid and req_in.w_addr.awvalid);
  --* If there is one free spot in the FIFO, ARREADY is asserted
  hst_arready  <= cmdack_local;
  --* If WVALID is equal to '1' and AWVALID is equal to '0', WREADY is de-asserted; it is asserted again when both AWVALID and WALID are equal to '1' and there is one free spot in the FIFO 
  hst_wready  <= (cmdack_local and not(req_in.w_data.wvalid)) or (cmdack_local and req_in.w_data.wvalid and req_in.w_addr.awvalid);
  req_out <= req_selector(requests);
  
  --* Forward incoming request to MSS
  process(ack_local, req_out)
  begin
    req2mss_local <= axi4lite_request_none; -- By default do not request MSS
    if ack_local = '1' then -- If request is acknowledged
      -- Send read/write request to MSS
      req2mss_local <= req_out;
    end if;
  end process;
  req2mss <= req2mss_local;
  
  --* REQ_CNT is the number of AXI requests currently acknowledged by MSS and for which a response has not yet been stored in the MSS responses FIFO. ACK_RSP is the
  --* number of free places in MSS responses FIFO. Outgoing requests are acknowledged only if REQ_CNT < ACK_RSP, which guarantees that there is enough room in
  --* MSS responses FIFO to store the corresponding response.
  process(mss_awready, mss_wready, mss_arready, req_cnt, ack_rsp, req_out)
  begin
    ack_local <= '1'; -- By default, acknowledge requests from MSS
    if mss_arready = '0' and is_r(req_out) then -- No handshake (Read request)
      ack_local <= '0';
    elsif (mss_awready = '0' or mss_wready = '0') and is_w(req_out) then -- No handshake (Write request)
      ack_local <= '0';
    elsif (mss_awready = '0' or mss_wready = '0' or mss_arready = '0') and is_wr(req_out) then -- No handshake (Both Read and Write request)
      ack_local <= '0';
    end if;
    if req_cnt >= ack_rsp then -- Never more active requests than free places in responses FIFO
      ack_local <= '0';
    end if;
  end process;
  
end architecture rtl;
