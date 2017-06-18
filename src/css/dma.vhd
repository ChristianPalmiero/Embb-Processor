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

--* @id $Id: dma.vhd 5288 2013-07-31 10:38:05Z cerdan $
--* @brief Direct Memory Access
--* @author Sebastien Cerdan (sebastien.cerdan@telecom-paristech.fr)
--* @date 2011-07-26
--*
--* This module performs memory transferts. It is in 
--* charge of AXI or MSS commands and  stores input responses in 
--* its local fifo. Module "shifter" shifts data before  
--* sending them either on AXI bus or in MSS.
--*
--* Changes log
--* 
--* 2017-05-01 by Christian Palmiero (palmiero@eurecom.fr): DMA interconnection with the host system has been redesigned (from VCI to AXI4Lite)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library global_lib;
use global_lib.global.all;
use global_lib.utils.all;
use global_lib.axi4lite_pkg.all;

use work.css_pkg.all;
use work.dma_pkg.all; -- defines the DMA engine component and register bit definitions


entity dma is
  generic(n0: positive;  --* Number of input pipeline registers of MSS
          n1: positive); --* Number of output pipeline registers of MSS
  port(clk:      in  std_ulogic;
       ctrl2dma: in  ctrl2dma_type;
       dma2ctrl: out dma2ctrl_type;
       mss2dma:  in  mss2dma_type;
       dma2mss:  out dma2mss_type;
       axi_in:   in  axi4lite_s2m_type;
       axi_out:  out axi4lite_m2s_type);
end entity dma;

architecture rtl of dma is
 
  signal shifti : shift_in_type;
  signal shifto : shift_out_type;
  signal freqi : fifo_req_in;
  signal freqo : fifo_req_out;
  signal frspi : fifo_rsp_in;
  signal frspo : fifo_rsp_out;
  
  constant np : natural := n0 + n1;

  signal stagea : stagea_v(np - 1 downto 0);

  signal rreq : req_type;
  signal wreq : req_type;
  signal rrsp, rrspin : rsp_type;
  signal wrsp, wrspin : rsp_type;
  signal ack : ack_type;

  signal rrsp_data : std_ulogic_vector(8 * axi4lite_data - 1 downto 0);
  signal mssrdata : std_ulogic_vector(8 * axi4lite_data - 1 downto 0);
  signal mssrdatain : std_ulogic_vector(8 * axi4lite_data - 1 downto 0);

  signal eop, eor, err : std_ulogic; 
  signal sym : std_ulogic; 
  signal axic, axir : axi4lite_request_type;
  signal mssc, mssr : dma2mss_type;
  
  signal rcnt, wcnt: u_unsigned(15 downto 0);
  signal start : std_ulogic;
  signal gcntin, gcntr : integer range 0 to (rsp_depth + req_depth);

