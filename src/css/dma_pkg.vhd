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

--* @id $Id: dma_pkg.vhd 5289 2013-07-31 10:40:52Z cerdan $
--* @brief DMA package definition
--* @author Sebastien Cerdan (sebastien.cerdan@telecom-paristech.fr)
--* @date 2011-07-26

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library global_lib;
use global_lib.global.all;
use global_lib.axi4lite_pkg.all;

use work.css_pkg.all;

package dma_pkg is

  constant rsp_address_width : natural := 3;
  constant req_address_width : natural := 1;

  constant req_depth : natural := 2**req_address_width;
  constant rsp_depth : natural := 2**rsp_address_width;

  type state_t is (idle, run);

  type req_type is record
    eor   : std_ulogic;
    run   : std_ulogic;
    eop   : std_ulogic;
    one   : std_ulogic;
    first : std_ulogic;
    last  : std_ulogic;
    be    : std_ulogic_vector(axi4lite_data - 1 downto 0);
    fbe   : std_ulogic_vector(axi4lite_data - 1 downto 0);
    lbe   : std_ulogic_vector(axi4lite_data - 1 downto 0);
    addr  : u_unsigned(axi4lite_addr - 1 downto 0);
    cnt   : u_unsigned(15 downto 0);
    fcnt  : u_unsigned(rsp_address_width downto 0);
  end record;

  constant req_none : req_type := (
    eor   => '0',
    eop   => '0',
    one   => '0',
    run   => '0',
    first => '0',
    last  => '0',
    addr  => (others => '0'),
    be    => (others => '0'),
    fbe   => (others => '0'),
    lbe   => (others => '0'),
    cnt   => (others => '0'),
    fcnt  => (others => '0'));

  type rsp_type is record
    cnt   : u_unsigned(15 downto 0);
  end record;

  constant rsp_none : rsp_type := (
    cnt   => (others => '0'));

  type shift_in_type is record
    eor   : std_ulogic;
    eop   : std_ulogic;
    start : std_ulogic;
    value : u_unsigned(15 downto 0);
    dst	  : std_ulogic_vector(2 downto 0);
    src   : std_ulogic_vector(2 downto 0);
    ack   : std_ulogic;
    ds    : std_ulogic;
    din	  : std_ulogic_vector(63 downto 0); 
  end record;
  
  constant shift_in_none: shift_in_type := ( 
    eor   => '0',
    eop   => '0',
    start => '0',
    value => (others => '0'),
    dst	  => (others => '0'),
    src   => (others => '0'),
    ack   => '0',
    ds    => '0',
    din	  => (others => '0')); 

  type shift_out_type is record
    eop   : std_ulogic;
    ds    : std_ulogic;
    dout  : std_ulogic_vector(63 downto 0); 
  end record;

  type stagea_t is record
    en  : std_ulogic;    
    rnw : std_ulogic;    
    gnt : std_ulogic_vector(axi4lite_data - 1 downto 0);    
    ack : std_ulogic;
  end record;

  constant stagea_none : stagea_t := (
    en => '0',
    rnw => '0',
    gnt => (others => '0'),
    ack => '0');
  
  type stagea_v is array(natural range <>) of stagea_t ;

  type fifo_req_in is record
    enr : std_ulogic;
    enw : std_ulogic;
    din : std_ulogic_vector(8*axi4lite_data-1 + 1 downto 0);
  end record;

  type fifo_req_out is record
    full : std_ulogic;
    empty : std_ulogic;
    dout : std_ulogic_vector(8*axi4lite_data-1 + 1 downto 0);
  end record;

  type fifo_rsp_in is record
    enr : std_ulogic;
    enw : std_ulogic;
    din : std_ulogic_vector(8*axi4lite_data-1 + 2 downto 0);
  end record;

  type fifo_rsp_out is record
    full : std_ulogic;
    empty : std_ulogic;
    dout : std_ulogic_vector(8*axi4lite_data-1 + 2 downto 0);
  end record;

  type ack_type is record
    rreq : std_ulogic;
    wreq : std_ulogic;
    rrsp : std_ulogic;
    wrsp : std_ulogic;
    ridle : std_ulogic;
    widle : std_ulogic;
  end record;

  -- Provide a byte enabled mask according to address
  function set_be(address:in std_ulogic_vector(2 downto 0);
		    -- input address		   
		   complement:in std_ulogic)
		    -- take complement of resulting be when last word transferred 
		   return std_ulogic_vector;

  function set_value(value, dst : in std_ulogic_vector) return std_ulogic_vector; 
  -- Select the correct byte enable
  function mux_be(one, first, last: std_ulogic; mbe, fbe, lbe: std_ulogic_vector) return std_ulogic_vector;
  -- Set end of packet flag
  function is_eop(one, last: std_ulogic) return std_ulogic; 
  -- Initialise read/write request variables
  function init_req(addr, lenm1: std_ulogic_vector; cnt: u_unsigned; run : std_ulogic) return req_type;
  -- Initialise read/write response variables
  function init_rsp(cnt: u_unsigned) return rsp_type;
  -- Mux R/W command either on AXI or MSS
  procedure mux_req(r: in req_type; signal axi: out axi4lite_request_type; signal mss: out dma2mss_type; rnw, local: in std_ulogic); 
  function get_cnt(addr, lenm1: std_ulogic_vector) return u_unsigned;

  type b_out_t is record
      msscmd : dma2mss_type;
      vci_i2t : vci_i2t_type;
      eor : std_ulogic;
      eot : std_ulogic;
      status : status_type;
      err : std_ulogic;
      ack :std_ulogic;
      data : std_ulogic_vector(63 downto 0);
  end record;
 
  type b_in_t is record
      srstn : std_ulogic;
      ce : std_ulogic; 
      vciin: vci_t2i_type;
      mssin: mss2dma_type;
      cmdack : std_ulogic;
      start : std_ulogic;
      data : std_ulogic_vector(63 downto 0);
      rvalue : u_unsigned(15 downto 0);
      wvalue : u_unsigned(15 downto 0);
      en : std_ulogic;
      ctrl : ctrl2dma_type;
  end record;

