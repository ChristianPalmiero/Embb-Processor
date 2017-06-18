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

--* @id $Id: requests_fifo_sim.vhd 5044 2013-06-14 10:27:18Z rpacalet $
--* @brief Simulation environment for incoming requests FIFO.
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2011-07-18
--*
--* Changes log
--* - 2017-03-01 by Christian Palmiero (palmiero@eurecom.fr): 
--* - requests_fifo_sim has been redesigned (from VCI to AXI4Lite)

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

entity requests_fifo_sim is
  generic(rsp_depth: positive := 6;
	  depth: positive := 3;
          n: positive := 50);
end entity requests_fifo_sim;

architecture sim of requests_fifo_sim is

  signal clk, srstn, ce, ack, err, awready, wready, arready: std_ulogic;
  signal req_in: axi4lite_request_type;
  signal ack_rsp: natural range 0 to rsp_depth;
  signal req2ctrl: req2ctrl_type;
  signal eos: boolean := false;

begin

  rf: entity work.requests_fifo(rtl)
    generic map(rsp_depth => rsp_depth,
		depth => depth)
    port map(clk     => clk,
             srstn   => srstn,
             ce      => ce,
             req_in  => req_in,
             ack_rsp => ack_rsp,
             ack     => ack,
             req2ctrl=> req2ctrl,
             err     => err,
             awready => awready,
             wready  => wready,
             arready => arready);
             
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
    ack    <= '1';
    ack_rsp <= rsp_depth;
    req_in <= axi4lite_request_none;
    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;
    wait for 2 ns;
    srstn <= '1';
    for i in 1 to 10 loop
      wait until rising_edge(clk);
    end loop;

    req_in <= axi4lite_request_rnd;

    -- WRITE
    for i in 1 to n loop
      if (req_in.w_addr.awvalid='1' and awready='1') or
         (req_in.w_data.wvalid='1' and wready='1') or
         (req_in.r_addr.arvalid='1' and arready='1') then
        req_in <= axi4lite_request_rnd;
        req_in.w_addr.awvalid <= '1';
        req_in.w_addr.awaddr <= x"000FFF00";
        req_in.r_addr.arvalid <= '0';
        req_in.w_data.wvalid <= '1';
      end if;
      ack <= std_ulogic_rnd;
      wait until rising_edge(clk);
      wait for 2 ns;
    end loop;
    
    -- READ
    for i in 1 to n loop
      if (req_in.w_addr.awvalid='1' and awready='1') or
         (req_in.w_data.wvalid='1' and wready='1') or
         (req_in.r_addr.arvalid='1' and arready='1') then
        req_in <= axi4lite_request_rnd;
        req_in.w_addr.awvalid <= '0';
        req_in.r_addr.araddr <= x"000FFF00";
        req_in.r_addr.arvalid <= '1';
        req_in.w_data.wvalid <= '0';
      end if;
      ack <= std_ulogic_rnd;
      wait until rising_edge(clk);
      wait for 2 ns;
    end loop;
    
    -- READ AND WRITE
    for i in 1 to n loop
      if (req_in.w_addr.awvalid='1' and awready='1') or
         (req_in.w_data.wvalid='1' and wready='1') or
         (req_in.r_addr.arvalid='1' and arready='1') then
        req_in <= axi4lite_request_rnd;
        req_in.w_addr.awvalid <= '1';
        req_in.w_addr.awaddr <= x"000FFF00";
        req_in.r_addr.arvalid <= '1';
        req_in.r_addr.araddr <= x"000FFF00";
        req_in.w_data.wvalid <= '1';
      end if;
      ack <= std_ulogic_rnd;
      wait until rising_edge(clk);
      wait for 2 ns;
    end loop;
    
    -- BEHAVIOUR OF READY SIGNALS
    for i in 1 to n loop
      if (req_in.w_addr.awvalid='1' and awready='1') or
         (req_in.w_data.wvalid='1' and wready='1') or
         (req_in.r_addr.arvalid='1' and arready='1') then
        req_in <= axi4lite_request_rnd;
        req_in.w_addr.awvalid <= '1';
        req_in.w_addr.awaddr <= x"000FFF00";
        req_in.r_addr.arvalid <= '0';
        req_in.w_data.wvalid <= '0';
      end if;
      if i = 50 then
        req_in.w_data.wvalid <= '1';
      end if;
      ack <= std_ulogic_rnd;
      wait until rising_edge(clk);
      wait for 2 ns;
    end loop;
    
    -- BEHAVIOUR OF READY SIGNALS
    for i in 1 to n loop
      if (req_in.w_addr.awvalid='1' and awready='1') or
         (req_in.w_data.wvalid='1' and wready='1') or
         (req_in.r_addr.arvalid='1' and arready='1') then
        req_in <= axi4lite_request_rnd;
        req_in.w_addr.awvalid <= '0';
        req_in.r_addr.arvalid <= '0';
        req_in.w_data.wvalid <= '1';
      end if;
      ack <= std_ulogic_rnd;
      wait until rising_edge(clk);
      wait for 2 ns;
    end loop;

    req_in <= axi4lite_request_none;
    eos <= true;
    stop;
  end process;

end architecture sim;
