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

--* @id $Id: utils.vhd 5037 2013-06-13 12:58:28Z rpacalet $
--* @brief Utility package
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2008-05-22
--*
--* Changes log
--*
--* - 2010-12-15 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   to_01
--*
--* - 2010-12-15 by Renaud Pacalet <renaud.pacalet@telecom-paristech.fr: added
--*   std_logic_vector versions of or_reduce
--*
--* - 2010-12-15 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   and_reduce
--*
--* - 2010-03-03 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   or_reduce
--*
--* - 2010-05-18 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   zero_pad_left
--*
--* - 2010-08-11 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   hread
--*
--* - 2010-09-02 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   vector and bit
--*
--* - 2010-09-09 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): fixed a
--*   bug in hwrite
--*
--* - 2011-05-11 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   u_signed versions of or_reduce and and_reduce
--*
--* - 2011-05-19 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   shift_left and shift_right, hwrite and hread of u_signed, removed write of
--*   bit_vector (already in textio).
--*
--* - 2011-05-23 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   decode functions and some more "and" functions.
--*
--* - 2011-06-16 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr): added
--*   rotate_left and rotate_right of std_ulogic_vector.
--*
--* - 2011-06-23 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added print = write(l, string'(.)) procedure
--*
--*   - added write(l, std_ulogic) procedure
--*
--* - 2011-07-08 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added decode(std_ulogic)
--*
--* - 2011-08-09 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added print(string) procedure
--*
--*   - moved hread, hwrite, write and print procedures to sim_utils.vhd
--*
--* - 2011-09-01 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - moved boolean_array definition to global.boolean_vector
--*
--*   - added boolean_vector versions of or_reduce and and_reduce
--*
--* - 2011-09-16 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added unsigned_resize(std_ulogic_vector; positive)
--*
--* - 2011-09-23 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added serializer - deserializer functions for VCI requests and responses 
--*
--* - 2012-11-07 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*
--*   - added to_stdulogic(boolean)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--pragma translate_off
use std.textio.all;
--pragma translate_on

use work.global.all;

package utils is

  -- Decode a n-bits word as a 2^n bits one-hot encoding: the leftmost bit of
  -- the result is set if a = (others => '0')...
  function decode(a: u_unsigned) return u_unsigned;
  function decode(a: std_ulogic_vector) return std_ulogic_vector;
  function decode(a: std_ulogic) return std_ulogic_vector;

  -- left shift (zeroes enter on the right)
  function shift_left(a: std_ulogic_vector; n: natural) return std_ulogic_vector;

  -- u_unsigned right shift (zeroes enter on the left)
  function shift_right(a: std_ulogic_vector; n: natural) return std_ulogic_vector;

  -- right rotate
  function rotate_right(a: std_ulogic_vector; n: natural) return std_ulogic_vector;

	function min(a: integer; b: integer) return integer;

  -- the log2 function returns the log base 2 of its parameter. the rounding
  -- is toward zero (log2(2) = log2(3) = 1). this function is synthesizable by
  -- precision RTL when the parameter is a static constant.
  function log2(v: positive) return natural;

  -- converts a std_ulogic to integer 0 or 1
  function to_i01(v: std_ulogic) return natural;

  -- returns the and of all bits of the input vector
  function and_reduce(v: std_ulogic_vector) return std_ulogic;
--  function and_reduce(v: std_logic_vector) return std_ulogic;
  function and_reduce(v: u_unsigned) return std_ulogic;
  function and_reduce(v: u_signed) return std_ulogic;
  function and_reduce(v: boolean_vector) return boolean;

  -- returns the or of all bits of the input vector
  function or_reduce(v: std_ulogic_vector) return std_ulogic;
--  function or_reduce(v: std_logic_vector) return std_ulogic;
  function or_reduce(v: u_unsigned) return std_ulogic;
  function or_reduce(v: u_signed) return std_ulogic;
  function or_reduce(v: boolean_vector) return boolean;

  -- left extends input vector to size bits with zeros
  function zero_pad_left(v: std_ulogic_vector; size: natural) return std_ulogic_vector;
	-- and between a vector and a bit
	function band(l: std_ulogic_vector; r: std_ulogic) return std_ulogic_vector;
	function band(l: std_ulogic; r: std_ulogic_vector) return std_ulogic_vector;
	function band(l: u_unsigned; r: std_ulogic) return u_unsigned;
	function band(l: std_ulogic; r: u_unsigned) return u_unsigned;
	function band(l: u_signed; r: std_ulogic) return u_signed;
	function band(l: std_ulogic; r: u_signed) return u_signed;

  function unsigned_resize(v: std_ulogic_vector; n: positive) return std_ulogic_vector;

  constant vci_request_length: natural := 1 + vci_n + vci_b + 2 + vci_b * 8 + vci_s + vci_t + vci_p + 1;
  constant vci_response_length: natural := 1 + vci_b * 8 + vci_e + 1 + 1 + vci_s + vci_t + vci_p;

  function to_stdulogic(b: boolean) return std_ulogic;
  function to_stdulogicvector(r: vci_request_type) return std_ulogic_vector;
  function to_vcirequesttype(v: std_ulogic_vector) return vci_request_type;
  function to_stdulogicvector(r: vci_response_type) return std_ulogic_vector;
  function to_vciresponsetype(v: std_ulogic_vector) return vci_response_type;

  function mask_bytes(v: std_ulogic_vector; b: std_ulogic_vector) return std_ulogic_vector;
  function mask_bytes(o: std_ulogic_vector; n: std_ulogic_vector; b: std_ulogic_vector) return std_ulogic_vector;
  function expand_bits_to_bytes(v: std_ulogic_vector) return std_ulogic_vector;

  -- returns n MSBs of v, indexed n-1 downto 0
  function get_msbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector;
  function get_msbs(v: u_unsigned; n: natural) return u_unsigned;
  function get_msbs(v: u_signed; n: natural) return u_signed;
  -- returns n LSBs of v, indexed n-1 downto 0
  function get_lsbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector;
  function get_lsbs(v: u_unsigned; n: natural) return u_unsigned;
  function get_lsbs(v: u_signed; n: natural) return u_signed;
  -- drops the n MSBs of v and returns the remaining LSBs indexed x-1 downto 0
  function drop_msbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector;
  function drop_msbs(v: u_unsigned; n: natural) return u_unsigned;
  function drop_msbs(v: u_signed; n: natural) return u_signed;
  -- drops the n LSBs of v and returns the remaining MSBs indexed x-1 downto 0
  function drop_lsbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector;
  function drop_lsbs(v: u_unsigned; n: natural) return u_unsigned;
  function drop_lsbs(v: u_signed; n: natural) return u_signed;

  -- carry save adder
  function csa(v: word32_vector) return word32_vector;

  -- Vector swapping. Recursively swaps v halves, quarters, eigths,... under control of bits of s, starting with MSB of s for the halves swapping. Examples:
  -- vector_swap("00011011", "00") = "00011011"
  -- vector_swap("00011011", "01") = "01001110"
  -- vector_swap("00011011", "10") = "10110001"
  -- vector_swap("00011011", "11") = "11100100"
  function vector_swap(v: std_ulogic_vector; s: std_ulogic_vector) return std_ulogic_vector;

end package utils;

package body utils is

  function decode(a: u_unsigned) return u_unsigned is
    constant n: natural := a'length;
    variable tmp: u_unsigned(n - 1 downto 0) := a;
    variable res: u_unsigned(2**n - 1 downto 0);
  begin
    if n = 0 then
      res := "1";
    elsif n = 1 then
      if tmp(0) = '0' then
        res := "10";
      else
        res := "01";
      end if;
    else
      res := band((not tmp(n - 1)), decode(tmp(n - 2 downto 0))) & band(tmp(n - 1), decode(tmp(n - 2 downto 0)));
    end if;
    return res;
  end function decode;

  function decode(a: std_ulogic_vector) return std_ulogic_vector is
  begin
    return std_ulogic_vector(decode(u_unsigned(a)));
  end function decode;

  function decode(a: std_ulogic) return std_ulogic_vector is
    variable va: std_ulogic_vector(0 downto 0);
  begin
    va(0) := a;
    return decode(va);
  end function decode;

  function shift_left(a: std_ulogic_vector; n: natural) return std_ulogic_vector is
  begin
--    return std_ulogic_vector(shift_left(u_unsigned(a), n));
    return a sll n;
  end function shift_left;

  function shift_right(a: std_ulogic_vector; n: natural) return std_ulogic_vector is
  begin
--    return std_ulogic_vector(shift_right(u_unsigned(a), n));
    return a srl n;
  end function shift_right;

  function rotate_right(a: std_ulogic_vector; n: natural) return std_ulogic_vector is
  begin
--    return std_ulogic_vector(rotate_right(u_unsigned(a), n));
	  return a ror n;
  end function rotate_right;

	function min(a: integer; b: integer) return integer is
	begin
--		if a < b then
--			return a;
--		else
--			return b;
--		end if;
		return minimum(a, b);
	end function min;

  function log2(v: positive) return natural is
    variable res: natural;
  begin
    if v = 1 then return 0;
    else return 1 + log2(v / 2);
    end if;
  end function log2;

  function to_i01(v: std_ulogic) return natural is
    variable res: natural range 0 to 1 := 0;
  begin
    if v = '1' then
      res := 1;
--pragma translate_off
    elsif v /= '0' then
      assert false
        report "to_i01: 'U'|'X'|'W'|'Z'|'-'|'L'|'H' input"
        severity warning;
--pragma translate_on
    end if;
    return res;
  end function to_i01;

  function and_reduce(v: std_ulogic_vector) return std_ulogic is
--    variable tmp: std_ulogic_vector(v'length - 1 downto 0) := v;
  begin
--    if tmp'length = 0 then
--      return '0';
--    elsif tmp'length = 1 then
--      return tmp(0);
--    else
--      return and_reduce(tmp(tmp'length - 1 downto tmp'length / 2)) and
--             and_reduce(tmp(tmp'length / 2 - 1 downto 0));
--    end if;
	  return "and"(v);
  end function and_reduce;

--  function and_reduce(v: std_logic_vector) return std_ulogic is
--	begin
--		return and_reduce(std_ulogic_vector(v));
--	end function and_reduce;
--
  function and_reduce(v: u_unsigned) return std_ulogic is
	begin
		return and_reduce(std_ulogic_vector(v));
	end function and_reduce;

  function and_reduce(v: u_signed) return std_ulogic is
	begin
		return and_reduce(std_ulogic_vector(v));
	end function and_reduce;

  function and_reduce(v: boolean_vector) return boolean is
--    variable tmp: boolean_vector(v'length - 1 downto 0) := v;
  begin
--    if tmp'length = 0 then
--      return false;
--    elsif tmp'length = 1 then
--      return tmp(0);
--    else
--      return and_reduce(tmp(tmp'length - 1 downto tmp'length / 2)) and
--             and_reduce(tmp(tmp'length / 2 - 1 downto 0));
--    end if;
	  return and v;
  end function and_reduce;

  function or_reduce(v: std_ulogic_vector) return std_ulogic is
--    variable tmp: std_ulogic_vector(v'length - 1 downto 0) := v;
  begin
--    if tmp'length = 0 then
--      return '0';
--    elsif tmp'length = 1 then
--      return tmp(0);
--    else
--      return or_reduce(tmp(tmp'length - 1 downto tmp'length / 2)) or
--             or_reduce(tmp(tmp'length / 2 - 1 downto 0));
--    end if;
	  return or v;
  end function or_reduce;

--  function or_reduce(v: std_logic_vector) return std_ulogic is
--	begin
--		return or_reduce(std_ulogic_vector(v));
--	end function or_reduce;
--
  function or_reduce(v: u_unsigned) return std_ulogic is
	begin
		return or_reduce(std_ulogic_vector(v));
	end function or_reduce;

  function or_reduce(v: u_signed) return std_ulogic is
	begin
		return or_reduce(std_ulogic_vector(v));
	end function or_reduce;

  function or_reduce(v: boolean_vector) return boolean is
--    variable tmp: boolean_vector(v'length - 1 downto 0) := v;
  begin
--    if tmp'length = 0 then
--      return false;
--    elsif tmp'length = 1 then
--      return tmp(0);
--    else
--      return or_reduce(tmp(tmp'length - 1 downto tmp'length / 2)) or
--             or_reduce(tmp(tmp'length / 2 - 1 downto 0));
--    end if;
	  return or v;
  end function or_reduce;

  function zero_pad_left(v: std_ulogic_vector; size: natural) return std_ulogic_vector is
    variable res: std_ulogic_vector(size - 1 downto 0);
  begin
--pragma translate_off
    assert v'length <= size
      report "zero_pad_left: cannot downsize"
      severity failure;
--pragma translate_on
    res := (others => '0');
    res(v'length - 1 downto 0) := v;
    return res;
  end function zero_pad_left;

	function band(l: std_ulogic_vector; r: std_ulogic)
	  return std_ulogic_vector is
		variable tmp: std_ulogic_vector(0 to l'length - 1) := l;
	begin
    for i in 0 to l'length - 1 loop
			tmp(i) := tmp(i) and r;
		end loop;
		return tmp;
	end function band;

	function band(l: std_ulogic; r: std_ulogic_vector)
	  return std_ulogic_vector is
	begin
		return band(r, l);
	end function band;

  function band(l: u_unsigned; r: std_ulogic) return u_unsigned is
  begin
    return u_unsigned(band(std_ulogic_vector(l), r));
  end function band;

  function band(l: std_ulogic; r: u_unsigned) return u_unsigned is
  begin
    return u_unsigned(band(std_ulogic_vector(r), l));
  end function band;

  function band(l: u_signed; r: std_ulogic) return u_signed is
  begin
    return u_signed(band(std_ulogic_vector(l), r));
  end function band;

  function band(l: std_ulogic; r: u_signed) return u_signed is
  begin
    return u_signed(band(std_ulogic_vector(r), l));
  end function band;

  function unsigned_resize(v: std_ulogic_vector; n: positive) return std_ulogic_vector is
    variable res: std_ulogic_vector(n - 1 downto 0) := (others => '0');
    variable tmp: std_ulogic_vector(v'length - 1 downto 0) := v;
  begin
    if n >= v'length then
      res(v'length - 1 downto 0) := v;
    else
      res := tmp(n - 1 downto 0);
    end if;
    return res;
  end function unsigned_resize;

  function to_stdulogic(b: boolean) return std_ulogic is
    variable res: std_ulogic := '0';
  begin
    if b then
      res := '1';
    end if;
    return res;
  end function to_stdulogic;

  function to_stdulogicvector(r: vci_request_type) return std_ulogic_vector is
    variable v: std_ulogic_vector(vci_request_length - 1 downto 0);
    variable n: natural;
  begin
    n := 0;
    v(n) := r.cmdval;
    n := n + 1;
    v(n + vci_n - 1 downto n) := r.address;
    n := n + vci_n;
    v(n + vci_b - 1 downto n) := r.be;
    n := n + vci_b;
    v(n + 1 downto n) := r.cmd;
    n := n + 2;
    v(n + vci_b * 8 - 1 downto n) := r.wdata;
    n := n + vci_b * 8;
    v(n + vci_s - 1 downto n) := r.srcid;
    n := n + vci_s;
    v(n + vci_t - 1 downto n) := r.trdid;
    n := n + vci_t;
    v(n + vci_p - 1 downto n) := r.pktid;
    n := n + vci_p;
    v(n) := r.eop;
    return v;
  end function to_stdulogicvector;

  function to_vcirequesttype(v: std_ulogic_vector) return vci_request_type is
    variable r: vci_request_type;
    variable n: natural;
  begin
    n := 0;
    r.cmdval := v(n);
    n := n + 1;
    r.address := v(n + vci_n - 1 downto n);
    n := n + vci_n;
    r.be := v(n + vci_b - 1 downto n);
    n := n + vci_b;
    r.cmd := v(n + 1 downto n);
    n := n + 2;
    r.wdata := v(n + vci_b * 8 - 1 downto n);
    n := n + vci_b * 8;
    r.srcid := v(n + vci_s - 1 downto n);
    n := n + vci_s;
    r.trdid := v(n + vci_t - 1 downto n);
    n := n + vci_t;
    r.pktid := v(n + vci_p - 1 downto n);
    n := n + vci_p;
    r.eop := v(n);
    return r;
  end function to_vcirequesttype;

  function to_stdulogicvector(r: vci_response_type) return std_ulogic_vector is
    variable v: std_ulogic_vector(vci_response_length - 1 downto 0);
    variable n: natural;
  begin
    n := 0;
    v(n) := r.rspval;
    n := n + 1;
    v(n + vci_b * 8 - 1 downto n) := r.rdata;
    n := n + vci_b * 8;
    v(n + vci_e downto n) := r.rerror;
    n := n + vci_e + 1;
    v(n) := r.reop;
    n := n + 1;
    v(n + vci_s - 1 downto n) := r.rsrcid;
    n := n + vci_s;
    v(n + vci_t - 1 downto n) := r.rtrdid;
    n := n + vci_t;
    v(n + vci_p - 1 downto n) := r.rpktid;
    return v;
  end function to_stdulogicvector;

  function to_vciresponsetype(v: std_ulogic_vector) return vci_response_type is
    variable r: vci_response_type;
    variable n: natural;
  begin
    n := 0;
    r.rspval := v(n);
    n := n + 1;
    r.rdata := v(n + vci_b * 8 - 1 downto n);
    n := n + vci_b * 8;
    r.rerror := v(n + vci_e downto n);
    n := n + vci_e + 1;
    r.reop := v(n);
    n := n + 1;
    r.rsrcid := v(n + vci_s - 1 downto n);
    n := n + vci_s;
    r.rtrdid := v(n + vci_t - 1 downto n);
    n := n + vci_t;
    r.rpktid := v(n + vci_p - 1 downto n);
    return r;
  end function to_vciresponsetype;

  function mask_bytes(v: std_ulogic_vector; b: std_ulogic_vector) return std_ulogic_vector is
    constant nv: natural := v'length;
    constant nb: natural := b'length;
    variable vv: std_ulogic_vector(nv - 1 downto 0) := v;
    variable res: std_ulogic_vector(nv - 1 downto 0) := (others => '0');
    variable vb: std_ulogic_vector(nb - 1 downto 0) := b;
  begin
--pragma translate_off
    assert nv = nb * 8
      report "mask_bytes: invalid parameters"
      severity failure;
--pragma translate_on
    for i in 0 to nb - 1 loop
      if vb(i) = '1' then
        res(8 * i + 7 downto 8 * i) := vv(8 * i + 7 downto 8 * i);
      end if;
    end loop;
    return res;
  end function mask_bytes;

  function mask_bytes(o: std_ulogic_vector; n: std_ulogic_vector; b: std_ulogic_vector) return std_ulogic_vector is
  begin
    return mask_bytes(o, not b) or mask_bytes(n, b);
  end function mask_bytes;

  function expand_bits_to_bytes(v: std_ulogic_vector) return std_ulogic_vector is
    constant nb: natural := v'length;
    variable vv: std_ulogic_vector(nb - 1 downto 0) := v;
    variable res: std_ulogic_vector(8 * nb - 1 downto 0) := (others => '0');
  begin
    for i in 0 to nb - 1 loop
      if vv(i) = '1' then
        res(8 * i + 7 downto 8 * i) := X"FF";
      end if;
    end loop;
    return res;
  end function expand_bits_to_bytes;

  function get_msbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector is
    constant vn: natural := v'length;
    variable tmp: std_ulogic_vector(vn - 1 downto 0) := v;
    variable res: std_ulogic_vector(n - 1 downto 0);
  begin
--pragma translate_off
    assert n <= vn report "get_msbs: invalid parameters" severity failure;
--pragma translate_on
    res := tmp(vn - 1 downto vn - n);
    return res;
  end function get_msbs;

  function get_msbs(v: u_unsigned; n: natural) return u_unsigned is
  begin
    return u_unsigned(get_msbs(std_ulogic_vector(v), n));
  end function get_msbs;

  function get_msbs(v: u_signed; n: natural) return u_signed is
  begin
    return u_signed(get_msbs(std_ulogic_vector(v), n));
  end function get_msbs;

  function get_lsbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector is
    constant vn: natural := v'length;
    variable tmp: std_ulogic_vector(vn - 1 downto 0) := v;
    variable res: std_ulogic_vector(n - 1 downto 0);
  begin
--pragma translate_off
    assert n <= vn report "get_msbs: invalid parameters" severity failure;
--pragma translate_on
    res := tmp(n - 1 downto 0);
    return res;
  end function get_lsbs;

  function get_lsbs(v: u_unsigned; n: natural) return u_unsigned is
  begin
    return u_unsigned(get_lsbs(std_ulogic_vector(v), n));
  end function get_lsbs;

  function get_lsbs(v: u_signed; n: natural) return u_signed is
  begin
    return u_signed(get_lsbs(std_ulogic_vector(v), n));
  end function get_lsbs;

  function drop_msbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector is
    constant vn: natural := v'length;
    variable tmp: std_ulogic_vector(vn - 1 downto 0) := v;
    variable res: std_ulogic_vector(vn - n - 1 downto 0);
  begin
--pragma translate_off
    assert n <= vn report "drop_msbs: invalid parameters" severity failure;
--pragma translate_on
    res := tmp(vn - n - 1 downto 0);
    return res;
  end function drop_msbs;

  function drop_msbs(v: u_unsigned; n: natural) return u_unsigned is
  begin
    return u_unsigned(drop_msbs(std_ulogic_vector(v), n));
  end function drop_msbs;

  function drop_msbs(v: u_signed; n: natural) return u_signed is
  begin
    return u_signed(drop_msbs(std_ulogic_vector(v), n));
  end function drop_msbs;

  function drop_lsbs(v: std_ulogic_vector; n: natural) return std_ulogic_vector is
    constant vn: natural := v'length;
    variable tmp: std_ulogic_vector(vn - 1 downto 0) := v;
    variable res: std_ulogic_vector(vn - n - 1 downto 0);
  begin
--pragma translate_off
    assert n <= vn report "drop_lsbs: invalid parameters" severity failure;
--pragma translate_on
    res := tmp(vn - 1 downto n);
    return res;
  end function drop_lsbs;


  function drop_lsbs(v: u_unsigned; n: natural) return u_unsigned is
  begin
    return u_unsigned(drop_lsbs(std_ulogic_vector(v), n));
  end function drop_lsbs;

  function drop_lsbs(v: u_signed; n: natural) return u_signed is
  begin
    return u_signed(drop_lsbs(std_ulogic_vector(v), n));
  end function drop_lsbs;

  function csa(v: word32_vector) return word32_vector is
    constant n: natural := v'length;
    constant n1: natural := 2 * (n / 3) + (n mod 3);
    variable tmp: word32_vector(0 to n - 1) := v;
    variable tmp1: word32_vector(0 to n1 - 1) := (others => (others => '0'));
    variable res: word32_vector(0 to 1) := (others => (others => '0'));
  begin
    if n = 1 then
      res(0) := tmp(0);
    elsif n = 2 then
      res := tmp;
    elsif n >= 3 then
      for i in 0 to n / 3 - 1 loop
        tmp1(2 * i) := tmp(3 * i) xor tmp(3 * i + 1) xor tmp(3 * i + 2);
        tmp1(2 * i + 1) := (tmp(3 * i) and tmp(3 * i + 1)) or (tmp(3 * i) and tmp(3 * i + 2)) or (tmp(3 * i + 1) and tmp(3 * i + 2));
        tmp1(2 * i + 1) := shift_left(tmp1(2 * i + 1), 1);
      end loop;
      if 2 * (n / 3 - 1) + 2 <= n1 - 1 then
        tmp1(2 * (n / 3 - 1) + 2 to n1 - 1) := tmp(3 * (n / 3 - 1) + 3 to n - 1);
      end if;
      res := csa(tmp1);
    end if;
    return res;
  end function csa;

  function vector_swap(v: std_ulogic_vector; s: std_ulogic_vector) return std_ulogic_vector is
    constant nv: natural := v'length;
    variable vv: std_ulogic_vector(nv - 1 downto 0) := v;
    constant ns: natural := s'length;
    variable vs: std_ulogic_vector(ns - 1 downto 0) := s;
  begin
--pragma translate_off
    assert ns >= 1 and (nv / 8 = 2**ns or nv = 2**ns) report "Invalid parameters" severity failure;
--pragma translate_on
    if vs(ns - 1) = '1' then
      vv := vv(nv / 2 - 1 downto 0) & vv(nv - 1 downto nv / 2);
    end if;
    if ns /= 1 then
      vv := vector_swap(vv(nv - 1 downto nv / 2), vs(ns - 2 downto 0)) & vector_swap(vv(nv / 2 - 1 downto 0), vs(ns - 2 downto 0));
    end if;
    return vv;
  end function vector_swap;

end package body utils;
