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

--* @id $Id: global.vhd 5204 2013-07-16 13:21:03Z rpacalet $
--* @brief Global package. Used everywhere in the project.
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2008-06-02
--*
--* 
--* The global package defines:
--* - The constants vci_xxx (parameters of the VCI interfaces)
--* - The record types of the interfaces between the components of the DU shell
--*   (VCIInterface, DMA, UC, MSS and PSS)
--* - The record types of the interfaces between the DU shell and the host system
--*   (target and initiator AVCI)
--*
--* Changes log
--*
--* - 2008-06-10 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added byte enables to the vci2mss_type and dma2mss_type definitions
--*
--* - 2010-07-30 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added css2pss_type and pss2css_type types definitions. simplified xxx2mss_type equivalent definitions. added xxx2mss_nop constants.
--*
--* - 2010-09-08 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added vci_i2t_t, vci_t2i_t types and corresponding vector types.
--*
--* - 2011-05-22 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added word128.
--*
--* - 2011-08-01 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - Changed pss2vci_status type (29 bits), renamed it pss2css_status. Added pss2css_type.
--*
--* - 2011-08-02 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - mss2dma.gnt and mss2vci.gnt are now 8 bits wide (one bit per byte) to allow partial read/write requests completion and multi-cycles request completion
--*
--*     in case of conflicts.
--*
--*   - nop => none
--*
--*   - types rework
--*
--* - 2011-08-04 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - Added status_none constant.
--*
--* - 2011-08-09 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - types rework
--*
--* - 2011-08-30 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added constants
--*
--* - 2011-09-01 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - moved utils.boolean_array definition to global.boolean_vector
--*
--* - 2011-09-26 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - Added target types constants
--*
--* - 2011-10-03 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - Added kintex7 target

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package global is

-- pragma translate_off
  type shared_boolean is protected
    impure function get return boolean;
    procedure set_true;
    procedure set_false;
    procedure flip;
  end protected shared_boolean;
