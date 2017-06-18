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

--* @id $Id: css_pkg.vhd 5044 2013-06-14 10:27:18Z rpacalet $
--* @brief Utility package.
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2011-07-19
--*
--* Changes log
--* - 2011-08-04 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added _none constants.
--* - 2011-08-08 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added register addresses constants
--* - 2011-08-10 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added utility functions and replaced constants by function calls
--* - 2011-08-30 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Fixed an annoying warning with idx2hst_add
--*   - Added printing procedures for debugging
--* - 2011-09-31 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Fixed an annoying warning with idx2uc_add
--* - 2012-03-15 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added eos_off and tty_off definitions
--* - 2012-09-27 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added USIG signalling register.
--* - 2012-10-16 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added extended interrupts.
--* - 2017-03-01 by Christian Palmiero (palmiero@eurecom.fr):
--*   - Added some functions for the new CSS design with the AXI4Lite protocol

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library random_lib;
use random_lib.rnd.all;

library global_lib;
use global_lib.global.all;
-- pragma translate_off
use global_lib.sim_utils.all;
use global_lib.axi4lite_pkg.all;
-- pragma translate_on

library css_lib;
use css_lib.bitfield.all;

package css_pkg is

  subtype regs_type is word64_vector(0 to 31);
  function "and"(r, l: regs_type) return regs_type;
  function "or"(r, l: regs_type) return regs_type;

  type field_def_type is record
    idx: natural range 0 to 31;
    msb: natural range 0 to 63;
    lsb: natural range 0 to 63;
  end record;

  constant   dcfg_idx: natural range 0 to 31 := 16; --* Index of DMA configuration register
  constant   dcst_idx: natural range 0 to 31 := 17; --* Index of DMA constant register
  constant   dadd_idx: natural range 0 to 31 := 18; --* Index of DMA addresses register
  constant  dgost_idx: natural range 0 to 31 := 19; --* Index of DMA start / status register
  constant  pgost_idx: natural range 0 to 31 := 20; --* Index of PSS start / status register
  constant   ctrl_idx: natural range 0 to 31 := 21; --* Index of control register
  constant    irq_idx: natural range 0 to 31 := 22; --* Index of IRQ register
  constant  uregs_idx: natural range 0 to 31 := 23; --* Index of UC internal registers
  constant uprphs_idx: natural range 0 to 31 := 30; --* Index of UC periperals interface register
  constant uvects_idx: natural range 0 to 31 := 31; --* Index of UC vectors register

  constant dls_field_def:    field_def_type := (idx => dcfg_idx,   msb =>   0 mod 64, lsb =>   0 mod 64);
  constant dld_field_def:    field_def_type := (idx => dcfg_idx,   msb =>   1 mod 64, lsb =>   1 mod 64);
  constant dfs_field_def:    field_def_type := (idx => dcfg_idx,   msb =>   2 mod 64, lsb =>   2 mod 64);
  constant dfd_field_def:    field_def_type := (idx => dcfg_idx,   msb =>   3 mod 64, lsb =>   3 mod 64);
  constant dcs_field_def:    field_def_type := (idx => dcfg_idx,   msb =>   4 mod 64, lsb =>   4 mod 64);
  constant dbe_field_def:    field_def_type := (idx => dcfg_idx,   msb =>  15 mod 64, lsb =>   8 mod 64);
  constant dlenm1_field_def: field_def_type := (idx => dcfg_idx,   msb =>  63 mod 64, lsb =>  32 mod 64);
  constant dcstl_field_def:  field_def_type := (idx => dcst_idx,   msb => 95  mod 64, lsb =>  64 mod 64);
  constant dcsth_field_def:  field_def_type := (idx => dcst_idx,   msb => 127 mod 64, lsb =>  96 mod 64);
  constant dsrc_field_def:   field_def_type := (idx => dadd_idx,   msb => 159 mod 64, lsb => 128 mod 64);
  constant ddst_field_def:   field_def_type := (idx => dadd_idx,   msb => 191 mod 64, lsb => 160 mod 64);
  constant dst_field_def:    field_def_type := (idx => dgost_idx,  msb => 215 mod 64, lsb => 192 mod 64);
  constant dgo_field_def:    field_def_type := (idx => dgost_idx,  msb => 199 mod 64, lsb => 192 mod 64); -- LSByte of dgost
  constant derr_field_def:   field_def_type := (idx => dgost_idx,  msb => 216 mod 64, lsb => 216 mod 64);
  constant dval_field_def:   field_def_type := (idx => dgost_idx,  msb => 217 mod 64, lsb => 217 mod 64);
  constant pst_field_def:    field_def_type := (idx => pgost_idx,  msb => 279 mod 64, lsb => 256 mod 64);
  constant pgo_field_def:    field_def_type := (idx => pgost_idx,  msb => 263 mod 64, lsb => 256 mod 64); -- LSByte of pgost
  constant perr_field_def:   field_def_type := (idx => pgost_idx,  msb => 280 mod 64, lsb => 280 mod 64);
  constant pval_field_def:   field_def_type := (idx => pgost_idx,  msb => 281 mod 64, lsb => 281 mod 64);
  constant pdata_field_def:  field_def_type := (idx => pgost_idx,  msb => 319 mod 64, lsb => 288 mod 64);
  constant urst_field_def:   field_def_type := (idx => ctrl_idx,   msb => 320 mod 64, lsb => 320 mod 64);
  constant prst_field_def:   field_def_type := (idx => ctrl_idx,   msb => 321 mod 64, lsb => 321 mod 64);
  constant drst_field_def:   field_def_type := (idx => ctrl_idx,   msb => 322 mod 64, lsb => 322 mod 64);
  constant uce_field_def:    field_def_type := (idx => ctrl_idx,   msb => 323 mod 64, lsb => 323 mod 64);
  constant pce_field_def:    field_def_type := (idx => ctrl_idx,   msb => 324 mod 64, lsb => 324 mod 64);
  constant dce_field_def:    field_def_type := (idx => ctrl_idx,   msb => 325 mod 64, lsb => 325 mod 64);
  constant udbg_field_def:   field_def_type := (idx => ctrl_idx,   msb => 326 mod 64, lsb => 326 mod 64);
  constant u2hie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 328 mod 64, lsb => 328 mod 64);
  constant p2hie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 329 mod 64, lsb => 329 mod 64);
  constant d2hie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 330 mod 64, lsb => 330 mod 64);
  constant e2hie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 331 mod 64, lsb => 331 mod 64);
  constant hie_field_def:    field_def_type := (idx => ctrl_idx,   msb => 332 mod 64, lsb => 332 mod 64);
  constant p2uie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 336 mod 64, lsb => 336 mod 64);
  constant d2uie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 337 mod 64, lsb => 337 mod 64);
  constant h2uie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 338 mod 64, lsb => 338 mod 64);
  constant e2uie_field_def:  field_def_type := (idx => ctrl_idx,   msb => 339 mod 64, lsb => 339 mod 64);
  constant uie_field_def:    field_def_type := (idx => ctrl_idx,   msb => 340 mod 64, lsb => 340 mod 64);
  constant lhirq_field_def:  field_def_type := (idx => ctrl_idx,   msb => 344 mod 64, lsb => 344 mod 64);
  constant luirq_field_def:  field_def_type := (idx => ctrl_idx,   msb => 345 mod 64, lsb => 345 mod 64);
  constant leirq_field_def:  field_def_type := (idx => ctrl_idx,   msb => 346 mod 64, lsb => 346 mod 64);
  constant eie_field_def:    field_def_type := (idx => ctrl_idx,   msb => 383 mod 64, lsb => 352 mod 64);
  constant u2hirq_field_def: field_def_type := (idx => irq_idx,    msb => 384 mod 64, lsb => 384 mod 64);
  constant p2hirq_field_def: field_def_type := (idx => irq_idx,    msb => 385 mod 64, lsb => 385 mod 64);
  constant d2hirq_field_def: field_def_type := (idx => irq_idx,    msb => 386 mod 64, lsb => 386 mod 64);
  constant hirq_field_def:   field_def_type := (idx => irq_idx,    msb => 386 mod 64, lsb => 384 mod 64);
  constant dbsy_field_def:   field_def_type := (idx => irq_idx,    msb => 388 mod 64, lsb => 388 mod 64);
  constant drqp_field_def:   field_def_type := (idx => irq_idx,    msb => 389 mod 64, lsb => 389 mod 64);
  constant p2uirq_field_def: field_def_type := (idx => irq_idx,    msb => 392 mod 64, lsb => 392 mod 64);
  constant d2uirq_field_def: field_def_type := (idx => irq_idx,    msb => 393 mod 64, lsb => 393 mod 64);
  constant h2uirq_field_def: field_def_type := (idx => irq_idx,    msb => 394 mod 64, lsb => 394 mod 64);
  constant uirq_field_def:   field_def_type := (idx => irq_idx,    msb => 394 mod 64, lsb => 392 mod 64);
  constant pbsy_field_def:   field_def_type := (idx => irq_idx,    msb => 396 mod 64, lsb => 396 mod 64);
  constant prqp_field_def:   field_def_type := (idx => irq_idx,    msb => 397 mod 64, lsb => 397 mod 64);
  constant eirq_field_def:   field_def_type := (idx => irq_idx,    msb => 447 mod 64, lsb => 416 mod 64);
  constant upc_field_def:    field_def_type := (idx => uregs_idx,  msb => 463 mod 64, lsb => 448 mod 64);
  constant usp_field_def:    field_def_type := (idx => uregs_idx,  msb => 471 mod 64, lsb => 464 mod 64);
  constant ua_field_def:     field_def_type := (idx => uregs_idx,  msb => 479 mod 64, lsb => 472 mod 64);
  constant ux_field_def:     field_def_type := (idx => uregs_idx,  msb => 487 mod 64, lsb => 480 mod 64);
  constant uy_field_def:     field_def_type := (idx => uregs_idx,  msb => 495 mod 64, lsb => 488 mod 64);
  constant uc_field_def:     field_def_type := (idx => uregs_idx,  msb => 496 mod 64, lsb => 496 mod 64);
  constant uz_field_def:     field_def_type := (idx => uregs_idx,  msb => 497 mod 64, lsb => 497 mod 64);
  constant ui_field_def:     field_def_type := (idx => uregs_idx,  msb => 498 mod 64, lsb => 498 mod 64);
  constant ud_field_def:     field_def_type := (idx => uregs_idx,  msb => 499 mod 64, lsb => 499 mod 64);
  constant ub_field_def:     field_def_type := (idx => uregs_idx,  msb => 500 mod 64, lsb => 500 mod 64);
  constant uv_field_def:     field_def_type := (idx => uregs_idx,  msb => 502 mod 64, lsb => 502 mod 64);
  constant un_field_def:     field_def_type := (idx => uregs_idx,  msb => 503 mod 64, lsb => 503 mod 64);
  constant ufpd_field_def:   field_def_type := (idx => uprphs_idx, msb => 519 mod 64, lsb => 512 mod 64);
  constant ufpl_field_def:   field_def_type := (idx => uprphs_idx, msb => 527 mod 64, lsb => 520 mod 64);
  constant ufpo_field_def:   field_def_type := (idx => uprphs_idx, msb => 535 mod 64, lsb => 528 mod 64);
  constant ufpb_field_def:   field_def_type := (idx => uprphs_idx, msb => 543 mod 64, lsb => 536 mod 64);
  constant usig_field_def:   field_def_type := (idx => uprphs_idx, msb => 575 mod 64, lsb => 544 mod 64);
  constant uirqv_field_def:  field_def_type := (idx => uvects_idx, msb => 591 mod 64, lsb => 576 mod 64);
  constant urstv_field_def:  field_def_type := (idx => uvects_idx, msb => 607 mod 64, lsb => 592 mod 64);
  constant unmiv_field_def:  field_def_type := (idx => uvects_idx, msb => 623 mod 64, lsb => 608 mod 64);
  -- pragma translate_off
  constant tty_field_def:    field_def_type := (idx => uvects_idx, msb => 631 mod 64, lsb => 624 mod 64);
  constant eos_field_def:    field_def_type := (idx => uvects_idx, msb => 639 mod 64, lsb => 632 mod 64);
  -- pragma translate_on

  --* Number of 64-bits configuration and status registers
  constant n_cs_regs: natural range 0 to 15 := bitfield_width / 64;

  constant hst_mss_mask:  axi4lite_addr_type := x"fff80007";
  constant hst_mss_ba:    axi4lite_addr_type := x"00000000";
  constant hst_regs_mask: axi4lite_addr_type := x"ffffff07";
  constant hst_regs_ba:   axi4lite_addr_type := x"000fff00";
  constant uc_mss_mask:   uc_address_type  := x"f800";
  constant uc_mss_ba:     uc_address_type  := x"0000";
  constant uc_regs_mask:  uc_address_type  := x"ff00";
  constant uc_regs_ba:    uc_address_type  := x"ff00";

  constant dcfg_hst_add:   axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(dcfg_idx, 5)) & "000";
  constant dcst_hst_add:   axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(dcst_idx, 5)) & "000";
  constant dadd_hst_add:   axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(dadd_idx, 5)) & "000";
  constant dgost_hst_add:  axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(dgost_idx, 5)) & "000";
  constant pgost_hst_add:  axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(pgost_idx, 5)) & "000";
  constant ctrl_hst_add:   axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(ctrl_idx, 5)) & "000";
  constant irq_hst_add:    axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(irq_idx, 5)) & "000";
  constant uregs_hst_add:  axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(uregs_idx, 5)) & "000";
  constant uprphs_hst_add: axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(uprphs_idx, 5)) & "000";
  constant uvects_hst_add: axi4lite_addr_type := hst_regs_ba(31 downto 8) & std_ulogic_vector(to_unsigned(uvects_idx, 5)) & "000";

  constant dcfg_uc_add:   uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(dcfg_idx, 5)) & "000";
  constant dcst_uc_add:   uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(dcst_idx, 5)) & "000";
  constant dadd_uc_add:   uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(dadd_idx, 5)) & "000";
  constant dgost_uc_add:  uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(dgost_idx, 5)) & "000";
  constant pgost_uc_add:  uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(pgost_idx, 5)) & "000";
  constant ctrl_uc_add:   uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(ctrl_idx, 5)) & "000";
  constant irq_uc_add:    uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(irq_idx, 5)) & "000";
  constant uregs_uc_add:  uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(uregs_idx, 5)) & "000";
  constant uprphs_uc_add: uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(uprphs_idx, 5)) & "000";
  constant uvects_uc_add: uc_address_type := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(uvects_idx, 5)) & "000";

  procedure set_field(r: inout word64; f: in field_def_type; v: in std_ulogic_vector);
  procedure set_field(r: inout regs_type; f: in field_def_type; v: in std_ulogic_vector);
  procedure clear_on_set(r: inout word64; w: in word64; f: in field_def_type);
  procedure clear_on_set(r: inout regs_type; w: in word64; f: in field_def_type);
  procedure clear_on_read(r: inout word64; b: in word64_be_type; f: in field_def_type);
  procedure clear_on_read(r: inout regs_type; b: in word64_be_type; f: in field_def_type);
  procedure set_flag(r: inout word64; f: in field_def_type; v: in std_ulogic);
  procedure set_flag(r: inout regs_type; f: in field_def_type; v: in std_ulogic);
  function get_field(r: in word64; f: in field_def_type) return std_ulogic_vector;
  function get_field(r: in regs_type; f: in field_def_type) return std_ulogic_vector;
  function get_flag(r: in word64; f: in field_def_type) return std_ulogic;
  function get_flag(r: in regs_type; f: in field_def_type) return std_ulogic;
  function hst_is_in_mss(a: axi4lite_addr_type) return boolean;
  function hst_is_in_regs(a: axi4lite_addr_type) return boolean;
  function is_w(r: axi4lite_request_type) return boolean;
  function is_r(r: axi4lite_request_type) return boolean;
  function is_wr(r: axi4lite_request_type) return boolean;
  function is_w(r: axi4lite_request_type) return std_ulogic;
  function is_r(r: axi4lite_request_type) return std_ulogic;
  function is_wr(r: axi4lite_request_type) return std_ulogic;
  function is_reg_req(r: axi4lite_FIFO_request_type) return boolean;
  function is_reg_err(r: axi4lite_FIFO_request_type) return boolean;
  function is_mss_req(r: axi4lite_request_type) return boolean;
  function is_mss_w_err(r: axi4lite_request_type) return boolean;
  function is_mss_r_err(r: axi4lite_request_type) return boolean;
  function uc_is_in_mss(a: uc_address_type) return boolean;
  function uc_is_in_regs(a: uc_address_type) return boolean;
  function gen_is_host_mapped(n: natural) return boolean_vector;
  function gen_is_uc_mapped(n: natural) return boolean_vector;
  function hst_add2idx(a: axi4lite_addr_type) return natural;
  function idx2hst_add(i: natural range 0 to 31) return axi4lite_addr_type;
  function uc_add2idx(a: uc_address_type) return natural;
  function idx2uc_add(i: natural range 0 to 31) return uc_address_type;
  function fidx2idx(i: natural range 0 to n_cs_regs - 1) return natural;
  function idx2fidx(i: natural range 16 to 31) return natural;
  procedure word64_update(w: inout word64; be: in word64_be_type; wdata: in word64);
  procedure word64_update(w: inout word64; be: in word64_be_type; msk: in word64; wdata: in word64);

  type pss_status_fifo_entry is record
    st: status_type;
    err: std_ulogic;
    val: std_ulogic;
    data: data_type;
  end record pss_status_fifo_entry;
  constant pss_status_fifo_entry_none: pss_status_fifo_entry := (st => status_none, err => '0', val => '0', data => data_none);
  type pss_status_fifo_type is array(0 to 1) of pss_status_fifo_entry;
  constant pss_status_fifo_none: pss_status_fifo_type := (others => pss_status_fifo_entry_none);

  procedure push(f: inout pss_status_fifo_type; e: in pss_status_fifo_entry);
  procedure pop(f: inout pss_status_fifo_type);

  type dma_status_fifo_entry is record
    st: status_type;
    err: std_ulogic;
    val: std_ulogic;
  end record dma_status_fifo_entry;
  constant dma_status_fifo_entry_none: dma_status_fifo_entry := (st => status_none, err => '0', val => '0');
  type dma_status_fifo_type is array(0 to 1) of dma_status_fifo_entry;
  constant dma_status_fifo_none: dma_status_fifo_type := (others => dma_status_fifo_entry_none);

  procedure push(f: inout dma_status_fifo_type; e: in dma_status_fifo_entry);
  procedure pop(f: inout dma_status_fifo_type);

  type req2ctrl_type is record
    en:    std_ulogic;
    rnw:   std_ulogic;
    be:    axi4lite_strb_type;
    add:   natural range 0 to 31;
    wdata: axi4lite_data_type;
  end record;
  constant req2ctrl_none: req2ctrl_type := (en => '0', rnw => '0', be => (others => '0'), add => 0, wdata => (others => '0'));

  type ctrl2rsp_type is record
    ack:   std_ulogic;
    oor:   std_ulogic;
    rdata: axi4lite_data_type;
  end record;
  constant ctrl2rsp_none: ctrl2rsp_type := (ack => '1', oor => '0', rdata => (others => '0'));

  type via2ctrl_type is record
    en:    std_ulogic;
    rnw:   std_ulogic;
    be:    axi4lite_strb_type;
    add:   natural range 0 to 31;
    wdata: axi4lite_data_type;
  end record;
  constant via2ctrl_none: via2ctrl_type := (en => '0', rnw => '0', be => (others => '0'), add => 0, wdata => (others => '0'));

  type ctrl2via_type is record
    ack:   std_ulogic;
    oor:   std_ulogic;
    rdata: axi4lite_data_type;
  end record;
  constant ctrl2via_none: ctrl2via_type := (ack => '1', oor => '0', rdata => (others => '0'));

  type ctrl2dma_type is record
    srstn: std_ulogic; -- synchronous active low reset
    ce:    std_ulogic; -- chip enable
    exec:  std_ulogic; -- start DMA transfer
    ls:    std_ulogic; -- local source flag
    ld:    std_ulogic; -- local destination flag
    fs:    std_ulogic; -- fixed source address flag
    fd:    std_ulogic; -- fixed destination address flag
    cs:    std_ulogic; -- constant source data flag
    be:    axi4lite_strb_type;      -- write byte enable
    lenm1:   word32;           -- DMA transfer length minus one (bytes)
    cst:   axi4lite_data_type;    -- constant write data
    src:   axi4lite_addr_type; -- source address
    dst:   axi4lite_addr_type; -- destination address
  end record;
  constant ctrl2dma_none: ctrl2dma_type := (srstn => '0', ce => '0', exec => '0', ls => '0', ld => '0', fs => '0', fd => '0', cs => '0', be => (others => '0'),
                                            lenm1 => (others => '0'), cst => (others => '0'), src => (others => '0'), dst => (others => '0'));
