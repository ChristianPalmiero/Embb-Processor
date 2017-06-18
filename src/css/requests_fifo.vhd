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

--* @id $Id: requests_fifo.vhd 4180 2012-07-27 12:08:32Z rpacalet $
--* @brief Incoming requests FIFO.
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2011-05-25
--*
--* Requests FIFO located between the host system and the internals of CSS. Up to DEPTH incoming requests are stored in the FIFO. The
--* AWREADY, WREADY and ARREADY signals sent back to the host system are asserted by default. They are de-asserted in the following scenarios:
--* 1) The FIFO is full -> All the three ready signals are de-asserted;
--* 2) The master is willing to perform a write operation but it does NOT provide at the same time both the AWADDR and the AWDATA -> 
--* If AWVALID is equal to '1' and WVALID is equal to '0', AWREADY is de-asserted; if WVALID is equal to '1' and AWVALID is equal to '0', WREADY is de-asserted;
--* 3) The master is willing to perform both a read and a write operation simultaneously but there is only one free spot in the FIFO -> 
--* The write request is stored into the FIFO free spot, the read request is stored into a buffer and All the three ready signals are de-asserted until the buffer is empty and there is at least one free spot in the FIFO.
--* On the local DSP unit side, the first received and not yet transmitted request, if any, is output on REQ2CTRL. When acknowledged,
--* it is removed from the FIFO and the next request, if any, is output on REQ2CTRL.
--*
--* Changes log
--* 
--* 2013-09-10 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): bug fix: cmdack was asserted while ce was deasserted
--* 2017-03-01 by Christian Palmiero (palmiero@eurecom.fr): requests_fifo has been redesigned (from VCI to AXI4Lite)

library ieee;
use ieee.std_logic_1164.all;

library global_lib;
use global_lib.global.all;
use global_lib.utils.all;
use global_lib.axi4lite_pkg.all;

use work.css_pkg.all;

entity requests_fifo is
  generic(rsp_depth: positive := 6;
  	  depth: positive := 3);
  port(
    clk:      in  std_ulogic;  --* Master clock
    srstn:    in  std_ulogic;  --* Synchronous active low reset
    ce:       in  std_ulogic;  --* Chip enable
    req_in:   in  axi4lite_request_type;  --* AXI4Lite incoming request (from host system)
    ack_rsp:  in  natural range 0 to rsp_depth;  --* Number of free places in responses FIFO
    ack:      in  std_ulogic;  --* Acknowledge from CTRL
    req2ctrl: out req2ctrl_type; --* Outputs to CTRL
    err:      out std_ulogic;  --* Signal to responses FIFO
    awready:  out std_ulogic;  --* AXI4Lite awready signal
    wready:   out std_ulogic;  --* AXI4Lite wready signal
    arready:  out std_ulogic); --* AXI4Lite arready signal
end entity requests_fifo;

architecture rtl of requests_fifo is

  --* Requests FIFO; inputs at 0, outputs at DEPTH-1
  signal requests: axi4lite_FIFO_request_vector(0 to depth-1);
  signal cmdack_local: std_ulogic;
  signal req_out, internal_buffer: axi4lite_FIFO_request_type;
  signal ack_local, busy: std_ulogic;
  signal req2ctrl_local: req2ctrl_type;
  signal req_cnt: natural range 0 to depth;

  --* Logarithmic, priority-based selector among a vector of requests. The rightmost request has the highest priority.
  function req_selector(r: axi4lite_FIFO_request_vector) return axi4lite_FIFO_request_type is
    constant n: natural := r'length;
    variable rv: axi4lite_FIFO_request_vector(0 to n-1) := r;
    variable tmpr, tmpl, res: axi4lite_FIFO_request_type;
  begin
    if n = 0 then      -- if no request...
      res := axi4lite_FIFO_request_none; -- ...return default request (no request)
    elsif n = 1 then   -- else if one request...
      res := rv(0);    -- ...return that one
    else               -- else if two or more requests
      tmpl := req_selector(rv(0 to n / 2 - 1));         -- highest priority request from the left half
      tmpr := req_selector(rv(n / 2 to n - 1)); -- highest priority request from the right half
      if ((tmpr.awvalid = '1' and tmpr.w_data.wvalid = '1') or tmpr.arvalid = '1') then -- if request from right half is active...
        res := tmpr;            -- ...return that one
      else                      -- else...
        res := tmpl;            -- ...return the one from the left half
      end if;
    end if;
    return res;
  end function req_selector;

