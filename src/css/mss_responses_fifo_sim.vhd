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

--* @id $Id: mss_responses_fifo_sim.vhd 2017-06-01 cpalmiero $
--* @brief Simulation environment for MSS outgoing responses FIFO.
--* @author Christian Palmiero (palmiero@eurecom.fr)
--* @date 2017-06-01
--*

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

entity mss_responses_fifo_sim is
  generic(depth: positive := 6;
          n: positive := 20);
end entity mss_responses_fifo_sim;

architecture sim of mss_responses_fifo_sim is

  signal clk, srstn, ce, mss_bready, mss_rready, hst_bready, hst_rready: std_ulogic;
  signal ack: natural range 0 to depth;
  signal rsp_out, mss2rsp: axi4lite_response_type;
  signal eos: boolean := false;

begin

  rf: entity work.mss_responses_fifo(rtl)
    generic map(depth => depth)
    port map(clk          => clk,
             srstn        => srstn,
             ce           => ce,
             mss2rsp      => mss2rsp,
             hst_bready   => hst_bready,
             hst_rready   => hst_rready,
             mss_bready   => mss_bready,
             mss_rready   => mss_rready,
             rsp_out      => rsp_out,
             ack          => ack);
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
    srstn      <= '0';
    ce     	   <= '1';
    hst_bready <= '1';
    hst_rready <= '1';
    mss2rsp    <= axi4lite_response_none;
    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    srstn <= '1';
    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    -- READ RESPONSES
    hst_bready <= '0';
    hst_rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        mss2rsp <= axi4lite_response_rnd;
        mss2rsp.r_data.rvalid <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    hst_bready <= '0';
    hst_rready <= '1';
    for i in 1 to n loop
      if ack /= 0 then
        mss2rsp <= axi4lite_response_rnd;
        mss2rsp.r_data.rvalid <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    hst_bready <= '1';
    hst_rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        mss2rsp <= axi4lite_response_rnd;
        mss2rsp.r_data.rvalid <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    -- WRITE RESPONSES
    hst_bready <= '0';
    hst_rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        mss2rsp <= axi4lite_response_rnd;
        mss2rsp.w_resp.bvalid <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    hst_bready <= '0';
    hst_rready <= '1';
    for i in 1 to n loop
      if ack /= 0 then
        mss2rsp <= axi4lite_response_rnd;
        mss2rsp.w_resp.bvalid <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    hst_bready <= '1';
    hst_rready <= '0';
    for i in 1 to n loop
      if ack /= 0 then
        mss2rsp <= axi4lite_response_rnd;
        mss2rsp.w_resp.bvalid <= '1';
      end if;
      wait until rising_edge(clk);
    end loop;

    eos <= true;
    stop;
    wait;
  end process;

end architecture sim;
