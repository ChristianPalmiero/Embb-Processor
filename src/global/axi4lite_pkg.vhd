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

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library random_lib;
use random_lib.rnd.all;

package axi4lite_pkg is

  -----------------------------------------------------------------------------------------------------
  -- AXI4Lite types and constants
  -----------------------------------------------------------------------------------------------------
  constant axi4lite_addr:   positive := 32; -- bit width of address bus
  constant axi4lite_data:   positive := 8;  -- byte width of data buses (64 bits)
  constant log2_axi4lite_b: natural  := 3;  -- log base 2 of axi4lite_data
  constant axi4lite_strb:   positive := 8;  -- bit width of WSRTB
  constant axi4lite_resp:   positive := 2;  -- bit width of xRESP
  
  subtype axi4lite_addr_type is std_ulogic_vector(axi4lite_addr - 1 downto 0);
  subtype axi4lite_data_type is std_ulogic_vector(8 * axi4lite_data - 1 downto 0);
  subtype axi4lite_strb_type is std_ulogic_vector(axi4lite_strb - 1 downto 0);

  -- AXI4Lite Response type
  subtype axi4lite_resp_type is std_ulogic_vector(axi4lite_resp - 1 downto 0);

  constant axi4lite_resp_okay:       axi4lite_resp_type := "00";  -- AXI Okay, normal access
  constant axi4lite_resp_exokay:     axi4lite_resp_type := "01";  -- AXI Exokay, exclusive access
  constant axi4lite_resp_slverr:     axi4lite_resp_type := "10";  -- AXI Slverr, slave error
  constant axi4lite_resp_decerr:     axi4lite_resp_type := "11";  -- AXI Decerr, decode error

  -- AXI4Lite Write address channel
  type axi4lite_write_addr_type is record
    awaddr   : axi4lite_addr_type;    -- Write address
    awvalid  : std_ulogic;	      -- Write address valid
  end record;

  constant axi4lite_write_addr_none: axi4lite_write_addr_type := (
    awaddr  => (others => '0'),
    awvalid => '0');
  type axi4lite_write_addr_vector is array(natural range <>) of axi4lite_write_addr_type;

  -- AXI4Lite Write data channel
  type axi4lite_write_data_type is record
    wdata    : axi4lite_data_type;	 -- Write data
    wstrb    : axi4lite_strb_type;	 -- Write strobes
    wvalid   : std_ulogic;	         -- Write data valid
  end record;

  constant axi4lite_write_data_none: axi4lite_write_data_type := (
    wdata   => (others => '0'),
    wstrb   => (others => '0'),
    wvalid  => '0');
  type axi4lite_write_data_vector is array(natural range <>) of axi4lite_write_data_type;

  -- AXI4 Write response channel
  type axi4lite_write_response_type is record
    bresp    : axi4lite_resp_type;	 -- Write response
    bvalid   : std_ulogic;	         -- Write response valid
  end record;

  constant axi4lite_write_response_none: axi4lite_write_response_type := (
    bresp   => (others => '0'),
    bvalid  => '0');
  type axi4lite_write_response_vector is array(natural range <>) of axi4lite_write_response_type;

  -- AXI4Lite Read address channel
  type axi4lite_read_addr_type is record
    araddr   : axi4lite_addr_type;    -- Read address
    arvalid  : std_ulogic;	      -- Read address valid
  end record;

  constant axi4lite_read_addr_none: axi4lite_read_addr_type := (
    araddr  => (others => '0'),
    arvalid => '0');
  type axi4lite_read_addr_vector is array(natural range <>) of axi4lite_read_addr_type;  
  
  -- AXI4Lite Read data channel
  type axi4lite_read_data_type is record
    rdata    : axi4lite_data_type;	 -- Read data
    rresp    : axi4lite_resp_type;       -- Read response
    rvalid   : std_ulogic;	         -- Read data valid
  end record;  

  constant axi4lite_read_data_none: axi4lite_read_data_type := (
    rdata   => (others => '0'),
    rresp   => (others => '0'),
    rvalid  => '0');
  type axi4lite_read_data_vector is array(natural range <>) of axi4lite_read_data_type;

  -- AXI4Lite request
  type axi4lite_request_type is record
    w_addr: axi4lite_write_addr_type;
    r_addr: axi4lite_read_addr_type;
    w_data: axi4lite_write_data_type;
  end record;

  constant axi4lite_request_none: axi4lite_request_type := (w_addr => axi4lite_write_addr_none, r_addr => axi4lite_read_addr_none, w_data => axi4lite_write_data_none);
  type axi4lite_request_vector is array(natural range <>) of axi4lite_request_type;
  
  -- AXI4Lite request stored into the requests FIFO
  type axi4lite_FIFO_request_type is record    
    addr   : axi4lite_addr_type;    -- Shared Read/Write address
    awvalid  : std_ulogic;	    -- Write address valid
    arvalid  : std_ulogic;	    -- Read address valid
    w_data: axi4lite_write_data_type;
  end record;

  constant axi4lite_FIFO_request_none: axi4lite_FIFO_request_type := (addr => (others => '0'), awvalid => '0', arvalid => '0', w_data => axi4lite_write_data_none);
  type axi4lite_FIFO_request_vector is array(natural range <>) of axi4lite_FIFO_request_type; 
  
  -- AXI4Lite master to slave
  type axi4lite_m2s_type is record
    axi4lite_request: axi4lite_request_type;
    bready: std_ulogic;
    rready: std_ulogic;
  end record;

  constant axi4lite_m2s_none: axi4lite_m2s_type := (axi4lite_request => axi4lite_request_none, bready => '0', rready => '0');
  type axi4lite_m2s_vector is array(natural range <>) of axi4lite_m2s_type;

  -- AXI4Lite response
  type axi4lite_response_type is record
    r_data: axi4lite_read_data_type;
    w_resp: axi4lite_write_response_type;
  end record;

  constant axi4lite_response_none: axi4lite_response_type := (r_data => axi4lite_read_data_none, w_resp => axi4lite_write_response_none);
  type axi4lite_response_vector is array(natural range <>) of axi4lite_response_type;
  
  -- AXI4Lite response stored into the response FIFO
  type axi4lite_FIFO_response_type is record    
    bvalid  : std_ulogic;	      -- Write response valid
    rvalid  : std_ulogic;	      -- Read data valid
    rdata   : axi4lite_data_type;     -- Read data
    resp    : axi4lite_resp_type;     -- Shared Read/Write response
  end record;

  constant axi4lite_FIFO_response_none: axi4lite_FIFO_response_type := (bvalid => '0', rvalid => '0', rdata => (others => '0'), resp => (others => '0'));
  type axi4lite_FIFO_response_vector is array(natural range <>) of axi4lite_FIFO_response_type;
  
  -- AXI4Lite slave to master
  type axi4lite_s2m_type is record
    axi4lite_response: axi4lite_response_type;
    awready: std_ulogic;
    wready: std_ulogic;
    arready: std_ulogic;
  end record;

  constant axi4lite_s2m_none: axi4lite_s2m_type := (axi4lite_response => axi4lite_response_none, awready => '0', wready => '0', arready => '0');
  type axi4lite_s2m_vector is array(natural range <>) of axi4lite_s2m_type;
  
  function read_to_FIFO(req_in: axi4lite_request_type) return axi4lite_FIFO_request_type;
  function write_to_FIFO(req_in: axi4lite_request_type) return axi4lite_FIFO_request_type;
  function read_to_BUFFER(req_in: axi4lite_request_type) return axi4lite_FIFO_request_type;
  function FIFO_to_rsp(req_in: axi4lite_FIFO_response_type) return axi4lite_response_type;
  impure function axi4lite_addr_rnd return axi4lite_addr_type;
  impure function axi4lite_strb_rnd return axi4lite_strb_type;
  impure function axi4lite_resp_rnd return axi4lite_resp_type;
  impure function axi4lite_data_rnd return axi4lite_data_type;
  impure function axi4lite_write_addr_rnd return axi4lite_write_addr_type;
  impure function axi4lite_write_data_rnd return axi4lite_write_data_type;
  impure function axi4lite_write_response_rnd return axi4lite_write_response_type;
  impure function axi4lite_read_addr_rnd return axi4lite_read_addr_type;
  impure function axi4lite_read_data_rnd return axi4lite_read_data_type;
  impure function axi4lite_request_rnd return axi4lite_request_type;
  impure function axi4lite_response_rnd return axi4lite_response_type;
  impure function axi4lite_m2s_rnd return axi4lite_m2s_type;
  impure function axi4lite_s2m_rnd return axi4lite_s2m_type;
  
