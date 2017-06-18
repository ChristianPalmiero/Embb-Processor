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

--* @brief Simulation environment for requests/responses FIFOs.
--* @author Christian Palmiero (palmiero@eurecom.fr)

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

entity css_fifos_sim is
  generic(n_pa_regs: positive := 3;
          n: positive := 50);
end entity css_fifos_sim;

architecture sim of css_fifos_sim is

  signal clk, srstn, ce : std_ulogic;
  signal hirq           : std_ulogic;
  signal pss2css        : pss2css_type;
  signal css2pss        : css2pss_type;
  signal param          : std_ulogic_vector(n_pa_regs * 64 - 1 downto 0);
  signal mss2css        : mss2css_type;
  signal css2mss        : css2mss_type;
  signal taxi_in        : axi4lite_m2s_type;
  signal taxi_out       : axi4lite_s2m_type;
  signal maxi_in        : axi4lite_m2s_type;
  signal maxi_out       : axi4lite_s2m_type;
  signal iaxi_in        : axi4lite_s2m_type;
  signal iaxi_out       : axi4lite_m2s_type;
  signal eos            : boolean := false;
  constant pa_rmask : std_ulogic_vector := x"ffffffffffffffffffffffffffffffffffffffffffffffff";
  constant pa_wmask : std_ulogic_vector := x"ffffffffffffffffffffffffffffffffffffffffffffffff";

begin

  css: entity work.css(rtl)
    generic map(n_pa_regs   => n_pa_regs,
                pa_rmask    => pa_rmask,
                pa_wmask    => pa_wmask)
    port map(clk      => clk,
             srstn    => srstn,
             ce       => ce,
             hirq     => hirq,
             uirq     => open,
             pirq     => open,
             dirq     => open,
             eirq     => open,
             pss2css  => pss2css,
             css2pss  => css2pss,
             param    => param,
             mss2css  => mss2css,
             css2mss  => css2mss,
             taxi_in  => taxi_in,
             taxi_out => taxi_out,
             maxi_in  => maxi_in,
             maxi_out => maxi_out,
             iaxi_in  => iaxi_in,
             iaxi_out => iaxi_out);

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
    srstn   <= '0';
    ce      <= '1';
    hirq    <= '0';
    pss2css <= pss2css_none;
    mss2css <= mss2css_none;
    maxi_in <= axi4lite_m2s_none;
    taxi_in <= axi4lite_m2s_none;
    iaxi_in <= axi4lite_s2m_none;

    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;
    wait for 2 ns;
    srstn <= '1';
    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    -- WRITE
    taxi_in.axi4lite_request <= axi4lite_request_rnd;
    taxi_in.axi4lite_request.w_addr.awvalid <= '1';
    taxi_in.axi4lite_request.w_addr.awaddr <= x"000FFF00";
    taxi_in.axi4lite_request.w_data.wvalid <= '1';
    taxi_in.axi4lite_request.r_addr <= axi4lite_read_addr_none;
    taxi_in.bready <= '1';
    taxi_in.rready <= '1';
    for i in 1 to n loop
      wait until rising_edge(clk);
      wait for 2 ns;
      taxi_in.axi4lite_request <= axi4lite_request_none;
    end loop;

    -- READ
    taxi_in.axi4lite_request <= axi4lite_request_rnd;
    taxi_in.axi4lite_request.r_addr.arvalid <= '1';
    taxi_in.axi4lite_request.r_addr.araddr <= x"000FFF00";
    taxi_in.axi4lite_request.w_data <= axi4lite_write_data_none;
    taxi_in.axi4lite_request.w_addr <= axi4lite_write_addr_none;
    for i in 1 to n loop
      wait until rising_edge(clk);
      wait for 2 ns;
      taxi_in.axi4lite_request <= axi4lite_request_none;
    end loop;
    
    eos <= true;
    stop;
  end process;

end architecture sim;
