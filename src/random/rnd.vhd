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

--* @id $Id: rnd.vhd 4362 2012-09-25 13:24:56Z rpacalet $
--* @brief Wrapper around the RANDOM_LIB.RANDOM package
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2000-01-01
--*
--*  This package is a wrapper around the RANDOM_LIB.RANDOM package. It
--* provides some uniform random generators for several usual types. For more
--* sophisticated random generators use RANDOM_LIB.RANDOM instead.
--*
--* Changes log
--* - 2010-09-09 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - fixed an incredible bug; on binary draws the low and high bounds were !
--*     equal, leading to a constant result. It is a true mystery that nobody
--*     never noticed this...
--*   - Added a string version
--* - 2011-06-14 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Replaced ieee numeric_std by global_lib.numeric_std
--*   - Added unsigned_rnd and signed_rnd
--* - 2012-09-25 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added g_seed_rnd, g_integer_rnd and g_int_rnd (geometric integer random generator)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.random.all;

package rnd is

	-- Version string
	constant rnd_version: string := "Version 1.2 - 2012-09-25";

-- Use SEED_RND(<1-50>) to initialize the random generator. By default
-- the random generator is intialized with SEED_RND(1).
  procedure seed_rnd(seed: in positive range 1 to 50);

-- Returns a random value of type Bit ('0' or '1').
  impure function bit_rnd return bit;

-- Returns a random value of type Boolean (false or true).
  impure function boolean_rnd return boolean;

-- Returns a random value of type Std_Ulogic ('0' or '1' only).
  impure function std_ulogic_rnd return std_ulogic;

-- Returns a random value of type Std_Ulogic_Vector (with '0' and '1' only).
  impure function std_ulogic_vector_rnd(size: natural) return
    std_ulogic_vector;

-- Returns a random value of type Unsigned (with '0' and '1' only).
  impure function unsigned_rnd(size: natural) return
    u_unsigned;

-- Returns a random value of type Signed (with '0' and '1' only).
  impure function signed_rnd(size: natural) return
    u_signed;

-- Returns a random value of type Std_Logic ('0' or '1' only).
  impure function std_logic_rnd return std_logic;

-- Returns a random value of type Std_Logic_Vector (with '0' and '1' only).
  impure function std_logic_vector_rnd(size: natural) return
    std_logic_vector;

-- Returns a random value of type Integer (greater or equal L and lower or equal
-- H).
  impure function integer_rnd(l, h: integer) return integer;

-- Just another name for INTEGER_RND.
  impure function int_rnd(l, h: integer) return integer;

-- Use SEED_RND(<1-50>) to initialize the random generator. By default
-- the random generator is intialized with SEED_RND(1).
  procedure g_seed_rnd(seed: in positive range 1 to 50);

  -- Returns a random value of type Integer generated from a geometric generator with probability of success p_success (real in the [0..1] range).
  impure function g_integer_rnd(p_success: real) return integer;

-- Just another name for GINTEGER_RND.
  impure function g_int_rnd(p_success: real) return integer;

end package rnd;