-- pragma translate_off
  procedure print(ctrl2dma: in ctrl2dma_type; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit");
-- pragma translate_on

  type dma2ctrl_type is record
    eot:     std_ulogic;  -- end of transfer
    err:     std_ulogic;  -- error flag
    status:  status_type; -- return status
  end record;
  constant dma2ctrl_none: dma2ctrl_type := (eot => '0', err => '0', status => status_none);
-- pragma translate_off
  procedure print(dma2ctrl: in dma2ctrl_type; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit");
-- pragma translate_on

-- pragma translate_off
  procedure print(ctrl2pss: in css2pss_type; param: in std_ulogic_vector; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit");
  procedure print(pss2ctrl: in pss2css_type; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit");
-- pragma translate_on

  type ctrl2uc_type is record
    srstn: std_ulogic; -- synchronous active low reset
    ce:    std_ulogic; -- chip enable
    irq:   std_ulogic; -- Interrupt request
  end record;
  constant ctrl2uc_none: ctrl2uc_type := (srstn => '0', ce => '0', irq => '0');

  type uc2ctrl_type is record
    pc: word16;     -- UC Program Counter field
    sp: word8;      -- UC Stack Pointer field
    a:  word8;      -- UC Accumulator field
    x:  word8;      -- UC X register field
    y:  word8;      -- UC Y register field
    c:  std_ulogic; -- UC Carry flag field
    z:  std_ulogic; -- UC Zero flag field
    i:  std_ulogic; -- UC Interrupt disable flag field
    d:  std_ulogic; -- UC Decimal mode flag field
    b:  std_ulogic; -- UC Break flag field
    v:  std_ulogic; -- UC oVerflow flag field
    n:  std_ulogic; -- UC Negative flag field
    sync: std_ulogic; -- Sync flag (used in debug mode to de-assert chip enable after each instruction). Asserted two clock cycles before the next instruction fetch.
  end record;
  constant uc2ctrl_none: uc2ctrl_type := (pc => (others => '0'), sp => (others => '0'), a => (others => '0'), x => (others => '0'), y => (others => '0'),
                                          c => '0', z => '0', i => '0', d => '0', b => '0', v => '0', n => '0', sync => '0');

  type ctrl2uca_type is record
    nmi:   std_ulogic; -- Non-maskable interrupt request
    rdata: word64; -- Read data
    bs:    natural range 0 to 255;
    off:   natural range 0 to 255;
    dst:   natural range 0 to 255;
    lenm1: natural range 0 to 255;
    exec:  std_ulogic;
  end record;
  constant ctrl2uca_none: ctrl2uca_type := (nmi => '0', rdata => (others => '0'), bs => 0, off => 0, dst => 0, lenm1 => 0, exec => '0');

  type uca2ctrl_type is record
    en: std_ulogic; -- Enable
    rnw: std_ulogic; -- Read not write
    add: natural range 0 to 31; -- word64 address
    wdata: word64;     -- Write data
    be : std_ulogic_vector(7 downto 0);
    eot: std_ulogic; -- End of fast path transfert
  end record;
  constant uca2ctrl_none: uca2ctrl_type := (en => '0', rnw => '0', add => 0, wdata => (others => '0'), be => (others => '0'), eot => '0');

  type uc2uca_type is record
    en:    std_ulogic; -- Enable
    rnw:   std_ulogic; -- Read not write
    add:   word16;     -- Byte address (from 0xFF00 to 0xFFFF)
    wdata: word8;      -- Write data
  end record;
  constant uc2uca_none: uc2uca_type := (en => '0', rnw => '0', add => (others => '0'), wdata => (others => '0'));

  type uca2uc_type is record
    rdy:   std_ulogic; -- Data ready
    nmi:   std_ulogic; -- non maskable interrupt
    rdata: word8;      -- Read data
  end record;
  constant uca2uc_none: uca2uc_type := (rdy => '0', nmi => '0', rdata => (others => '0'));

  function is_read(f: field_def_type; r: req2ctrl_type) return boolean;
  function is_written(f: field_def_type; r: req2ctrl_type) return boolean;
  function is_read(f: field_def_type; r: uca2ctrl_type) return boolean;
  function is_written(f: field_def_type; r: uca2ctrl_type) return boolean;

  impure function ctrl2rsp_rnd return ctrl2rsp_type;

  function gen_mask(pa_mask: std_ulogic_vector; bitfield_mask: std_ulogic_vector; neirq: natural range 0 to 32) return regs_type;

end package css_pkg;

package body css_pkg is

  function "and"(r, l: regs_type) return regs_type is
    variable res: regs_type;
  begin
    for i in r'range loop
      res(i) := r(i) and l(i);
    end loop;
    return res;
  end function "and";

  function "or"(r, l: regs_type) return regs_type is
    variable res: regs_type;
  begin
    for i in r'range loop
      res(i) := r(i) or l(i);
    end loop;
    return res;
  end function "or";

  procedure set_field(r: inout word64; f: in field_def_type; v: in std_ulogic_vector) is
  begin
    r(f.msb downto f.lsb) := v;
  end procedure set_field;

  procedure set_field(r: inout regs_type; f: in field_def_type; v: in std_ulogic_vector) is
  begin
    set_field(r(f.idx), f, v);
  end procedure set_field;

  procedure clear_on_set(r: inout word64; w: in word64; f: in field_def_type) is
  begin
    set_field(r, f, (not get_field(w, f)) and get_field(r, f));
  end procedure clear_on_set;

  procedure clear_on_set(r: inout regs_type; w: in word64; f: in field_def_type) is
  begin
    clear_on_set(r(f.idx), w, f);
  end procedure clear_on_set;

  procedure clear_on_read(r: inout word64; b: in word64_be_type; f: in field_def_type) is
    variable lsb, msb: natural range 0 to 63;
  begin
    lsb := f.lsb mod 64;
    msb := f.msb mod 64;
    for i in msb downto lsb loop
      if b(i / 8) = '1' then
        r(i) := '0';
      end if;
    end loop;
  end procedure clear_on_read;

  procedure clear_on_read(r: inout regs_type; b: in word64_be_type; f: in field_def_type) is
  begin
    clear_on_read(r(f.idx), b, f);
  end procedure clear_on_read;

  procedure set_flag(r: inout word64; f: in field_def_type; v: in std_ulogic) is
  begin
-- pragma translate_off
    assert f.msb = f.lsb report "Invalid field assignment" severity failure;
-- pragma translate_on
    r(f.msb) := v;
  end procedure set_flag;

  procedure set_flag(r: inout regs_type; f: in field_def_type; v: in std_ulogic) is
  begin
-- pragma translate_off
    assert f.msb = f.lsb report "Invalid field assignment" severity failure;
-- pragma translate_on
    set_flag(r(f.idx), f, v);
  end procedure set_flag;

  function get_field(r: in word64; f: in field_def_type) return std_ulogic_vector is
  begin
    return r(f.msb downto f.lsb);
  end function get_field;

  function get_field(r: in regs_type; f: in field_def_type) return std_ulogic_vector is
  begin
    return get_field(r(f.idx), f);
  end function get_field;

  function get_flag(r: in word64; f: in field_def_type) return std_ulogic is
  begin
-- pragma translate_off
    assert f.msb = f.lsb report "Invalid field assignment" severity failure;
-- pragma translate_on
    return r(f.msb);
  end function get_flag;

  function get_flag(r: in regs_type; f: in field_def_type) return std_ulogic is
  begin
-- pragma translate_off
    assert f.msb = f.lsb report "Invalid field assignment" severity failure;
-- pragma translate_on
    return get_flag(r(f.idx), f);
  end function get_flag;

  function fidx2idx(i: natural range 0 to n_cs_regs - 1) return natural is
    variable r: natural range 16 to 31;
  begin
    if i = n_cs_regs - 1 then
      r := 31;
    elsif i = n_cs_regs - 2 then
      r := 30;
    else
      r := i + 16;
    end if;
    return r;
  end function fidx2idx;

  function idx2fidx(i: natural range 16 to 31) return natural is
    variable r: natural range 0 to n_cs_regs - 1;
  begin
    if i = 31 then
      r := n_cs_regs - 1;
    elsif i = 30 then
      r := n_cs_regs - 2;
    else
      r := i - 16;
    end if;
    return r;
  end function idx2fidx;

  function hst_is_in_mss(a: axi4lite_addr_type) return boolean is
  begin
    return (a and hst_mss_mask) = hst_mss_ba;
  end function hst_is_in_mss;

  function hst_is_in_regs(a: axi4lite_addr_type) return boolean is
  begin
    return (a and hst_regs_mask) = hst_regs_ba;
  end function hst_is_in_regs;

  function is_w(r: axi4lite_request_type) return boolean is
  begin
    return r.w_addr.awvalid = '1' and r.w_data.wvalid = '1';
  end is_w;
  
  function is_r(r: axi4lite_request_type) return boolean is
  begin
    return r.r_addr.arvalid = '1';
  end is_r;
  
  function is_wr(r: axi4lite_request_type) return boolean is
  begin
    return r.w_addr.awvalid = '1' and r.w_data.wvalid = '1' and r.r_addr.arvalid = '1';
  end is_wr;

  function is_w(r: axi4lite_request_type) return std_ulogic is
  begin
    return r.w_addr.awvalid and r.w_data.wvalid;
  end is_w;
  
  function is_r(r: axi4lite_request_type) return std_ulogic is
  begin
    return r.r_addr.arvalid;
  end is_r;
  
  function is_wr(r: axi4lite_request_type) return std_ulogic is
  begin
    return r.w_addr.awvalid and r.w_data.wvalid and r.r_addr.arvalid;
  end is_wr;
  
  function is_reg_req(r: axi4lite_FIFO_request_type) return boolean is
  begin
    return (r.awvalid = '1' and r.w_data.wvalid = '1' and hst_is_in_regs(r.addr)) or (r.arvalid = '1' and hst_is_in_regs(r.addr));
  end is_reg_req;
  
  function is_reg_err(r: axi4lite_FIFO_request_type) return boolean is
  begin
    return (r.awvalid = '1' and r.w_data.wvalid = '1' and not(hst_is_in_regs(r.addr))) or (r.arvalid = '1' and not(hst_is_in_regs(r.addr)));
  end is_reg_err;

  function is_mss_req(r: axi4lite_request_type) return boolean is
  begin
    return (r.w_addr.awvalid = '1' and r.w_data.wvalid = '1' and hst_is_in_mss(r.w_addr.awaddr)) or (r.r_addr.arvalid = '1' and hst_is_in_mss(r.r_addr.araddr));
  end is_mss_req;
    
  function is_mss_w_err(r: axi4lite_request_type) return boolean is
  begin
    return (r.w_addr.awvalid = '1' and r.w_data.wvalid = '1' and not(hst_is_in_mss(r.w_addr.awaddr)));
  end is_mss_w_err;

  function is_mss_r_err(r: axi4lite_request_type) return boolean is
  begin
    return (r.r_addr.arvalid = '1' and not(hst_is_in_mss(r.r_addr.araddr)));
  end is_mss_r_err;

  function uc_is_in_mss(a: uc_address_type) return boolean is
  begin
    return (a and uc_mss_mask) = uc_mss_ba;
  end function uc_is_in_mss;

  function uc_is_in_regs(a: uc_address_type) return boolean is
  begin
    return (a and uc_regs_mask) = uc_regs_ba;
  end function uc_is_in_regs;

  procedure word64_update(w: inout word64; be: in word64_be_type; wdata: in word64) is
  begin
    for i in 0 to 7 loop
      if be(i) = '1' then
        w(8 * i + 7 downto 8 * i) := wdata(8 * i + 7 downto 8 * i);
      end if;
    end loop;
  end procedure word64_update;

  procedure word64_update(w: inout word64; be: in word64_be_type; msk: in word64; wdata: in word64) is
  begin
    for i in 0 to 63 loop
      if (be(i / 8) = '1') and (msk(i) = '1') then
        w(i) := wdata(i);
      end if;
    end loop;
  end procedure word64_update;

  procedure push(f: inout pss_status_fifo_type; e: in pss_status_fifo_entry) is
    variable tmp: pss_status_fifo_entry := e;
  begin
    tmp.val := '1';
    if f(1).val = '1' then -- FIFO full
      f := f(1) & tmp;
    elsif f(0).val = '0' then -- FIFO empty
      f(0) := tmp;
    else
      f(1) := tmp;
    end if;
  end procedure push;

  procedure pop(f: inout pss_status_fifo_type) is
  begin
    if f(1).val = '1' then
      f(0) := f(1);
      f(1).val := '0';
    else
      f(0).val := '0';
    end if;
  end procedure pop;

  procedure push(f: inout dma_status_fifo_type; e: in dma_status_fifo_entry) is
    variable tmp: dma_status_fifo_entry := e;
  begin
    tmp.val := '1';
    if f(1).val = '1' then -- FIFO full
      f := f(1) & tmp;
    elsif f(0).val = '0' then -- FIFO empty
      f(0) := tmp;
    else
      f(1) := tmp;
    end if;
  end procedure push;

  procedure pop(f: inout dma_status_fifo_type) is
  begin
    if f(1).val = '1' then
      f(0) := f(1);
      f(1).val := '0';
    else
      f(0).val := '0';
    end if;
  end procedure pop;

  function gen_is_host_mapped(n: natural) return boolean_vector is
    variable res: boolean_vector(0 to 31);
  begin
    res := (others => false);
    for i in 0 to 15 loop
      if i < n then
        res(i) := true;
      end if;
      if i < n_cs_regs then
        res(fidx2idx(i)) := true;
      end if;
    end loop;
    return res;
  end function gen_is_host_mapped;

  function gen_is_uc_mapped(n: natural) return boolean_vector is
    variable res: boolean_vector(0 to 31);
  begin
    res := gen_is_host_mapped(n);
    res(uregs_idx) := false;
    return res;
  end function gen_is_uc_mapped;

  function hst_add2idx(a: axi4lite_addr_type) return natural is
  begin
    return to_integer(u_unsigned(a(7 downto 3)));
  end function hst_add2idx;

  function idx2hst_add(i: natural range 0 to 31) return axi4lite_addr_type is
    variable tmp: axi4lite_addr_type;
  begin
    tmp := hst_regs_ba;
    tmp(7 downto 3) := std_ulogic_vector(to_unsigned(i, 5));
    tmp(2 downto 0) := (others => '0');
    return tmp;
  end function idx2hst_add;

  function uc_add2idx(a: uc_address_type) return natural is
  begin
    return to_integer(u_unsigned(a(7 downto 3)));
  end function uc_add2idx;

  function idx2uc_add(i: natural range 0 to 31) return uc_address_type is
    variable tmp: uc_address_type;
  begin
    tmp := uc_regs_ba(15 downto 8) & std_ulogic_vector(to_unsigned(i, 5)) & "000";
    return tmp;
  end function idx2uc_add;

  impure function ctrl2rsp_rnd return ctrl2rsp_type is
    variable res: ctrl2rsp_type;
  begin
    res.ack:= std_ulogic_rnd;
    res.oor:= std_ulogic_rnd;
    res.rdata:= axi4lite_data_rnd;
    return res;
  end function ctrl2rsp_rnd;

-- pragma translate_off
  procedure print(ctrl2dma: in ctrl2dma_type; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit") is
    variable l: line;
  begin
    cnt := cnt + 1;
    print(l, name);
    print(l, ": Starting DMA transfer #");
    write(l, cnt);
    print(l, " at ");
    write(l, now);
    writeline(output, l);
    if verbose then
      print(l, "  SRSTN=");
      write(l, ctrl2dma.srstn);
      writeline(output, l);
      print(l, "     CE=");
      write(l, ctrl2dma.ce);
      writeline(output, l);
      print(l, "   EXEC=");
      write(l, ctrl2dma.exec);
      writeline(output, l);
      print(l, "     LS=");
      write(l, ctrl2dma.ls);
      writeline(output, l);
      print(l, "     LD=");
      write(l, ctrl2dma.ld);
      writeline(output, l);
      print(l, "     FS=");
      write(l, ctrl2dma.fs);
      writeline(output, l);
      print(l, "     FD=");
      write(l, ctrl2dma.fd);
      writeline(output, l);
      print(l, "     CS=");
      write(l, ctrl2dma.cs);
      writeline(output, l);
      print(l, "     BE=");
      hwrite(l, ctrl2dma.be);
      writeline(output, l);
      print(l, "  LENM1=");
      dwrite(l, ctrl2dma.lenm1);
      writeline(output, l);
      print(l, "    CST=");
      hwrite(l, ctrl2dma.cst);
      writeline(output, l);
      print(l, "    SRC=");
      hwrite(l, ctrl2dma.src);
      writeline(output, l);
      print(l, "    DST=");
      hwrite(l, ctrl2dma.dst);
      writeline(output, l);
    end if;
  end procedure print;

  procedure print(dma2ctrl: in dma2ctrl_type; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit") is
    variable l: line;
  begin
    cnt := cnt + 1;
    print(l, name);
    print(l, ": End of DMA transfer #");
    write(l, cnt);
    print(l, " at ");
    write(l, now);
    writeline(output, l);
    if verbose then
      print(l, "     EOT=");
      write(l, dma2ctrl.eot);
      writeline(output, l);
      print(l, "     ERR=");
      write(l, dma2ctrl.err);
      writeline(output, l);
      print(l, "  STATUS=");
      hwrite(l, dma2ctrl.status);
      writeline(output, l);
    end if;
  end procedure print;

  procedure print(ctrl2pss: in css2pss_type; param: in std_ulogic_vector; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit") is
    variable l: line;
  begin
    cnt := cnt + 1;
    print(l, name);
    print(l, ": Starting PSS processing #");
    write(l, cnt);
    print(l, " at ");
    write(l, now);
    writeline(output, l);
    if verbose then
      print(l, "  SRSTN=");
      write(l, ctrl2pss.srstn);
      writeline(output, l);
      print(l, "     CE=");
      write(l, ctrl2pss.ce);
      writeline(output, l);
      print(l, "   EXEC=");
      write(l, ctrl2pss.exec);
      writeline(output, l);
      print(l, "  PARAM=");
      hwrite(l, param);
      writeline(output, l);
    end if;
  end procedure print;

  procedure print(pss2ctrl: in pss2css_type; cnt: inout natural; verbose: in boolean; name: in string := "DSP Unit") is
    variable l: line;
  begin
    cnt := cnt + 1;
    print(l, name);
    print(l, ": End of PSS processing #");
    write(l, cnt);
    print(l, " at ");
    write(l, now);
    writeline(output, l);
    if verbose then
      print(l, "     EOC=");
      write(l, pss2ctrl.eoc);
      writeline(output, l);
      print(l, "     ERR=");
      write(l, pss2ctrl.err);
      writeline(output, l);
      print(l, "  STATUS=");
      hwrite(l, pss2ctrl.status);
      print(l, "  DATA=");
      hwrite(l, pss2ctrl.data);
      writeline(output, l);
    end if;
  end procedure print;
-- pragma translate_on

  function is_read(f: field_def_type; r: req2ctrl_type) return boolean is
    variable res: boolean := false;
    variable b: std_ulogic_vector(7 downto 0) := r.be;
  begin
    if r.add = f.idx and r.en = '1' and r.rnw = '1' then
      for i in f.lsb / 8 to f.msb / 8 loop
        if b(i) = '1' then
          res := true;
        end if;
      end loop;
    end if;
    return res;
  end function is_read;

  function is_written(f: field_def_type; r: req2ctrl_type) return boolean is
    variable res: boolean := false;
    variable b: std_ulogic_vector(7 downto 0) := r.be;
  begin
    if r.add = f.idx and r.en = '1' and r.rnw = '0' then
      for i in f.lsb / 8 to f.msb / 8 loop
        if b(i) = '1' then
          res := true;
        end if;
      end loop;
    end if;
    return res;
  end function is_written;

  function is_read(f: field_def_type; r: uca2ctrl_type) return boolean is
    variable res: boolean := false;
    variable b: std_ulogic_vector(7 downto 0) := r.be;
  begin
    if r.add = f.idx and r.en = '1' and r.rnw = '1' then
      for i in f.lsb / 8 to f.msb / 8 loop
        if b(i) = '1' then
          res := true;
        end if;
      end loop;
    end if;
    return res;
  end function is_read;

  function is_written(f: field_def_type; r: uca2ctrl_type) return boolean is
    variable res: boolean := false;
    variable b: std_ulogic_vector(7 downto 0) := r.be;
  begin
    if r.add = f.idx and r.en = '1' and r.rnw = '0' then
      for i in f.lsb / 8 to f.msb / 8 loop
        if b(i) = '1' then
          res := true;
        end if;
      end loop;
    end if;
    return res;
  end function is_written;

  function gen_mask(pa_mask: std_ulogic_vector; bitfield_mask: std_ulogic_vector; neirq: natural range 0 to 32) return regs_type is
    variable res: regs_type;
  begin
    res := (others => (others => '0'));
    for i in 0 to 15 loop
      if i < pa_mask'length / 64 then
        res(i) := pa_mask(64 * i + 63 downto 64 * i);
      end if;
      if i < n_cs_regs then
        if fidx2idx(i) = ctrl_idx or fidx2idx(i) = irq_idx then
          res(fidx2idx(i))(31 + neirq downto 0) := bitfield_mask(64 * i + 31 + neirq downto 64 * i);
        else
          res(fidx2idx(i)) := bitfield_mask(64 * i + 63 downto 64 * i);
        end if;
      end if;
    end loop;
    return res;
  end function gen_mask;

end package body css_pkg;
