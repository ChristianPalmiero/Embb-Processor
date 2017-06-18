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

--* @id $Id: shifter.vhd 5282 2013-07-30 20:37:40Z cerdan $
--* @brief Data shifter
--* @author Sebastien Cerdan (sebastien.cerdan@telecom-paristech.fr)
--* @date 2011-07-26
--*
--*  
--* Source and destination addresses are not necessarily aligned on the same byte.
--* This module shifts input data according to shifti.src and shifti.dst input signals to otbain
--* valid data that can be written either in memory or in MSS. "shifto.ds" signal  
--* indicates that an data is ready on "shifto.dout". "shifti.ds" signal indicates that a data 
--* is ready on "shifti.din". "shifti.eor" signal indicates that no more data will be valid on 
--* "shifti.din", in this case we must flush the shifter to send remainding data if cnt 
--* is not equal to 0. "shifti.ack" signal indicates that output is ready to accept
--* new data on "shifto.dout"


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library global_lib;
use global_lib.global.all;
use global_lib.utils.all;

use work.dma_pkg.all;

entity shifter is
  port (  clk	   : in std_ulogic;
          srstn	   : in std_ulogic;
          ce       : in std_ulogic;
          shifti   : in shift_in_type; 
          shifto   : out shift_out_type 
        );
end entity shifter;

architecture rtl of shifter is

  signal rdst : u_unsigned(63 downto 0);
  signal val: std_ulogic;
  signal flush, flushr: std_ulogic;
  signal cnt : u_unsigned (15 downto 0);
  
  begin

    process(clk)

      variable src_v, dst_v, tmp : u_unsigned(127 downto 0);
      variable index_dst : integer range 0 to 7;
      variable index_src : integer range 0 to 7;
      variable v : std_ulogic_vector(1 downto 0);
      variable shift : std_ulogic;

    begin

      if(clk'event and clk='1') then
        if srstn = '0' then 
          rdst <= (others => '0');
          src_v := (others => '0');
          dst_v := (others => '0');
          cnt <= (others => '0');
          shifto.eop <= '0';
          v := (others => '0');
          flushr <= '0';
        elsif ce = '1' then 
              
          flushr <= flush;
          
          index_dst := to_integer(u_unsigned(shifti.dst(2 downto 0)));
          index_src := to_integer(u_unsigned(shifti.src(2 downto 0)));
     
          shift := shifti.ds or flush;
          
          if shifti.start = '1' then 
            rdst <= (others => '0');
            src_v := (others => '0');
            dst_v := (others => '0');
            cnt <= shifti.value + 1;
            v := (others => '0');
          end if;

          if shifti.ack = '1' then 
 
            shifto.eop <= shifti.eop and shifti.ds;

            v(1) := '0';
            if shift = '1' then  
              v := shift_left(v, 1); 
              v(0) := '1'; 
            end if;
              
            if v(1) = '1' then 
              cnt <= cnt - 1;
            end if;

            if shift = '1' then
              src_v := shift_left(src_v, 64);
              dst_v := shift_left(dst_v, 64);
              src_v(63 downto  0) := u_unsigned(shifti.din);
            end if;
 
            tmp := shift_left(src_v, index_src * vci_b);
 
            for i in 0 to 7 loop
              if i = index_dst then
                dst_v(127 - i * vci_b downto 64 - i * vci_b) := tmp(127 downto 64);
              end if;
            end loop;

          end if;

          rdst 	<= dst_v(127 downto 64);
          val   <= v(1);

        end if;
      end if;
    end process;

    flush_p : process(cnt, shifti, flushr)
    begin
      flush <= flushr;
      if shifti.eor = '1' and shifti.ds = '1' then
        if cnt /= 0 then 
          flush <= '1';
        end if;
      elsif cnt = 0 then 
        flush <= '0';
      end if;
      
   end process flush_p;
    
   shifto.ds <= val;
   shifto.dout  <= std_ulogic_vector(rdst);
    

end rtl;

