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

--* @id $Id: fifo.vhd 4628 2012-12-18 10:16:30Z rpacalet $
--* @brief Blockin FIFO
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2012-12-18
--*
--* Generic blocking FIFO. A read operation succeeds iff the FIFO is not empty (it may become empty after the read):
--* - rising edge of clk for which read_en=1 and empty=0 => read succeeds,
--* - rising edge of clk for which read_en=1 and empty=1 => read fails.
--*  The reader must sample the output data bus on rising edges of the clock for which read_en=1 and empty=0. A write operation succeeds iff the FIFO is not full
--*  (it may become full after the write) or if there is also a read:
--* - rising edge of clk for which write_en=1 and full=0 => write succeeds,
--* - rising edge of clk for which write_en=1 and read_en=1 => write succeeds,
--* - rising edge of clk for which write_en=1 and full=1 and read_en=0 => write fails.
--* During a write operation the input data bus is written on rising edges of the clock for which write_en=1 and (read_en=1 or full=0). The read and write pointers
--* are right-rotating vectors.
--*
--* Changes log

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.global.all;

entity fifo is
  generic(
    width: positive := 1;
    depth: positive := 2);
  port(
    clk:     in  std_ulogic;  --* master clock
    srstn:   in  std_ulogic;  --* synchronous active low reset
    read_en:    in  std_ulogic;  --* read enable
    write_en:   in  std_ulogic;  --* write enable
    din:     in  std_ulogic_vector(width - 1 downto 0); --* data input
    dout:    out std_ulogic_vector(width - 1 downto 0); --* data output
    full:    out std_ulogic;  --* FIFO full
    empty:   out std_ulogic); --* FIFO empty

end entity fifo;

architecture rtl of fifo is

  function rotate_right(a: std_ulogic_vector) return std_ulogic_vector is
  begin
    return std_ulogic_vector(rotate_right(u_unsigned(a), 1));
  end function rotate_right;

  type memory_type is array (0 to depth - 1) of std_ulogic_vector(width - 1 downto 0);

  signal f: memory_type;
  attribute ram_block of f: signal is false;
  signal rptr, wptr: std_ulogic_vector(0 to depth - 1);

begin

  process(f, rptr)
  begin
    dout <= (others => '0');
    for i in 0 to depth - 1 loop
      if rptr(i) = '1' then
        dout <= f(i);
      end if;
    end loop;
  end process;

  process(clk)
    variable empty_local, full_local: std_ulogic;
    variable next_rptr, next_wptr: std_ulogic_vector(0 to depth - 1);
  begin
    if rising_edge(clk) then
      if srstn = '0' then -- if reset active...
        f(0) <= (others => '0');
        rptr <= (others => '0');
        rptr(0) <= '1';
        wptr <= (others => '0');
        wptr(0) <= '1';
        empty_local := '1';
        full_local := '0';
        empty <= '1';
        full <= '0';
      else
        next_rptr := rptr;
        next_wptr := wptr;
        -- read first
        if read_en = '1' and empty_local = '0' then
          next_rptr := rotate_right(rptr);
          if next_rptr = wptr then
            empty_local := '1';
          end if;
          full_local := '0';
        end if;
        -- write next
        if write_en = '1' and full_local = '0' then
          for i in 0 to depth - 1 loop
            if wptr(i) = '1' then
              f(i) <= din;
            end if;
          end loop;
          next_wptr := rotate_right(wptr);
          if next_wptr = next_rptr then
            full_local := '1';
          end if;
          empty_local := '0';
        end if;
        full <= full_local;
        empty <= empty_local;
        rptr <= next_rptr;
        wptr <= next_wptr;
      end if;
    end if;
  end process;

end architecture rtl;