-- pragma translate_on
    
  attribute ram_block: boolean;

  subtype word4 is std_ulogic_vector(3 downto 0);   -- half byte
  subtype word8 is std_ulogic_vector(7 downto 0);   -- byte
  subtype word11 is std_ulogic_vector(10 downto 0); -- 11 bits word
  subtype word12 is std_ulogic_vector(11 downto 0); -- 11 bits word
  subtype word14 is std_ulogic_vector(13 downto 0); -- 14 bits word
  subtype word16 is std_ulogic_vector(15 downto 0); -- half word
  subtype word18 is std_ulogic_vector(17 downto 0); -- 18 bits half word
  subtype word24 is std_ulogic_vector(23 downto 0); -- 24 bits word
  subtype word28 is std_ulogic_vector(27 downto 0); -- 28 bits word
  subtype word32 is std_ulogic_vector(31 downto 0); -- word
  subtype word54 is std_ulogic_vector(53 downto 0); -- 54 bits word
  subtype word64 is std_ulogic_vector(63 downto 0); -- double word
  subtype word128 is std_ulogic_vector(127 downto 0); -- quad word

  type word4_vector is array(natural range <>) of word4;
  type word8_vector is array(natural range <>) of word8;
  type word11_vector is array(natural range <>) of word11;
  type word12_vector is array(natural range <>) of word12;
  type word14_vector is array(natural range <>) of word14;
  type word16_vector is array(natural range <>) of word16;
  type word18_vector is array(natural range <>) of word18;
  type word24_vector is array(natural range <>) of word24;
  type word28_vector is array(natural range <>) of word28;
  type word32_vector is array(natural range <>) of word32;
  type word54_vector is array(natural range <>) of word54;
  type word64_vector is array(natural range <>) of word64;
  type word128_vector is array(natural range <>) of word128;

  subtype word16_address_type is std_ulogic_vector(30 downto 0);
  subtype word16_be_type is std_ulogic_vector(1 downto 0);
  subtype word32_address_type is std_ulogic_vector(29 downto 0);
  subtype word32_be_type is std_ulogic_vector(3 downto 0);
  subtype word64_address_type is std_ulogic_vector(28 downto 0);
  subtype word64_be_type is std_ulogic_vector(7 downto 0);

  constant word16_address_none: word16_address_type := (others => '0');
  constant word16_be_none: word16_be_type := (others => '0');
  constant word32_address_none: word32_address_type := (others => '0');
  constant word32_be_none: word32_be_type := (others => '0');
  constant word64_address_none: word64_address_type := (others => '0');
  constant word64_be_none: word64_be_type := (others => '0');

  -----------------------------------------------------------------------------------------------------
  -- VCI types and constants
  -----------------------------------------------------------------------------------------------------
  constant vci_n:      positive := 32; -- bit width of address bus
  constant vci_b:      positive := 8;  -- byte width of data buses (64 bits)
  constant log2_vci_b: natural  := 3;  -- log base 2 of vci_b
  constant vci_s:      positive := 6;  -- bit width of source id
  constant vci_t:      positive := 6;  -- bit width of thread id
  constant vci_p:      positive := 4;  -- bit width of packet id
  constant vci_e:      positive := 4;  -- bit width - 1 of error reponse


  subtype vci_address_type is std_ulogic_vector(vci_n - 1 downto 0);
  subtype vci_data_type is std_ulogic_vector(8 * vci_b - 1 downto 0);
  subtype vci_be_type is std_ulogic_vector(vci_b - 1 downto 0);
  subtype vci_srcid_type is std_ulogic_vector(vci_s - 1 downto 0);
  subtype vci_trdid_type is std_ulogic_vector(vci_t - 1 downto 0);
  subtype vci_pktid_type is std_ulogic_vector(vci_p - 1 downto 0);

  -- VCI Command type
  subtype vci_cmd_type is std_ulogic_vector(1 downto 0);

  constant vci_cmd_nop:      vci_cmd_type := "00";  -- VCI No operation
  constant vci_cmd_read:     vci_cmd_type := "01";  -- VCI Read
  constant vci_cmd_write:    vci_cmd_type := "10";  -- VCI Write
  constant vci_cmd_lockread: vci_cmd_type := "11";  -- VCI Lockread

  -- VCI Error type
  subtype vci_error_type is std_ulogic_vector(vci_e downto 0);

  constant vci_noerr:    vci_error_type := "00000";    -- No error
  constant vci_noperr:   vci_error_type := "00001";    -- No information
  constant vci_tssncerr: vci_error_type := "01001";    -- Transaction supported and serviced, but not completed
  constant vci_tsnserr:  vci_error_type := "00101";    -- Transaction supported, but not serviced, retry later
  constant vci_tnserr:   vci_error_type := "00011";    -- Transaction not supported and not serviced
  constant vci_tnsderr:  vci_error_type := "01011";    -- Transaction not supoprted and degraded
  constant vci_faterr:   vci_error_type := "00111";    -- Fatal error

  -- Advanced VCI request
  type vci_request_type is record
    cmdval  : std_ulogic;       -- command valid
    address : vci_address_type; -- address bus
    be      : vci_be_type;      -- byte enable
    eop     : std_ulogic;       -- end of packet
    cmd     : vci_cmd_type;     -- command
    wdata   : vci_data_type;    -- write data
    srcid   : vci_srcid_type;   -- source id
    trdid   : vci_trdid_type;   -- thread id
    pktid   : vci_pktid_type;   -- packet id
  end record;

  constant vci_request_none: vci_request_type := (
    cmdval  => '0',
    address => (others => '0'),
    be      => (others => '0'),
    cmd     => (others => '0'),
    wdata   => (others => '0'),
    srcid   => (others => '0'),
    trdid   => (others => '0'),
    pktid   => (others => '0'),
    eop     => '0');

  type vci_request_vector is array(natural range <>) of vci_request_type;

  -- Advanced VCI response
  type vci_response_type is record
    rspval: std_ulogic;  -- response valid
    rdata:  vci_data_type;  -- read data
    rerror: vci_error_type; -- response error
    reop:   std_ulogic;  -- response end of packet
    rsrcid: vci_srcid_type; -- response source id
    rtrdid: vci_trdid_type; -- response thread id
    rpktid: vci_pktid_type; -- response packet id
  end record;

  constant vci_response_none: vci_response_type := (
    rspval => '0',
    rdata  => (others => '0'),
    rerror => (others => '0'),
    reop   => '0',
    rsrcid => (others => '0'),
    rtrdid => (others => '0'),
    rpktid => (others => '0'));
  type vci_response_vector is array(natural range <>) of vci_response_type;

  type vci_i2t_type is record
    req: vci_request_type;
    rspack: std_ulogic;
  end record;

  constant vci_i2t_none: vci_i2t_type := (req => vci_request_none, rspack => '0');
  type vci_i2t_vector is array(natural range <>) of vci_i2t_type;

  type vci_t2i_type is record
    rsp: vci_response_type;
    cmdack: std_ulogic;
  end record;

  constant vci_t2i_none: vci_t2i_type := (rsp => vci_response_none, cmdack => '0');
  type vci_t2i_vector is array(natural range <>) of vci_t2i_type;

  constant vci_response_lenght:  positive := vci_b * 8 + vci_s + vci_p + vci_t + vci_e + 1 + 1 + 1;
  constant vci_request_lenght :  positive := vci_b * 8 + vci_s + vci_p + vci_t + vci_n + vci_b + 1 + 1 + 2;

  function vci_rsp_to_vector(rsp: vci_response_type) return std_ulogic_vector;

  function vector_to_vci_rsp(v : std_ulogic_vector) return vci_response_type;

  function vci_req_to_vector(req: vci_request_type) return std_ulogic_vector;

  function vector_to_vci_req(v : std_ulogic_vector) return vci_request_type;

  -----------------------------------------------------------------------------------------------------
  -- Standard interfaces
  -----------------------------------------------------------------------------------------------------
  subtype status_type is std_ulogic_vector(23 downto 0);
  constant status_none: status_type := (others => '0');

  subtype data_type is std_ulogic_vector(31 downto 0);
  constant data_none: data_type := (others => '0');

  subtype eirq_type is word32;
  constant eirq_none: eirq_type := (others => '0');

  type pss2css_type is record
    eoc:    std_ulogic;  -- end of computation
    err:    std_ulogic;  -- error flag
    status: status_type; -- status info
    data:   data_type;   -- read data
    eirq:   eirq_type;   -- extended interrupts
  end record;

  constant pss2css_none: pss2css_type := (eoc => '0', err => '0', status => status_none, data => data_none, eirq => eirq_none);

  type css2pss_type is record
    srstn: std_ulogic; -- synchronous active low reset
    ce:    std_ulogic; -- chip enable
    exec:  std_ulogic; -- exec flag (launch execution)
  end record;
  constant css2pss_none: css2pss_type := (srstn => '0', ce => '0', exec => '0');

  type dma2mss_type is record
    en:    std_ulogic;          -- enable
    rnw:   std_ulogic;          -- read not write
    be:    word64_be_type;      -- byte enable
    add:   word64_address_type; -- address bus
    wdata: word64;              -- write data
  end record;
  constant dma2mss_none: dma2mss_type := (en => '0', rnw => '1', be => (others => '0'), add => (others => '0'), wdata => (others => '0'));

  type mss2dma_type is record
    oor:   std_ulogic;     -- out of range access flag
    gnt:   word64_be_type; -- grant (one bit per byte)
    be:    word64_be_type; -- byte enable (one bit per valid byte on rdata), curently unused
    rdata: word64;         -- read data
    en:    std_ulogic;     -- valid rdata, curently unused
  end record;
  constant mss2dma_none: mss2dma_type := (oor => '0', gnt => (others => '0'), be => (others => '0'), rdata => (others => '0'), en => '0');
  subtype mss2vci_type is mss2dma_type;
  constant mss2vci_none: mss2vci_type := mss2dma_none;

  subtype uc_address_type is word16;
  subtype uc_data_type is word64;
  type uc2mss_type is record
    en:    std_ulogic;      -- enable
    rnw:   std_ulogic;      -- read not write
    be:    word64_be_type;      -- byte enable
    add:   uc_address_type; -- address bus
    wdata: uc_data_type;    -- write data
  end record;
  constant uc2mss_none: uc2mss_type := (en => '0', rnw => '1', be => (others => '0'), add => (others => '0'), wdata => (others => '0'));

  type mss2uc_type is record
    oor:   std_ulogic; -- out of range access flag
    gnt:   word64_be_type; -- grant (one bit per byte)
    be:    word64_be_type; -- byte enable (one bit per valid byte on rdata)
    rdata: uc_data_type; -- read data
  end record;
  constant mss2uc_none: mss2uc_type := (oor => '0', gnt => (others => '0'), be => (others => '0'), rdata => (others => '0'));

  type css2mss_type is record
    dma2mss: dma2mss_type;
    req2mss: axi4lite_m2s_type;
  end record;

  type mss2css_type is record
    mss2dma: mss2dma_type;
    mss2rsp: axi4lite_s2m_type;
  end record;
  constant mss2css_none: mss2css_type := (mss2vci => mss2dma_none, mss2dma => mss2dma_none, mss2uc => mss2uc_none);

  -- DSP request
  type dsp_request_type is record 
    cmdval  : std_ulogic;
    rnw     : std_ulogic;
    address : std_ulogic_vector(30 downto 0);
    size    : std_ulogic_vector(1 downto 0);
    wdata   : std_ulogic_vector(31 downto 0);
  end record;

  constant dsp_request_none: dsp_request_type := (
    cmdval  => '0',
    rnw     => '0',
    address => (others => '0'),
    size    => (others => '0'),
    wdata   => (others => '0'));

  type dsp_i2t_type is record
    req: dsp_request_type;
    rspack: std_ulogic;
  end record;

  constant dsp_i2t_none: dsp_i2t_type := (req => dsp_request_none, rspack => '0');         

  -- DSP response
  type dsp_response_type is record
    rspval: std_ulogic;
    rdata:  std_ulogic_vector(31 downto 0);
  end record;

  constant dsp_response_none: dsp_response_type := (
    rspval => '0',
    rdata  => (others => '0'));

  type dsp_t2i_type is record
    rsp: dsp_response_type;
    cmdack: std_ulogic;
    irq : std_ulogic;
  end record;

  constant dsp_t2i_none: dsp_t2i_type := (rsp => dsp_response_none, cmdack => '0', irq => '0');

  -- micro-controller's vector addresses
  constant vect_nmi1:   std_ulogic_vector := X"fffa"; -- non-maskable interrupt address 1
  constant vect_nmi2:   std_ulogic_vector := X"fffb"; --      "        "         "      2
  constant vect_reset1: std_ulogic_vector := X"fffc"; -- reset address 1
  constant vect_reset2: std_ulogic_vector := X"fffd"; --      "        2
  constant vect_irq1:   std_ulogic_vector := X"fffe"; -- interrupt address 1
  constant vect_irq2:   std_ulogic_vector := X"ffff"; --      "        "   2

  attribute logic_block: boolean;