package body rnd is

  subtype seeds is positive range 1 to 50;

  type shared_rnd_rec is protected
    procedure set_seed(seed: seeds);
    procedure apply_rnd_random;
    impure function get_rnd return integer;
    procedure set_bounds(bound_l: in integer; bound_h: in integer);
  end protected shared_rnd_rec;

  type shared_rnd_rec is protected body
    variable rec: rnd_rec_t := (
      rnd          => 0.0,
      distribution => rnd_uniform_d,
      seed         => rnd_seeds(1),
      mean         => 0.0,
      std_dev      => 0.0,
      bound_l      => real(integer'low),
      bound_h      => real(integer'high),
      trials       => 0,
      p_success    => 0.0);
    procedure set_seed(seed: seeds) is
    begin
      rec.seed := rnd_seeds(seed);
    end procedure set_seed;
    procedure apply_rnd_random is
    begin
      rnd_random(rec);
    end procedure apply_rnd_random;
    impure function get_rnd return integer is
    begin
      return integer(rec.rnd);
    end function get_rnd;
    procedure set_bounds(bound_l: in integer; bound_h: in integer) is
    begin
      rec.bound_l := real(bound_l);
      rec.bound_h := real(bound_h);
    end procedure set_bounds;
  end protected body shared_rnd_rec;

  shared variable rnd_rec: shared_rnd_rec;

  procedure seed_rnd(seed: seeds) is
  begin
    rnd_rec.set_seed(seed);
  end procedure seed_rnd;

  type shared_g_rnd_rec is protected
    procedure set_seed(seed: seeds);
    procedure apply_rnd_random;
    impure function get_rnd return integer;
    procedure set_p_success(p_success: in real);
  end protected shared_g_rnd_rec;

  type shared_g_rnd_rec is protected body
    variable rec: rnd_rec_t := (
      rnd          => 0.0,
      distribution => rnd_geometric,
      seed         => rnd_seeds(1),
      mean         => 0.0,
      std_dev      => 0.0,
      bound_l      => 0.0,
      bound_h      => 0.0,
      trials       => 0,
      p_success    => 0.5);
    procedure set_seed(seed: seeds) is
    begin
      rec.seed := rnd_seeds(seed);
    end procedure set_seed;
    procedure apply_rnd_random is
    begin
      rnd_random(rec);
    end procedure apply_rnd_random;
    impure function get_rnd return integer is
    begin
      return integer(rec.rnd);
    end function get_rnd;
    procedure set_p_success(p_success: in real) is
    begin
      rec.p_success := p_success;
    end procedure set_p_success;
  end protected body shared_g_rnd_rec;

  shared variable g_rnd_rec: shared_g_rnd_rec;

  procedure g_seed_rnd(seed: seeds) is
  begin
    g_rnd_rec.set_seed(seed);
  end procedure g_seed_rnd;

  impure function bit_rnd return bit is
  begin
    rnd_rec.set_bounds(0, 1);
    rnd_rec.apply_rnd_random;
    if rnd_rec.get_rnd mod 2 = 0 then
      return '0';
    else
      return '1';
    end if;
  end function bit_rnd;

  impure function boolean_rnd return boolean is
  begin
    rnd_rec.set_bounds(0, 1);
    rnd_rec.apply_rnd_random;
    if rnd_rec.get_rnd mod 2 = 0 then
      return false;
    else
      return true;
    end if;
  end function boolean_rnd;

  impure function std_ulogic_rnd return std_ulogic is
  begin
    rnd_rec.set_bounds(0, 1);
    rnd_rec.apply_rnd_random;
    if rnd_rec.get_rnd mod 2 = 0 then
      return '0';
    else
      return '1';
    end if;
  end function std_ulogic_rnd;

  impure function std_ulogic_vector_rnd(size: natural) return
    std_ulogic_vector is
    variable res: std_ulogic_vector(1 to size);
  begin
    for i in 1 to size loop
      res(i) := std_ulogic_rnd;
    end loop;
    return res;
  end function std_ulogic_vector_rnd;

  impure function unsigned_rnd(size: natural) return u_unsigned is
  begin
    return u_unsigned(std_ulogic_vector_rnd(size));
  end function unsigned_rnd;

  impure function signed_rnd(size: natural) return u_signed is
  begin
    return u_signed(std_ulogic_vector_rnd(size));
  end function signed_rnd;

  impure function std_logic_rnd return std_logic is
  begin
    rnd_rec.apply_rnd_random;
    if rnd_rec.get_rnd mod 2 = 0 then
      return '0';
    else
      return '1';
    end if;
  end function std_logic_rnd;

  impure function std_logic_vector_rnd(size: natural) return
    std_logic_vector is
    variable res: std_logic_vector(1 to size);
  begin
    for i in 1 to size loop
      res(i) := std_logic_rnd;
    end loop;
    return res;
  end function std_logic_vector_rnd;

  impure function integer_rnd(l, h: integer) return integer is
  begin
    rnd_rec.set_bounds(l, h);
    rnd_rec.apply_rnd_random;
    return rnd_rec.get_rnd;
  end function integer_rnd;

  impure function int_rnd(l, h: integer) return integer is
  begin
    return integer_rnd(l, h);
  end function int_rnd;

  impure function g_integer_rnd(p_success: real) return integer is
  begin
    g_rnd_rec.set_p_success(p_success);
    g_rnd_rec.apply_rnd_random;
    return g_rnd_rec.get_rnd;
  end function g_integer_rnd;

  impure function g_int_rnd(p_success: real) return integer is
  begin
    return g_integer_rnd(p_success);
  end function g_int_rnd;

end package body rnd;