end package dma_pkg;

package body dma_pkg is

  function mux_be(one, first, last: std_ulogic; mbe, fbe, lbe: std_ulogic_vector) return std_ulogic_vector is 
    variable be : std_ulogic_vector(axi4lite_data - 1 downto 0);
    begin
      if one = '1' then   
      -- one word write operation
        be := fbe and lbe;
      elsif first = '1' then   
      -- first word written
        be := fbe;
      elsif last = '1' then 
      -- last word written
        be := lbe;
      else
        be := X"FF";
      end if;
 
      return std_ulogic_vector(u_unsigned(mbe) and u_unsigned(be));

  end function mux_be;
    
  function is_eop(one, last: std_ulogic) return std_ulogic is 
    variable eop : std_ulogic;
    begin
      eop := '0';
      if one = '1' then   
      -- one word write operation
        eop := '1';
      elsif last = '1' then 
      -- last word written
        eop := '1';
      end if;

      return eop;
  end function is_eop;

  function set_be(address:in std_ulogic_vector(2 downto 0);
		  complement:in std_ulogic) return std_ulogic_vector is 
    variable be_v : std_ulogic_vector(7 downto 0);
    begin
	    if address = "000" then
	    be_v := X"FF";
	  elsif address = "001" then
	    be_v := X"7F";
	  elsif address = "010" then
	    be_v := X"3F";
	  elsif address = "011" then
	    be_v := X"1F";
	  elsif address = "100" then
	    be_v := X"0F";
	  elsif address = "101" then
	    be_v := X"07";
	  elsif address = "110" then
	    be_v := X"03";
	  elsif address = "111" then
	    be_v := X"01";
	  end if;
	  if complement = '1' and address /= "000" then return not be_v; else return  be_v; end if;
  end set_be;

  function set_value(value, dst : in std_ulogic_vector) return std_ulogic_vector is 
    begin
      return std_ulogic_vector(shift_right(u_unsigned(value), to_integer(u_unsigned(dst)) * axi4lite_data) or shift_left(u_unsigned(value), (axi4lite_data - to_integer(u_unsigned(dst))) * axi4lite_data));
  end set_value;
  
  function get_cnt(addr, lenm1: std_ulogic_vector) return u_unsigned is
    variable v : u_unsigned(18 downto 0);
    begin
        v  := shift_right(u_unsigned(addr(18 downto 0)) + u_unsigned(lenm1(18 downto 0)), log2_axi4lite_b);
        return resize(v - shift_right(u_unsigned(addr(18 downto 0)), log2_axi4lite_b), axi4lite_addr/2);
  end get_cnt;

  function init_rsp(cnt: u_unsigned) return rsp_type is
    variable v : rsp_type;
    begin
       v := rsp_none;
       v.cnt := cnt;
       return v;
  end init_rsp;

  function init_req(addr, lenm1: std_ulogic_vector; cnt: u_unsigned; run : std_ulogic) return req_type is
    variable v : req_type;
    begin 
       v := req_none;
       
       v.run := run;
       v.cnt := cnt;
       v.first := '1';
       v.addr := shift_right(u_unsigned(addr), log2_axi4lite_b);
       v.fbe := set_be(addr(2 downto 0), '0');
       v.lbe := set_be(std_ulogic_vector(u_unsigned(addr(2 downto 0)) + u_unsigned(lenm1) + 1), '1');
       if cnt = 0 then 
         v.one := '1';
       end if;
       return v; 
  end init_req;
  
  procedure mux_req(r: in req_type; signal axi: out axi4lite_request_type; signal mss: out dma2mss_type; rnw, local: in std_ulogic) is 
    begin
      if local = '1' then
        -- MSS
        mss.en  <= r.run;
        mss.add <= std_ulogic_vector(r.addr(axi4lite_addr - log2_axi4lite_b - 1 downto 0));
        mss.rnw <= rnw;
        mss.be  <= r.be;
      else 
        -- AXI
        if rnw = '1' then
          axi.r_addr.arvalid <= r.run;
          axi.r_addr.araddr  <= std_ulogic_vector(shift_left(r.addr, log2_axi4lite_b));
        else
          axi.w_addr.awvalid <= r.run;
          axi.w_addr.awaddr  <= std_ulogic_vector(shift_left(r.addr, log2_axi4lite_b));    
          axi.w_data.wvalid  <= r.run;
          axi.w_data.wstrb   <= r.be;
        end if;
      end if; 
  end mux_req;
end package body dma_pkg;