end package global;

package body global is

-- pragma translate_off
  type shared_boolean is protected body
    variable b: boolean := false;
    impure function get return boolean is
    begin
      return b;
    end function get;
    procedure set_true is
    begin
      b := true;
    end procedure set_true;
    procedure set_false is
    begin
      b := false;
    end procedure set_false;
    procedure flip is
    begin
      b := not b;
    end procedure flip;
  end protected body shared_boolean;
-- pragma translate_on

  function vci_req_to_vector(req: vci_request_type) return std_ulogic_vector is
    begin
      return req.srcid & req.trdid & req.pktid & req.address & req.wdata & req.be & req.cmd & req.eop & req.cmdval ;
  end vci_req_to_vector;

  function vector_to_vci_req(v : std_ulogic_vector) return vci_request_type is

    variable req : vci_request_type;
    variable tmp : natural;

    begin

      req.cmdval := v(0);
      tmp := 1;
      req.eop := v(tmp);
      tmp := 2;
      req.cmd := v(tmp + 1 downto tmp);
      tmp := tmp + 2;
      req.be := v(tmp + vci_b - 1 downto tmp);
      tmp := tmp + vci_b;
      req.wdata := v(tmp + vci_b * 8 - 1 downto tmp);
      tmp := tmp + vci_b * 8;
      req.address := v(tmp + vci_n - 1 downto tmp);
      tmp := tmp + vci_n;
      req.pktid := v(tmp + vci_p - 1 downto tmp);
      tmp := tmp + vci_p;
      req.trdid := v(tmp + vci_t - 1 downto tmp);
      tmp := tmp + vci_t;
      req.srcid := v(tmp + vci_s - 1 downto tmp);
     
      return req;

  end vector_to_vci_req;

  function vci_rsp_to_vector(rsp: vci_response_type) return std_ulogic_vector is
    begin
      return rsp.rsrcid & rsp.rtrdid & rsp.rpktid & rsp.rerror & rsp.rdata & rsp.reop & rsp.rspval ;
  end vci_rsp_to_vector;

  function vector_to_vci_rsp(v : std_ulogic_vector) return vci_response_type is

    variable rsp : vci_response_type;
    variable tmp : natural;

    begin

      rsp.rspval := v(0);
      tmp := 1;
      rsp.reop := v(1);
      tmp := 2;
      rsp.rdata := v(tmp + vci_b * 8 - 1 downto tmp);
      tmp := tmp + vci_b * 8;
      rsp.rerror := v(tmp + vci_e downto tmp);
      tmp := tmp + vci_e + 1;
      rsp.rpktid := v(tmp + vci_p - 1 downto tmp);
      tmp := tmp + vci_p;
      rsp.rtrdid := v(tmp + vci_t - 1 downto tmp);
      tmp := tmp + vci_t;
      rsp.rsrcid := v(tmp + vci_s - 1 downto tmp);
     
      return rsp;

  end vector_to_vci_rsp;

end package body global;
