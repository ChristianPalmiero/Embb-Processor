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

--* @id $Id: responses_fifo_sim.vhd 5044 2013-06-14 10:27:18Z rpacalet $
--* @brief Simulation environment for outgoing responses FIFO.
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2011-07-19
--*
--* Changes log
--* - 2017-03-01 by Christian Palmiero (palmiero@eurecom.fr): 
--* - responses_fifo_sim has been redesigned (from VCI to AXI4Lite)

use std.env.all;

library ieee;
use ieee.std_logic_1164.all;

library random_lib;
use random_lib.rnd.all;

library global_lib;
use global_lib.global.all;
use global_lib.sim_utils.all;
use global_lib.axi4lite_pkg.all;

use work.css_pkg.all;

entity responses_fifo_sim is
  generic(depth: positive := 6;
          n: positive := 20);
end entity responses_fifo_sim;

architecture sim of responses_fifo_sim is

  signal clk, srstn, ce, en, rnw, err, bready, rready: std_ulogic;
  signal ack: natural range 0 to depth;
  signal ctrl2rsp: ctrl2rsp_type;
  signal rsp_out: axi4lite_response_type;
  signal eos: boolean := false;

begin

  rf: entity work.responses_fifo(rtl)
    generic map(depth => depth)
    port map(clk      => clk,
             srstn    => srstn,
             ce       => ce,
             ctrl2rsp => ctrl2rsp,
             en       => en,
             rnw      => rnw,
             err      => err,
             bready   => bready,
             rready   => rready,
             rsp_out  => rsp_out,
             ack      => ack);
  process
  begin
    clk <= '0';
    wait for 5 ns;
    clk <= '1';
    wait for 5 ns;
    if eos then
      wait;
    end if;
  end process;

  process
  begin
    srstn  <= '0';
    ce     <= '1';
    en     <= '0';
    rnw    <= '0';
    err    <= '0';
    bready <= '0';
    rready <= '0';
    ctrl2rsp <= ctrl2rsp_none;
    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    srstn <= '1';
    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    -- READ RESPONSES
    en     <= '1';
    rnw    <= '1';
    bready <= '0';
    rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        ctrl2rsp <= ctrl2rsp_rnd;
        ctrl2rsp.ack <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    bready <= '0';
    rready <= '1';
    for i in 1 to n loop
      if ack /= 0 then
        ctrl2rsp <= ctrl2rsp_rnd;
        ctrl2rsp.ack <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    bready <= '1';
    rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        ctrl2rsp <= ctrl2rsp_rnd;
        ctrl2rsp.ack <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    -- WRITE RESPONSES
    rnw    <= '0';
    bready <= '0';
    rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        ctrl2rsp <= ctrl2rsp_rnd;
        ctrl2rsp.ack <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    bready <= '0';
    rready <= '1';
    for i in 1 to n loop
      if ack /= 0 then
        ctrl2rsp <= ctrl2rsp_rnd;
        ctrl2rsp.ack <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    bready <= '1';
    rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        ctrl2rsp <= ctrl2rsp_rnd;
        ctrl2rsp.ack <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    -- WRITE RESPONSES
    err    <= '1';
    en     <= '0';
    rnw    <= std_ulogic_rnd;
    bready <= '1';
    rready <= '1';
    for i in 1 to n loop
      wait until rising_edge(clk);
    end loop;

    eos <= true;
    stop;
    wait;
  end process;

end architecture sim;