begin

  --* The FIFO of requests. Incoming requests, if any, are always stored in the input place of the FIFO (REQUESTS(0)) if there is at least one free place in the
  --* FIFO. Active requests are always moved ahead from input to output if the next place is free. The current pending request, if any, is always the active
  --* request which place is the closest from the output.
  process(clk)
    variable requestsv: axi4lite_FIFO_request_vector(0 to depth-1);
    variable ackv, busyv: std_ulogic;
    variable ri, ro, rd: boolean;
    variable req_cntv: natural range 0 to depth;
    variable internal_bufferv: axi4lite_FIFO_request_type;
  begin
    if rising_edge(clk) then
      if srstn = '0' then -- if reset active...
        for i in 0 to depth - 1 loop
          requestsv(i) := axi4lite_FIFO_request_none; -- set all FIFO places to "no request"
        end loop;
        internal_bufferv := axi4lite_FIFO_request_none;
        busyv := '0';
        req_cntv := 0;
      elsif ce = '1' then -- reset inactive and chip enabled
        requestsv := requests;
        ackv      := ack_local;
        busyv     := busy;
        internal_bufferv := internal_buffer;
        ri := false;
        rd := false;
        ro := false;
        if ack_local = '1' and (req2ctrl.en = '1' or err = '1') then -- If there is a FIFO output
          ro := true;
        end if;
        for i in depth - 1 downto 0 loop -- for all FIFO places from output to input
          if ackv = '1' and ((requestsv(i).awvalid = '1' and requestsv(i).w_data.wvalid = '1') or requestsv(i).arvalid = '1') then -- if pending active request acknowledged
            ackv                 := '0'; -- clear acknowledge flag
            requestsv(i).awvalid := '0'; -- clear request flag
            requestsv(i).arvalid := '0'; -- clear request flag
            requestsv(i).w_data.wvalid := '0'; -- clear request flag            
          end if;
        end loop;
        -- shift FIFO ahead by one place whenever possible (but save power by not moving inactive requests)
        for i in depth - 1 downto 1 loop -- for all FIFO places from output to input, but the input place
          if (requestsv(i).awvalid = '0' and requestsv(i).arvalid = '0' and requestsv(i).w_data.wvalid = '0') and
            ((requestsv(i-1).awvalid = '1' and requestsv(i-1).w_data.wvalid = '1') or requestsv(i-1).arvalid = '1') then -- if current place is empty and previous is active
            requestsv(i) := requestsv(i - 1); -- shift request
            requestsv(i-1).awvalid := '0'; -- clear request flag
            requestsv(i-1).arvalid := '0'; -- clear request flag
            requestsv(i-1).w_data.wvalid := '0'; -- clear request flag 
          end if;
        end loop;
        -- move BUFFER into the FIFO whenever possible
        if (requestsv(0).awvalid = '0' and requestsv(0).arvalid = '0' and requestsv(0).w_data.wvalid = '0') and busyv = '1' then
          requestsv(0) := internal_bufferv;
          busyv := '0';
          ri := true;
        end if;
        -- If there is at least one free spot in the FIFO
        if cmdack_local = '1' then
          -- If the master is willing to perform BOTH a read and a write operation concurrently
          if (is_wr(req_in)) then
	    -- If all the ready signals are asserted
            if awready and arready and wready then 
	      -- If there are two free spots in the requests FIFO, store both requests into the FIFO (Priority: write wins over read)
              if (requestsv(1).awvalid = '0' and requestsv(1).arvalid = '0' and requestsv(1).w_data.wvalid = '0') then
		requestsv(1) := write_to_FIFO(req_in);       -- store incoming write request into the FIFO
                requestsv(0) := read_to_FIFO(req_in);        -- store incoming read request into the FIFO
                ri := true;
                rd := true;
	      -- Else store the write request into the FIFO, the read request into the BUFFER
	      else            
                requestsv(0) := write_to_FIFO(req_in);       -- store incoming write request into the FIFO
                internal_bufferv := read_to_BUFFER(req_in);  -- store incoming read request into the BUFFER
                busyv := '1';
                ri := true;
              end if;
            end if;
          -- If the master is willing to perform a write operation
          elsif (is_w(req_in)) then
	    -- If the required ready signals are asserted
            if awready and wready then
              requestsv(0) := write_to_FIFO(req_in);         -- store incoming write request into the FIFO
              ri := true;
            end if;
          -- If the master is willing to perform a read operation            
	  elsif (is_r(req_in)) then
	    -- If the required ready signal is asserted
	    if arready then
              requestsv(0) := read_to_FIFO(req_in);          -- store incoming read request into the FIFO          
              ri := true;
            end if;
          end if;
        end if;
        if ri and rd and (not ro) then         -- Two inputs, no output
	  req_cntv := req_cntv + 2;
	elsif ri and rd and ro then            -- Two inputs, one output
          req_cntv := req_cntv + 1;      
        elsif ri and not(rd) and not(ro) then  -- One input, no output
          req_cntv := req_cntv + 1; 
        elsif (not ri) and ro then             -- No input, one output
          req_cntv := req_cntv - 1; 
        end if;
      end if;
      requests <= requestsv;
      internal_buffer <= internal_bufferv;
      busy <= busyv;
      req_cnt <= req_cntv;
    end if;
  end process;

  -- Cmdack_local is asserted if there is at least one free spot in the FIFO and the chip enable is asserted
  process(requests, ce)
    variable tmp: std_ulogic_vector(0 to depth - 1);
  begin
    for i in 0 to depth - 1 loop
      tmp(i) := (requests(i).awvalid and requests(i).w_data.wvalid) or requests(i).arvalid;
    end loop;
    cmdack_local <= (not and_reduce(tmp)) and ce;
  end process;

  -- If AWVALID is equal to '1' and WVALID is equal to '0', AWREADY is de-asserted; it is asserted again when both AWVALID and WALID are equal to '1', there is one free spot in the FIFO and the buffer is empty
  awready  <= (cmdack_local and not(busy) and not(req_in.w_addr.awvalid)) or (cmdack_local and not(busy) and req_in.w_data.wvalid and req_in.w_addr.awvalid);
  -- If there is one free spot in the FIFO and the buffer is empty, ARREADY is asserted
  arready  <= cmdack_local and not(busy);
  -- If WVALID is equal to '1' and AWVALID is equal to '0', WREADY is de-asserted; it is asserted again when both AWVALID and WALID are equal to '1', there is one free spot in the FIFO and the buffer is empty 
  wready  <= (cmdack_local and not(busy) and not(req_in.w_data.wvalid)) or (cmdack_local and not(busy) and req_in.w_data.wvalid and req_in.w_addr.awvalid);
  req_out <= req_selector(requests);
  
  --* Forward incoming request to CTRL
  process(ack_local, req_out)
  begin
    err <= '0';
    req2ctrl_local <= req2ctrl_none; -- By default do not request CTRL
    if is_reg_req(req_out) and ack_local = '1' then -- If request is acknowledged
      -- Send read/write request to CTRL
      if req_out.awvalid = '1' then
        req2ctrl_local.en <= '1';
        req2ctrl_local.rnw <= '0';
        req2ctrl_local.be  <= req_out.w_data.wstrb;
        req2ctrl_local.add <= hst_add2idx(req_out.addr);
        req2ctrl_local.wdata <= req_out.w_data.wdata;
      elsif req_out.arvalid = '1' then
        req2ctrl_local.en <= '1';
        req2ctrl_local.rnw <= '1';
        req2ctrl_local.add <= hst_add2idx(req_out.addr);
      end if;
    elsif is_reg_err(req_out) then
      err <= '1';
      if req_out.awvalid = '1' then
        req2ctrl_local.en <= '0';
        req2ctrl_local.rnw <= '0';
        req2ctrl_local.be  <= req_out.w_data.wstrb;
        req2ctrl_local.add <= hst_add2idx(req_out.addr);
        req2ctrl_local.wdata <= req_out.w_data.wdata;
      elsif req_out.arvalid = '1' then
        req2ctrl_local.en <= '0';
        req2ctrl_local.rnw <= '1';
        req2ctrl_local.add <= hst_add2idx(req_out.addr);
      end if;
    end if;
  end process;
  req2ctrl <= req2ctrl_local;
  
  --* REQ_CNT is the number of AXI requests currently acknowledged by CSS and for which a response has not yet been stored in the responses FIFO. ACK_RSP is the
  --* number of free places in responses FIFO. Outgoing requests are acknowledged only if REQ_CNT < ACK_RSP, which guarantees that there is enough room in
  --* responses FIFO to store the corresponding response.
  process(ack, req_cnt, ack_rsp, req_out)
  begin
    ack_local <= '1'; -- By default, acknowledge requests from CTRL
    if ack = '0' and is_reg_req(req_out) then
      ack_local <= '0';
    end if;
    if req_cnt >= ack_rsp then -- Never more active requests than free places in responses FIFO
      ack_local <= '0';
    end if;
  end process;
  
end architecture rtl;