begin

  rsp_fifo: entity global_lib.fifo 
  generic map(
    depth  =>  rsp_depth,
    width  =>  66)
  port map (
    srstn    =>  ctrl2dma.srstn, 
    clk      =>  clk,
    read_en  =>  frspi.enr,
    write_en =>  frspi.enw,  
    din      =>  frspi.din,
    dout     =>  frspo.dout, 
    empty    =>  frspo.empty,
    full     =>  frspo.full
  );

  req_fifo: entity global_lib.fifo 
  generic map(
    depth  =>  req_depth,
    width  =>  65)
  port map (
    srstn    =>  ctrl2dma.srstn, 
    clk      =>  clk,
    read_en  =>  freqi.enr,
    write_en =>  freqi.enw,  
    din      =>  freqi.din,
    dout     =>  freqo.dout, 
    empty    =>  freqo.empty,
    full     =>  freqo.full
  );

  shift : entity work.shifter
    port map (
      clk      =>  clk,
      srstn    =>  ctrl2dma.srstn, 
      ce       =>  ctrl2dma.ce, 
      shifti   =>  shifti,
      shifto   =>  shifto
      );

  -- Output request
  axi_out.axi4lite_request <= axic;
  dma2mss <= mssc;
  -- Fifos input signals
  freqi.enr <= ack.wreq and not freqo.empty;	
  freqi.enw <= shifto.ds and not freqo.full;	
  freqi.din <= shifto.eop & shifto.dout;
  frspi.din <= eor & eop & rrsp_data;
  frspi.enw <= ack.rrsp and not frspo.full;
  frspi.enr <= not freqo.full and not frspo.empty;
  -- Shifter input signals
  shifti.eop <= frspo.dout(8 * axi4lite_data);
  shifti.eor <= frspo.dout(8 * axi4lite_data + 1);
  shifti.start <= start;
  shifti.value <= wcnt;
  shifti.src <= ctrl2dma.src(2 downto 0);
  shifti.dst <= ctrl2dma.dst(2 downto 0);
  shifti.din <= frspo.dout(8 * axi4lite_data - 1 downto 0);
  shifti.ack <= not freqo.full;
  shifti.ds <= not frspo.empty;

  start_p: process(clk)

    variable rtmp, wtmp : u_unsigned(18 downto 0);
    variable rval, wval: u_unsigned(15 downto 0);

  begin

    if rising_edge (clk) then
      if ctrl2dma.srstn = '0' then
        start <= '0'; 
        rcnt <= (others => '0');
        wcnt <= (others => '0');
        rrsp <= rsp_none;
        wrsp <= rsp_none;
      elsif ctrl2dma.ce = '1' then
        rrsp <= rrspin;
        wrsp <= wrspin;
        start <= '0';
        wval := get_cnt(ctrl2dma.dst, ctrl2dma.lenm1); 
        rval := get_cnt(ctrl2dma.src, ctrl2dma.lenm1); 
        if (ctrl2dma.exec = '1') then
          start <= '1';    
          rcnt <= rval;
          wcnt <= wval;
        end if;
        if start = '1' then 
          -- Initialise registers
          rrsp <= init_rsp(rcnt); 
          wrsp <= init_rsp(wcnt); 
        end if;
      end if;
    end if;

  end process start_p;

  rsp_cnt_p : process(mssc, mss2dma, axi_in, rrsp, wrsp, ack, gcntr, rreq)

    variable r, w : rsp_type;
    variable veor, veop : std_ulogic;
    variable gcnt : integer range 0 to (rsp_depth + req_depth + 2);

  begin

    dma2ctrl <= dma2ctrl_none;  

    r := rrsp;
    w := wrsp;

    err <= '0';
    veor := '0';
    veop := '0';
    gcnt := gcntr;

    if ack.rreq = '1' then
    -- A read command was sent
      if ack.rrsp = '0' then
        gcnt := gcntr + 1;
      end if;
    else
      if ack.rrsp = '1' then
      -- A read response was received
        if gcntr /= 0 then  
          gcnt := gcntr - 1;
        end if;
        if gcnt = 0 and rreq.run = '0' then 
          -- All request has been sent
          veop := '1';
        end if;     
      end if;
    end if;
 
    if ack.wrsp = '1' then
      w.cnt := w.cnt - 1;
      if wrsp.cnt = 0 then
        dma2ctrl.eot <= '1';
      end if;
    end if;
    if ack.rrsp = '1' then
      r.cnt := r.cnt - 1;
      if rrsp.cnt = 0 then
        veor := '1';
      end if;
    end if;

    if mssc.en = '1' then 
      if mss2dma.oor = '1' then
        -- mss out of range error
        dma2ctrl.eot <= '1';
        dma2ctrl.err <= '1';
        dma2ctrl.status(status_type'left) <= '1';
        err <= '1';
      end if;   
    end if;
    if axi_in.axi4lite_response.r_data.rvalid = '1' then 
      if axi_in.axi4lite_response.r_data.rresp(1) = '1' then
        -- AXI transaction error
        dma2ctrl.eot <= '1';
        dma2ctrl.err <= '1';
        dma2ctrl.status(axi4lite_resp-1 downto 0) <= axi_in.axi4lite_response.r_data.rresp;
        err <= '1';
      end if;
    elsif axi_in.axi4lite_response.w_resp.bvalid = '1' then 
      if axi_in.axi4lite_response.w_resp.bresp(1) = '1' then
        -- AXI transaction error
        dma2ctrl.eot <= '1';
        dma2ctrl.err <= '1';
        dma2ctrl.status(axi4lite_resp-1 downto 0) <= axi_in.axi4lite_response.w_resp.bresp;
        err <= '1';
      end if;
    end if;

    if veor = '1' then 
      veop := '0';
    end if;

    eor <= veor;
    eop <= veop;
    rrspin <= r;
    wrspin <= w;
    gcntin <= gcnt;  

  end process; 

  process(axic, mssc, ctrl2dma, axi_in, mss2dma) 
  begin
    ack.rreq  <= '0';
    ack.wreq  <= '0';
    ack.ridle <= '0';
    ack.widle <= '0';
    if ctrl2dma.ls = '0' then 
      -- AXI READ 
      ack.rreq  <= axic.r_addr.arvalid and axi_in.arready;
      ack.ridle <= not axic.r_addr.arvalid or axi_in.arready;
    else
      -- MSS READ 
      if mssc.en = '1' and mss2dma.gnt = mssc.be and mssc.rnw = '1' then 
        ack.rreq <= '1';
      end if;
      if mssc.en = '0' or mss2dma.gnt = mssc.be then 
        ack.ridle <= '1';
      end if;
    end if;
    if ctrl2dma.ld = '0' then 
      -- AXI WRITE 
      ack.wreq  <= axic.w_addr.awvalid and axi_in.awready and axic.w_data.wvalid and axi_in.wready;
      ack.widle <= not (axic.w_addr.awvalid and axic.w_data.wvalid) or (axi_in.awready and axi_in.wready);
    else
      -- MSS WRITE 
      if mssc.en = '1' and mss2dma.gnt = mssc.be and mssc.rnw = '0' then 
        ack.wreq <= '1';
      end if;
      if mssc.en = '0' or mss2dma.gnt = mssc.be then 
        ack.widle <= '1';
      end if;
    end if;
  end process;
 
  sym_p : process(ctrl2dma)
  begin
    sym <= '0';
    if ctrl2dma.ld = ctrl2dma.ls then
    -- Symetrical transfert 
      if ctrl2dma.cs = '0' then
        sym <= '1';
      end if;
    end if;
  end process;

  req_p : process(clk)

    variable r : req_type;
    variable w : req_type;
    variable run : std_ulogic;

  begin

    if rising_edge (clk) then
      if ctrl2dma.srstn = '0' then
        r := req_none;
        w := req_none;
        rreq <= req_none;
        wreq <= req_none;
        axir <= axi4lite_request_none;
        mssr <= dma2mss_none;
      elsif ctrl2dma.ce = '1' then 
        if start = '1' then   
          run := not sym;   
          w := init_req(ctrl2dma.dst, ctrl2dma.lenm1(2 downto 0), wcnt, run);
          run := not ctrl2dma.cs;   
          r := init_req(ctrl2dma.src, ctrl2dma.lenm1(2 downto 0), rcnt, run);
        end if;
        if ack.wreq = '1' then  
          w.first := '0'; 
          -- Write counter management
          w.cnt := w.cnt - 1;
          -- Adress management
          if ctrl2dma.fd = '0' then 
            w.addr := w.addr + 1;
          end if;
          if wreq.cnt = 1 then 
            w.last := '1';
          end if;
          if wreq.cnt = 0 then 
            w.run := '0';
          end if;
          if sym = '1' then
            if freqo.dout(8 * axi4lite_data) = '1' then
            -- End of packet 
              r.run := '1';
              w.run := '0';
            end if;
          end if;
        end if;
        if ack.widle = '1' then 
        -- No pending write
          w.be := mux_be(w.one, w.first, w.last, ctrl2dma.be, w.fbe, w.lbe);
          w.eop := is_eop(w.one, w.last);
        else
        -- A request is pending
          if ctrl2dma.ld = '1' then 
            w.be := w.be and not (mss2dma.gnt);
          end if;
        end if;
        -- Read management
        if ack.rreq = '1' then  
        -- Read counter management
          r.cnt := r.cnt - 1;
          r.first := '0'; 
          -- Adress management
          if ctrl2dma.fs = '0' then 
            r.addr := r.addr + 1;
          end if;
          if frspi.enr = '0' then 
          -- Fifo write only
            r.fcnt := r.fcnt + 1;
          end if;
          if rreq.cnt = 1 then 
            r.last := '1';
          end if;
          if rreq.cnt = 0 then 
            r.run := '0';
            r.eor := '1';
            w.run := '1';
          end if;
          if r.fcnt = rsp_depth then 
            r.run := '0';
            if sym = '1' then
              w.run := '1';
            end if;
          end if;
        else
          -- Fifo read only
          if frspi.enr = '1' then 
            r.fcnt := r.fcnt - 1;
            if sym = '0' and r.eor = '0' then
              if r.fcnt < rsp_depth then 
                r.run := '1';
              end if;
            end if;
          end if;
        end if;
        if ack.ridle = '1' then 
        -- No pending read
          r.be := mux_be(r.one, r.first, r.last, ctrl2dma.be, r.fbe, r.lbe);
          r.eop := is_eop(r.one, r.last);
        else
        -- A request is pending
          if ctrl2dma.ls = '1' then 
            r.be := r.be and not (mss2dma.gnt);
          end if;
        end if;
        if err = '1' then 
          r := req_none;
          w := req_none;
        end if;
        rreq <= r;
        wreq <= w;
        -- Mux to send "r" and "w" either on AXI or MSS
        mssr <= dma2mss_none;
        axir <= axi4lite_request_none;
        if r.run = '1' then 
          mux_req(r, axir, mssr, '1', ctrl2dma.ls);
        end if;
        if w.run = '1' then 
          mux_req(w, axir, mssr, '0', ctrl2dma.ld);
        end if;
      end if;
    end if;
  end process;
 
  req_out_p : process(ctrl2dma, freqo, mssr, axir)
 
    variable wdata : std_ulogic_vector(8*axi4lite_data - 1 downto 0);

  begin

    mssc <= mssr;
    axic <= axir;

    -- Write data management
    if ctrl2dma.cs = '1' then
      wdata := set_value(ctrl2dma.cst, ctrl2dma.dst(2 downto 0));
    else
      wdata := freqo.dout(63 downto 0);
    end if;

    mssc.wdata <= wdata;
    axic.w_data.wdata <= wdata;

    if mssr.rnw = '1' then
      mssc.wdata <= (others => '0');
    end if;
    if axir.w_data.wvalid = '0' and axir.w_addr.awvalid = '0' and axir.r_addr.arvalid = '1' then
      -- Read
      axic.w_data.wdata <= (others => '0');
    end if;

    if ctrl2dma.cs = '0' then 
      if mssr.rnw = '0' then
        mssc.en <= mssr.en and not freqo.empty;
      end if;
      if axir.w_data.wvalid = '1' and axir.w_addr.awvalid = '1' and axir.r_addr.arvalid = '0' then  
        -- Write
        axic.w_data.wvalid  <= not freqo.empty;
        axic.w_addr.awvalid <= not freqo.empty;
      end if;
    end if;

  end process;

  process(frspo)
  begin
    axi_out.rready <= not frspo.full;
    axi_out.bready <= not frspo.full;
  end process;

  rsp_p : process(frspo, stagea, ctrl2dma, axi_in, mssrdatain)
  
  begin
    ack.rrsp  <= '0';
    ack.wrsp  <= '0';
    if ctrl2dma.ld = '0' then 
      -- AXI WRITE 
      ack.wrsp  <= axi_in.axi4lite_response.w_resp.bvalid;
    else
      -- MSS WRITE 
      ack.wrsp  <= stagea(np - 1).ack and not stagea(np - 1).rnw;
    end if;
    if ctrl2dma.ls = '0' then 
      -- AXI READ 
      ack.rrsp  <= axi_in.axi4lite_response.r_data.rvalid and not frspo.full;
      rrsp_data <= axi_in.axi4lite_response.r_data.rdata;
    else
      -- MSS READ 
      ack.rrsp  <= stagea(np - 1).ack and stagea(np - 1).rnw;
      rrsp_data <= mssrdatain;
    end if;

  end process;

  mss_response_p : process(clk)
  begin
    if rising_edge (clk) then
      if ctrl2dma.srstn = '0' then 
        stagea <= (others => stagea_none);
        mssrdata <= (others => '0');
        gcntr <= 0;
      elsif ctrl2dma.ce = '1' then

        mssrdata <= mssrdatain;
        gcntr <= gcntin;
 
        stagea(0).ack  <= '0'; 
        if mssc.en = '1' then 
          if mss2dma.gnt = mssc.be then 
            stagea(0).ack  <= '1'; 
          end if;
        end if;

        stagea(0).gnt  <= mss2dma.gnt;
        stagea(0).rnw  <= mssc.rnw;
        stagea(0).en   <= mssc.en;
         
        for i in np - 1 downto 1 loop
          stagea(i) <= stagea(i - 1);
        end loop;
          
      end if;
    end if;
  end process;
  
  mssrdatain_p : process(mssrdata, mss2dma, stagea)
    variable rdata : std_ulogic_vector(8*axi4lite_data-1 downto 0);
  begin

    rdata := mssrdata;

    if stagea(np - 1).en = '1' then 
      for i in 0 to axi4lite_data - 1 loop
        if stagea(np - 1).gnt(axi4lite_data - 1 - i) = '1' then 
            rdata(63 - i * 8 downto 56 - i * 8) := mss2dma.rdata(63 - i * 8 downto 56 - i * 8);
        end if;
      end loop;
    end if;
  
    mssrdatain <= rdata;

  end process;

end architecture rtl;