end package axi4lite_pkg;

package body axi4lite_pkg is

  -- This function implements the procedure for storing a READ AXI4Lite request coming from the host system into the requests FIFO
  -- The AWADDR/ARADDR signals of the AXI4Lite protocol are shared and are stored into the ADDR variable of the requests FIFO
  function read_to_FIFO(req_in: axi4lite_request_type) return axi4lite_FIFO_request_type is
    variable res: axi4lite_FIFO_request_type;
  begin
    res.addr := req_in.r_addr.araddr;
    res.awvalid := '0'; 
    res.arvalid := '1';
    res.w_data := axi4lite_write_data_none;
    return res;
  end function read_to_FIFO;
  
  -- This function implements the procedure for storing a WRITE AXI4Lite request coming from the host system into the requests FIFO
  -- The AWADDR/ARADDR signals of the AXI4Lite protocol are shared and are stored into the ADDR variable of the requests FIFO
  function write_to_FIFO(req_in: axi4lite_request_type) return axi4lite_FIFO_request_type is
    variable res: axi4lite_FIFO_request_type;
  begin
    res.addr := req_in.w_addr.awaddr;
    res.awvalid := '1';
    res.arvalid := '0';
    res.w_data := req_in.w_data;
    return res;
  end function write_to_FIFO;
  
  -- This function implements the procedure for storing a READ AXI4Lite request coming from the host system into the requests FIFO internal buffer
  function read_to_BUFFER(req_in: axi4lite_request_type) return axi4lite_FIFO_request_type is
    variable res: axi4lite_FIFO_request_type;
  begin
    res.addr := req_in.r_addr.araddr;
    res.awvalid := '0';
    res.arvalid := '1';
    res.w_data := axi4lite_write_data_none;
    return res;
  end function read_to_BUFFER;
  
  -- This function implements the procedure for storing an AXI4Lite request coming from the responses FIFO into the host system
  -- The WRESP/RRESP signals of the AXI4Lite protocol are shared and are stored into the RESP variable of the responses FIFO  
  function FIFO_to_rsp(req_in: axi4lite_FIFO_response_type) return axi4lite_response_type is
    variable res: axi4lite_response_type;
  begin
    if req_in.bvalid = '1' and req_in.rvalid = '0' then
      res.w_resp.bresp := req_in.resp;
      res.w_resp.bvalid := req_in.bvalid;
      res.r_data.rvalid := '0';
      res.r_data.rdata := (others => '0');
      res.r_data.rresp := (others => '0');
    elsif req_in.rvalid = '1' and req_in.bvalid = '0' then
      res.w_resp.bresp := req_in.resp;
      res.w_resp.bvalid := req_in.rvalid;
      res.r_data.rdata := req_in.rdata;
      res.r_data.rvalid := '0';
      res.r_data.rresp := (others => '0');
    else
      res.w_resp.bresp := (others => '0');
      res.w_resp.bvalid := '0';
      res.r_data.rdata := (others => '0');
      res.r_data.rvalid := '0';
      res.r_data.rresp := (others => '0');
    end if;
    return res;
  end function FIFO_to_rsp;
  
  impure function axi4lite_addr_rnd return axi4lite_addr_type is
    variable res: axi4lite_addr_type;
  begin
    res := std_ulogic_vector_rnd(axi4lite_addr_type'length);
    return res;
  end function axi4lite_addr_rnd;
  
  impure function axi4lite_strb_rnd return axi4lite_strb_type is
    variable res: axi4lite_strb_type;
  begin
    res := std_ulogic_vector_rnd(axi4lite_strb_type'length);
    return res;
  end function axi4lite_strb_rnd;

  impure function axi4lite_resp_rnd return axi4lite_resp_type is
    variable res: axi4lite_resp_type;
  begin
    res := std_ulogic_vector_rnd(axi4lite_resp_type'length);
    return res;
  end function axi4lite_resp_rnd;  
  
  impure function axi4lite_data_rnd return axi4lite_data_type is
    variable res: axi4lite_data_type;
  begin
    res := std_ulogic_vector_rnd(axi4lite_data_type'length);
    return res;
  end function axi4lite_data_rnd;  
  
  impure function axi4lite_write_addr_rnd return axi4lite_write_addr_type is
    variable res: axi4lite_write_addr_type;
  begin
    res.awaddr := axi4lite_addr_rnd;
    res.awvalid := std_ulogic_rnd;
    return res;
  end function axi4lite_write_addr_rnd;
  
  impure function axi4lite_write_data_rnd return axi4lite_write_data_type is
    variable res: axi4lite_write_data_type;
  begin
    res.wdata := axi4lite_data_rnd;
    res.wstrb := axi4lite_strb_rnd;
    res.wvalid := std_ulogic_rnd;
    return res;
  end function axi4lite_write_data_rnd;
  
  impure function axi4lite_write_response_rnd return axi4lite_write_response_type is
    variable res: axi4lite_write_response_type;
  begin
    res.bresp := axi4lite_resp_rnd;
    res.bvalid := std_ulogic_rnd;
    return res;
  end function axi4lite_write_response_rnd;
  
  impure function axi4lite_read_addr_rnd return axi4lite_read_addr_type is
    variable res: axi4lite_read_addr_type;
  begin
    res.araddr := axi4lite_addr_rnd;
    res.arvalid := std_ulogic_rnd;
    return res;
  end function axi4lite_read_addr_rnd;       
    
  impure function axi4lite_read_data_rnd return axi4lite_read_data_type is
    variable res: axi4lite_read_data_type;
  begin
    res.rdata := axi4lite_data_rnd;
    res.rresp := axi4lite_resp_rnd;
    res.rvalid := std_ulogic_rnd;
    return res;
  end function axi4lite_read_data_rnd;  
  
  impure function axi4lite_request_rnd return axi4lite_request_type is
     variable res: axi4lite_request_type;
  begin
    res.w_addr := axi4lite_write_addr_rnd;
    res.r_addr := axi4lite_read_addr_rnd;
    res.w_data := axi4lite_write_data_rnd;
    return res;
  end function axi4lite_request_rnd; 
  
  impure function axi4lite_response_rnd return axi4lite_response_type is
     variable res: axi4lite_response_type;
  begin
    res.w_resp := axi4lite_write_response_rnd;
    res.r_data := axi4lite_read_data_rnd;
    return res;
  end function axi4lite_response_rnd;       
  
  impure function axi4lite_m2s_rnd return axi4lite_m2s_type is
     variable res: axi4lite_m2s_type;
  begin
    res.axi4lite_request := axi4lite_request_rnd;
    res.bready := std_ulogic_rnd;
    res.rready := std_ulogic_rnd;
    return res;  
  end function axi4lite_m2s_rnd;
  
  impure function axi4lite_s2m_rnd return axi4lite_s2m_type is
     variable res: axi4lite_s2m_type;
  begin
    res.axi4lite_response := axi4lite_response_rnd;
    res.awready := std_ulogic_rnd;
    res.wready := std_ulogic_rnd;
    res.arready := std_ulogic_rnd;
    return res;  
  end function axi4lite_s2m_rnd;  
  
end package body axi4lite_pkg;
