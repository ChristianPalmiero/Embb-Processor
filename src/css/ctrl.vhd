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

--* @id $Id: ctrl.vhd 5044 2013-06-14 10:27:18Z rpacalet $
--* @brief Configuration and status registers
--* @author Renaud Pacalet (renaud.pacalet@telecom-paristech.fr)
--* @date 2011-07-26
--*
--*  Special read-write actions:
--* - writing in DGOST: launch DMA if (not DGOST.DBSY) or EOT (End Of Transfer), else set DGOST.DRQP
--* - writing in PGOST: launch PSS if (not PGOST.PBSY) or EOC (End Of Computation), else set PGOST.PRQP
--* - UC writing in IRQ (set IRQ.U2HIRQ)
--* - host writing in IRQ (set IRQ.H2UIRQ)
--* - UC reading in IRQ (clear IRQ.H2UIRQ, IRQ.P2UIRQ and IRQ.D2UIRG flags)
--* - host reading in IRQ (clear IRQ.U2HIRQ, IRQ.P2HIRQ and IRQ.D2HIRG flags)
--* Other special actions:
--* - PSS EOC (End Of Computation):
--*   - if PGOST.PRQP and simultaneous write access to PGOST, launch processing
--*   - if PGOST.PRQP and no simultaneous write access to PGOST, launch processing and clear PGOST.PRQP
--*   - if not PGOST.PRQP and simultaneous write access to PGOST, launch processing
--*   - if not PGOST.PRQP and no simultaneous write access to PGOST, clear PGOST.PBSY
--*   - set IRQ.P2UIRQ and IRQ.P2HIRQ
--* - DMA EOT (End Of Transfer):
--*   - if DGOST.DRQP and simultaneous write access to DGOST, launch processing
--*   - if DGOST.DRQP and no simultaneous write access to DGOST, launch processing and clear DGOST.DRQP
--*   - if not DGOST.DRQP and simultaneous write access to DGOST, launch processing
--*   - if not DGOST.DRQP and no simultaneous write access to DGOST, clear DGOST.DBSY
--*   - set IRQ.D2UIRQ and IRQ.D2HIRQ
--* - UC not in debug mode and UC fully enabled interrupt raised, that is,
--*     (not CTRL.UDBG) and CTRL.UIE and (not UREGS.UI) and ((CTRL.H2UIE and IRQ.H2UIRQ) or (CTRL.P2UIE and IRQ.P2UIRQ) or (CTRL.D2UIE and IRQ.D2UIRQ))
--*   then, set CTRL.UCE (UC wake up on interrupts)
--* - If CTRL.UDBG and UC instruction fetch, clear CTRL.UCE (step-by-step execution in UC debug mode)
--*
--* Changes log
--* - 2011-08-30 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added generic parameters to make DMA, PSS and UC optional 
--*   - Added generic parameters for debugging
--* - 2011-09-05 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added generic parameter for level/single cycle interrupts
--* - 2012-03-15 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added end of simulation and TTY UC virtual registers
--* - 2012-09-27 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added USIG signalling register.
--* - 2012-10-16 by Renaud Pacalet (renaud.pacalet@telecom-paristech.fr):
--*   - Added extended interrupts.
--* - 2017-05-20 by Christian Palmiero (palmiero@eurecom.fr): 
--*   - Redesigned some signals from VCI to AXI4Lite

-- pragma translate_off
use std.textio.all;
-- pragma translate_on

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library global_lib;
use global_lib.global.all;
use global_lib.utils.all;
use global_lib.axi4lite_pkg.all;

use work.bitfield.all;
use work.css_pkg.all;

entity ctrl is
  generic(
-- pragma translate_off
          debug:            boolean := true;       --* Print debug information
          verbose:          boolean := false;      --* Print more debug information
          name:             string  := "DSP Unit"; --* Name of surrounding DSP Unit
-- pragma translate_on
          hst_level_interrupts: boolean := false;  --* DEPRECATED, USE FLAG CTRL.LHIRQ INSTEAD
          uc_level_interrupts:  boolean := false;  --* DEPRECATED, USE FLAG CTRL.LUIRQ INSTEAD
          n_pa_regs:        natural range 0 to 15; --* Number of 64-bits parameters registers
          pa_rmask:         std_ulogic_vector;     --* Mask of read-reserved bits in parameters registers; unset bits are reserved
          pa_wmask:         std_ulogic_vector;     --* Mask of write-reserved bits in parameters registers; unset bits are reserved
          neirq:            natural range 0 to 32 := 0; --* Number of extended interrupt requests
          with_dma:         boolean;               --* With/without DMA
          with_pss:         boolean;               --* With/without PSS
          with_uc:          boolean);              --* With/without UC
  port(clk:      in  std_ulogic;      --* Clock
       srstn:    in  std_ulogic;      --* Synchronous, active low reset
       ce:       in  std_ulogic;      --* Active high chip enable
       req2ctrl: in  req2ctrl_type;   --* Target AXI arbiter to CTRL
       ctrl2rsp: out ctrl2rsp_type;   --* CTRL to Target AXI arbiter
       hirq:     in  std_ulogic;      --* Input interrupt request from host system to UC
       uirq:     out std_ulogic;      --* Output interrupt request from UC to host system
       pirq:     out std_ulogic;      --* Output interrupt request from PSS to host system
       dirq:     out std_ulogic;      --* Output interrupt request from DMA to host system
       eirq:     out std_ulogic_vector(neirq - 1 downto 0); --* Output interrupt requests to host system
       dma2ctrl: in  dma2ctrl_type;   --* DMA engine to CTRL
       ctrl2dma: out ctrl2dma_type;   --* CTRL to DMA engine
       uca2ctrl: in  uca2ctrl_type;   --* UC arbiter to CTRL
       ctrl2uca: out ctrl2uca_type;   --* CTRL to UC arbiter
       uc2ctrl:  in  uc2ctrl_type;    --* UC to CTRL
       ctrl2uc:  out ctrl2uc_type;    --* CTRL to UC
       pss2ctrl: in  pss2css_type;     --* PSS to CTRL
       ctrl2pss: out css2pss_type;     --* CTRL to PSS (EXEC, CE, SRSTN)
       param:    out std_ulogic_vector(64 * n_pa_regs - 1 downto 0)); --* CTRL to PSS (parameters)
end entity ctrl;

architecture rtl of ctrl is

  signal regs, regs_d, regs_q: regs_type;
  signal pst_q, pst_d: pss_status_fifo_entry; -- PSS status/error FIFOs
  signal dst_q, dst_d: dma_status_fifo_entry; -- DMA status/error FIFOs
  signal ctrl2dma_local: ctrl2dma_type;
  signal ctrl2pss_local:  css2pss_type;
  signal param_local:    std_ulogic_vector(64 * n_pa_regs - 1 downto 0);
  signal ctrl2uca_exec: std_ulogic;
  signal ongoing_fast_path: boolean;

-- pragma translate_off
  signal regs_debug: bitfield_type;
  signal eos: boolean;
  signal tty: boolean;
  signal c: character;
  signal v: natural range 0 to 255;
-- pragma translate_on
  constant pa_rmask_local: std_ulogic_vector(n_pa_regs * 64 - 1 downto 0) := pa_rmask;
  constant pa_wmask_local: std_ulogic_vector(n_pa_regs * 64 - 1 downto 0) := pa_wmask;
  constant regs_rmask: regs_type := gen_mask(pa_rmask_local, bitfield_rpadmask, neirq);
  constant regs_wmask: regs_type := gen_mask(pa_wmask_local, bitfield_wpadmask, neirq);
  constant is_host_mapped: boolean_vector(0 to 31) := gen_is_host_mapped(n_pa_regs);
  constant is_uc_mapped:   boolean_vector(0 to 31) := gen_is_uc_mapped(n_pa_regs);

begin

-- pragma translate_off
  process
  begin
    assert not hst_level_interrupts
      report "THE HST_LEVEL_INTERRUPTS GENERIC PARAMETER OF CSS IS DEPRECATED, USE FLAG CTRL.LHIRQ INSTEAD"
      severity failure;
    assert not uc_level_interrupts
      report "THE UC_LEVEL_INTERRUPTS GENERIC PARAMETER OF CSS IS DEPRECATED, USE FLAG CTRL.LUIRQ INSTEAD"
      severity failure;
    wait;
  end process;
-- pragma translate_on

  param      <= param_local;

  --* Read-only copy of UC internal registers in regs
  process(uc2ctrl, regs_q)
    variable vregs: regs_type;
  begin
    vregs := regs_q;
    set_field(vregs, upc_field_def, uc2ctrl.pc);
    set_field(vregs, usp_field_def, uc2ctrl.sp);
    set_field(vregs, ua_field_def, uc2ctrl.a);
    set_field(vregs, ux_field_def, uc2ctrl.x);
    set_field(vregs, uy_field_def, uc2ctrl.y);
    set_flag(vregs, uc_field_def, uc2ctrl.c);
    set_flag(vregs, uz_field_def, uc2ctrl.z);
    set_flag(vregs, ui_field_def, uc2ctrl.i);
    set_flag(vregs, ud_field_def, uc2ctrl.d);
    set_flag(vregs, ub_field_def, uc2ctrl.b);
    set_flag(vregs, uv_field_def, uc2ctrl.v);
    set_flag(vregs, un_field_def, uc2ctrl.n);
    regs <= vregs and (regs_rmask or regs_wmask);
  end process;

  --* Combinatorial process. Updates:
  --* - responses to read-write accesses from target AXI arbiter (ctrl2rsp)
  --* - responses to read-write accesses from UC arbiter (ctrl2uca)
  --* - interrupt request to host system (eirq, uirq, pirq and dirq)
  --* - control bits and commands sent to DMA engine (ctrl2dma)
  --* - control bits and commands to PSS (ctrl2pss, param)
  --* - control bits to UC (ctrl2uc)
  --* - inputs of internal registers (pa_regs_d and cs_regs_d)
  comb_p: process(ongoing_fast_path, regs, dst_q, pst_q, req2ctrl, hirq, dma2ctrl, uca2ctrl, uc2ctrl, pss2ctrl)
    variable dma_go, pss_go, fp_go: boolean;
    variable idx: natural range 0 to 31;
    variable uc_irq, hst_irq: std_ulogic;
    variable vregs: regs_type;
    variable pst: pss_status_fifo_type;
    variable dst: dma_status_fifo_type;
    variable pop_dst, pop_pst: boolean;
    variable vwdata: axi4lite_data_type;
    variable uwdata: word64;
    variable eirq_tmp: word32;
  begin
    -- written data
    -- responses to read-write accesses from target AXI arbiter
    vregs  := regs;
    dst(0) := (st => get_field(vregs, dst_field_def), err => get_flag(vregs, derr_field_def), val => get_flag(vregs, dval_field_def));
    dst(1) := dst_q;
    pst(0) := (st => get_field(vregs, pst_field_def), err => get_flag(vregs, perr_field_def), val => get_flag(vregs, pval_field_def),
               data => get_field(vregs, pdata_field_def));
    pst(1) := pst_q;
    pop_dst := false;
    pop_pst := false;
    -- PSS to host and DMA to host interrupt flags in IRQ register are used in edge-triggered mode only
    set_flag(vregs, p2hirq_field_def, '0');
    set_flag(vregs, d2hirq_field_def, '0');
    if get_flag(vregs, lhirq_field_def) = '0' then -- If edge-triggered interrupts, clear UC to host interrupt flag
      set_flag(vregs, u2hirq_field_def, '0');
    end if;
    -- PSS to UC and DMA to UC interrupt flags in IRQ register are used in edge-triggered mode only
    set_flag(vregs, p2uirq_field_def, '0');
    set_flag(vregs, d2uirq_field_def, '0');
    if get_flag(vregs, luirq_field_def) = '0' then -- If edge-triggered interrupts, clear host to UC interrupt flag
      set_flag(vregs, h2uirq_field_def, '0');
    end if;
    -- extended interrupts
    if get_flag(vregs, leirq_field_def) = '0' then -- If edge-triggered interrupts, clear extended interrupt flags
      eirq_tmp := (others => '0');
      set_field(vregs, eirq_field_def, eirq_tmp);
    end if;
    dst_d          <= dma_status_fifo_entry_none; -- Clear spare register of DMA status/error FIFO
    pst_d          <= pss_status_fifo_entry_none; -- Clear spare register of PSS status/error FIFO
    ctrl2rsp.oor   <= '0';
    ctrl2rsp.rdata <= (others => '0');
    dma_go         := false;
    pss_go          := false;
    fp_go          := false;
    hst_irq        := '0';
    ctrl2rsp.ack   <= '1'; -- by default, acknowledge FIFO requests
    if ongoing_fast_path then -- If ongoing Fast Path
      ctrl2rsp.ack <= '0'; -- Don't acknowledge FIFO requests
    elsif req2ctrl.en = '1' then -- If FIFO request and no ongoing Fast Path
      idx := req2ctrl.add; -- Index of target register
      if not is_host_mapped(idx) then
        ctrl2rsp.oor <= '1';
      else
        if req2ctrl.rnw = '0' then -- Write request
          vwdata := mask_bytes(req2ctrl.wdata, req2ctrl.be);
          if idx = uregs_idx then -- UC registers (read-only)
            ctrl2rsp.oor <= '1';
          elsif is_written(dgo_field_def, req2ctrl) then -- DMA go-status register
            dma_go := true;
          elsif is_written(pgo_field_def, req2ctrl) then -- PSS go-status register
            pss_go := true;
          elsif idx = irq_idx then -- Interrupt status register
            hst_irq := get_flag(vwdata, h2uirq_field_def); -- host to UC software interrupt
          else -- Other writable registers
            word64_update(vregs(idx), req2ctrl.be, regs_wmask(idx), vwdata);
            if is_written(ufpo_field_def , req2ctrl) then -- Offset byte of UC peripherals register
              fp_go := true;
            end if;
            if is_written(usig_field_def , req2ctrl) and req2ctrl.be(4) = '1' then -- LSB of USIG field of UC peripherals register
              hst_irq := '1';
            end if;
-- pragma translate_off
            if is_written(eos_field_def, req2ctrl) then -- If write in EOS virtual register
              v <= to_integer(u_unsigned(get_field(vwdata, eos_field_def)));
              eos <= true;
            end if;
            if is_written(tty_field_def, req2ctrl) then -- If write in TTY virtual register
              c <= character'val(to_integer(u_unsigned(get_field(vwdata, tty_field_def))));
              tty <= true;
            end if; 
-- pragma translate_on
          end if;
        else -- Read request
          ctrl2rsp.rdata <= regs(idx) and regs_rmask(idx);
          if is_read(pgo_field_def, req2ctrl) then -- Read least significant byte of PSS status register
            pop_pst := true; -- shift FIFO
          end if;
          if is_read(dgo_field_def, req2ctrl) then -- Read least significant byte of DMA status register
            pop_dst := true; -- shift FIFO
          end if;
          if idx = irq_idx then -- Interrupt status register
            -- Clear-on-read of UC to host software interrupt, PSS interrupt and DMA interrupt
            clear_on_read(vregs, req2ctrl.be, hirq_field_def);
            -- Clear-on-read of extended interrupt requests
            clear_on_read(vregs, req2ctrl.be, eirq_field_def);
          end if;
        end if;
      end if;
    end if;

    -- responses to read-write accesses from UC arbiter
-- pragma translate_off
    eos <= false;
    tty <= false;
-- pragma translate_on
    ctrl2uca.nmi   <= '0';
    ctrl2uca.rdata <= (others => '0');
    ctrl2uca_exec  <= '0';
    ctrl2uca.bs    <= 0;
    ctrl2uca.off   <= 0;
    ctrl2uca.dst   <= 0;
    ctrl2uca.lenm1 <= 0;
    idx := uca2ctrl.add;   -- Index of target register
    if with_uc and uca2ctrl.en = '1' then -- If uca request
      if not is_uc_mapped(idx) then
        ctrl2uca.nmi <= '1';
      else
        if uca2ctrl.rnw = '0' then -- Write request
          uwdata := mask_bytes(uca2ctrl.wdata, uca2ctrl.be);
          if idx = dgost_idx then -- DMA go-status register
            dma_go := true;
          elsif idx = pgost_idx then -- PSS go-status register
            pss_go := true;
          elsif idx = irq_idx then -- Interrupt status register
            uc_irq := get_flag(uwdata, u2hirq_field_def);
          else -- Other writable registers
            word64_update(vregs(idx), uca2ctrl.be, regs_wmask(idx), uwdata);
            if is_written(ufpo_field_def, uca2ctrl) then -- Offset byte of UC peripherals register
              fp_go := true;
            end if;
            if is_written(usig_field_def, uca2ctrl) and uca2ctrl.be(4) = '1' then -- LSB of USIG field of UC peripherals register
              uc_irq := '1';
            end if;
-- pragma translate_off
            if is_written(eos_field_def, uca2ctrl) then -- If write in EOS virtual register
              v <= to_integer(u_unsigned(get_field(uwdata, eos_field_def)));
              eos <= true;
            end if;
            if is_written(tty_field_def, uca2ctrl) then -- If write in TTY virtual register
              c <= character'val(to_integer(u_unsigned(get_field(uwdata, tty_field_def))));
              tty <= true;
            end if; 
-- pragma translate_on
          end if;
        else -- Read request
          ctrl2uca.rdata <= regs(idx) and regs_rmask(idx);
          if is_read(pgo_field_def, uca2ctrl) then -- Read least significant byte of PSS status register
            pop_pst := true; -- shift FIFO
          end if;
          if is_read(dgo_field_def, uca2ctrl) then -- Read least significant byte of DMA status register
            pop_dst := true; -- shift FIFO
          end if;
          if idx = irq_idx then -- Interrupt status register
            -- Clear-on-read of host to UC software interrupt, PSS interrupt and DMA interrupt
            clear_on_read(vregs, uca2ctrl.be, uirq_field_def);
            -- Clear-on-read of extended interrupt requests
            clear_on_read(vregs, uca2ctrl.be, eirq_field_def);
          end if;
        end if;
      end if;
    end if;

    -- irq.h2uirq, irq.u2hirq and irq.eirq register update
    if with_uc and (hst_irq = '1' or hirq = '1') then
      set_flag(vregs, h2uirq_field_def, '1');
    end if;
    if with_uc and uc_irq = '1' then
      set_flag(vregs, u2hirq_field_def, '1');
    end if;
    if with_pss then
      if get_flag(regs, leirq_field_def) = '1' then
        set_field(vregs, eirq_field_def, pss2ctrl.eirq or get_field(vregs, eirq_field_def));
      else
        set_field(vregs, eirq_field_def, pss2ctrl.eirq);
      end if;
    end if;

    -- pop status FIFOs
    if pop_pst then -- Read PSS status register
      pop(pst); -- shift FIFO
    end if;
    if pop_dst then -- Read DMA status register
      pop(dst); -- shift FIFO
    end if;

    -- interrupt requests to host system (uirq, pirq, dirq and eirq)
    uirq <= '0';
    if with_uc and (get_flag(regs, hie_field_def) and get_flag(regs, u2hie_field_def)) = '1' then -- If UC-to-host interrupt enabled and host interrupts enabled
      uirq <= get_flag(regs, u2hirq_field_def);
    end if;
    pirq <= '0';
    eirq <= (others => '0');
    if with_pss and (get_flag(regs, hie_field_def) and get_flag(regs, p2hie_field_def)) = '1' then -- If PSS-to-host interrupts enabled and host interrupts enabled
      if get_flag(vregs, lhirq_field_def) = '0' then -- If edge-triggered host interrupts
        pirq <= get_flag(regs, p2hirq_field_def);
      else
        pirq <= get_flag(regs, pval_field_def);
      end if;
    end if;
    if with_pss and (get_flag(regs, hie_field_def) and get_flag(regs, e2hie_field_def)) = '1' then -- If extended-to-host interrupts enabled and host interrupts enabled
      eirq_tmp := get_field(regs, eirq_field_def) and get_field(regs, eie_field_def);
      eirq <= eirq_tmp(neirq - 1 downto 0);
    end if;
    dirq <= '0';
    if with_dma and (get_flag(regs, hie_field_def) and get_flag(regs, d2hie_field_def)) = '1' then -- If DMA-to-host interrupt enabled and host interrupts enabled
      if get_flag(vregs, lhirq_field_def) = '0' then -- If edge-triggered interrupts
        dirq <= get_flag(regs, d2hirq_field_def);
      else
        dirq <= get_flag(regs, dval_field_def);
      end if;
    end if;

    -- DMA engine. This behaviour assumes a fair use of DMA: DMA requests from UC or host are silently discarded if they arrive while a DMA request is already
    -- pending.
    ctrl2dma_local <= ctrl2dma_none;
    if with_dma then
      ctrl2dma_local.srstn <= get_flag(regs, drst_field_def);
      ctrl2dma_local.ce    <= get_flag(regs, dce_field_def);
      if get_flag(regs, drst_field_def) = '0' then -- If DMA reset
        set_flag(vregs, dbsy_field_def, '0'); -- Clear DMA busy flag
        set_flag(vregs, drqp_field_def, '0'); -- Clear DMA request pending flag
      elsif get_flag(regs, dce_field_def) = '0' then -- If DMA disabled
        if dma_go then -- DMA request from UC or host
          set_flag(vregs, drqp_field_def, '1');    -- Set DMA request pending flag
        end if;
      else -- If DMA enabled and not reset
        if get_flag(regs, dbsy_field_def) = '0' then -- If DMA not busy
          if get_flag(regs, drqp_field_def) = '1' or dma_go then -- If DMA request pending (x)or DMA request from UC or host
            ctrl2dma_local.exec <= '1'; -- Go
            set_flag(vregs, dbsy_field_def, '1'); -- Set DMA busy flag
            set_flag(vregs, drqp_field_def, '0'); -- Clear DMA request pending flag
          end if;
        elsif dma2ctrl.eot = '1' then -- If DMA busy and end of current DMA transfer
          if get_flag(regs, drqp_field_def) = '1' or dma_go then -- If DMA request pending (x)or DMA request from UC or host
            ctrl2dma_local.exec <= '1'; -- Go
            set_flag(vregs, drqp_field_def, '0'); -- Clear DMA request pending flag
          else -- No DMA request pending nor DMA request from UC or host
            set_flag(vregs, dbsy_field_def, '0'); -- Clear DMA busy flag
          end if;
          if get_flag(vregs, lhirq_field_def) = '0' then -- If edge-triggered interrupts
            set_flag(vregs, d2hirq_field_def, '1'); -- Raise interrupt to host
          end if;
          if get_flag(vregs, luirq_field_def) = '0' then -- If edge-triggered interrupts
            set_flag(vregs, d2uirq_field_def, '1'); -- Raise interrupt to UC
          end if;
          -- Push new return status in DMA statuses FIFO
          push(dst, (st => dma2ctrl.status, err => dma2ctrl.err, val => '1'));
        elsif dma_go then -- DMA busy, no end of current DMA transfer but DMA request from UC or host
          set_flag(vregs, drqp_field_def, '1'); -- Set DMA request pending flag
        end if;
      end if;
      ctrl2dma_local.ls    <= get_flag(regs, dls_field_def);
      ctrl2dma_local.ld    <= get_flag(regs, dld_field_def);
      ctrl2dma_local.fs    <= get_flag(regs, dfs_field_def);
      ctrl2dma_local.fd    <= get_flag(regs, dfd_field_def);
      ctrl2dma_local.cs    <= get_flag(regs, dcs_field_def);
      ctrl2dma_local.be    <= get_field(regs, dbe_field_def);
      ctrl2dma_local.lenm1 <= get_field(regs, dlenm1_field_def);
      ctrl2dma_local.cst   <= get_field(regs, dcsth_field_def) & get_field(regs, dcstl_field_def);
      ctrl2dma_local.src   <= get_field(regs, dsrc_field_def);
      ctrl2dma_local.dst   <= get_field(regs, ddst_field_def);
    end if;

    -- PSS processing core. This behaviour assumes a fair use of PSS: PSS requests from UC or host are silently discarded if they arrive while a PSS request is
    -- already pending.
    ctrl2pss_local <= css2pss_none;
    param_local   <= (others => '0');
    if with_pss then
      ctrl2pss_local.srstn <= get_flag(regs, prst_field_def);
      ctrl2pss_local.ce    <= get_flag(regs, pce_field_def);
      for i in 0 to n_pa_regs - 1 loop
        param_local(64 * i + 63 downto 64 * i) <= regs(i);
      end loop;
      if get_flag(regs, prst_field_def) = '0' then -- If PSS reset
        set_flag(vregs, pbsy_field_def, '0'); -- Clear PSS busy flag
        set_flag(vregs, prqp_field_def, '0'); -- Clear PSS request pending flag
      elsif get_flag(regs, pce_field_def) = '0' then -- If PSS disabled
        if pss_go then -- PSS request from UC or host
          set_flag(vregs, prqp_field_def, '1');    -- Set PSS request pending flag
        end if;
      else -- If PSS enabled and not reset
        if get_flag(regs, pbsy_field_def) = '0' then -- If PSS not busy
          if get_flag(regs, prqp_field_def) = '1' or pss_go then  -- If PSS request pending (x)or PSS request from UC or host
            ctrl2pss_local.exec <= '1';  -- Go
            set_flag(vregs, pbsy_field_def, '1'); -- Set PSS busy flag
            set_flag(vregs, prqp_field_def, '0'); -- Clear PSS request pending flag
          end if;
        elsif pss2ctrl.eoc = '1' then -- If PSS busy and end of current PSS operation
          if get_flag(regs, prqp_field_def) = '1' or pss_go then -- If PSS request pending (x)or PSS request from UC or host
            ctrl2pss_local.exec <= '1';  -- Go
            set_flag(vregs, prqp_field_def, '0'); -- Clear PSS request pending flag
          else
            set_flag(vregs, pbsy_field_def, '0'); -- Clear PSS busy flag
          end if;
          if get_flag(vregs, lhirq_field_def) = '0' then -- If edge-triggered interrupts
            set_flag(vregs, p2hirq_field_def, '1'); -- Raise interrupt to host
          end if;
          if get_flag(vregs, luirq_field_def) = '0' then -- If edge-triggered interrupts
            set_flag(vregs, p2uirq_field_def, '1'); -- Raise interrupt to UC
          end if;
          -- Push new return status in PSS statuses FIFO
          push(pst, (st => pss2ctrl.status, err => pss2ctrl.err, val => '1', data => pss2ctrl.data));
        elsif pss_go then -- PSS busy, no end of current PSS operation but PSS request from UC or host
          set_flag(vregs, prqp_field_def, '1'); -- Set PSS request pending flag
        end if;
      end if;
    end if;

    -- Fast Path
    if with_uc then
      ctrl2uca.bs    <= to_integer(u_unsigned(get_field(regs, ufpb_field_def)));
      ctrl2uca.off   <= to_integer(u_unsigned(get_field(regs, ufpo_field_def)));
      ctrl2uca.dst   <= to_integer(u_unsigned(get_field(regs, ufpd_field_def)));
      ctrl2uca.lenm1 <= to_integer(u_unsigned(get_field(regs, ufpl_field_def)));
      if fp_go then
        ctrl2uca_exec  <= '1';
      end if;
    end if;

    -- control bits to UC (ctrl2uc)
    ctrl2uc <= ctrl2uc_none;
    if with_uc then
      ctrl2uc.srstn <= get_flag(regs, urst_field_def);
      ctrl2uc.ce    <= get_flag(regs, uce_field_def);
      uc_irq        := get_flag(regs, h2uie_field_def) and get_flag(regs, h2uirq_field_def);
      if get_flag(vregs, luirq_field_def) = '0' then -- If edge-triggered interrupts
        uc_irq      := uc_irq or (get_flag(regs, p2uie_field_def) and get_flag(regs, p2uirq_field_def));
        uc_irq      := uc_irq or (get_flag(regs, d2uie_field_def) and get_flag(regs, d2uirq_field_def));
      else
        uc_irq      := uc_irq or (get_flag(regs, p2uie_field_def) and get_flag(regs, pval_field_def));
        uc_irq      := uc_irq or (get_flag(regs, d2uie_field_def) and get_flag(regs, dval_field_def));
      end if;
      if with_pss then -- If PSS enabled, extended interrupts
        uc_irq      := uc_irq or (get_flag(regs, e2uie_field_def) and or_reduce(get_field(regs, eirq_field_def) and get_field(regs, eie_field_def)));
      end if;
      uc_irq        := uc_irq and get_flag(regs, uie_field_def);
      ctrl2uc.irq   <= uc_irq;
      uc_irq        := uc_irq and (not get_flag(regs, ui_field_def));
      if uc_irq = '1' and get_flag(regs, udbg_field_def) = '0' then -- Fully enabled and raised UC interrupt and UC not in debug mode
        set_flag(vregs, uce_field_def, '1'); -- enable UC (wake up on interrupts when not in debug mode)
      end if;
      if uc2ctrl.sync = '1' and get_flag(regs, udbg_field_def) = '1' then -- UC in sync step (instruction fetch) and UC in debug mode
        set_flag(vregs, uce_field_def, '0'); -- Halt UC.
      end if;
    end if;

    set_field(vregs, dst_field_def, dst(0).st);
    set_flag(vregs, derr_field_def, dst(0).err);
    set_flag(vregs, dval_field_def, dst(0).val);
    set_field(vregs, pst_field_def, pst(0).st);
    set_flag(vregs, perr_field_def, pst(0).err);
    set_flag(vregs, pval_field_def, pst(0).val);
    set_field(vregs, pdata_field_def, pst(0).data);
-- pragma translate_off
    set_field(vregs, eos_field_def, x"00");
    set_field(vregs, tty_field_def, x"00");
-- pragma translate_on
    regs_d <= vregs;
    dst_d  <= dst(1);
    pst_d  <= pst(1);
  end process comb_p;

  --* Registers
  regs_p: process(clk)
  begin
    if rising_edge(clk) then
      if srstn = '0' then
        regs_q <= (others => (others => '0'));
        dst_q  <= dma_status_fifo_entry_none;
        pst_q  <= pss_status_fifo_entry_none;
        ctrl2pss  <= css2pss_none;
        ctrl2dma <= ctrl2dma_none;
        ongoing_fast_path <= false;
      elsif ce = '1' then
        regs_q <= regs_d;
        dst_q  <= dst_d;
        pst_q  <= pst_d;
        ctrl2pss  <= ctrl2pss_local;
        ctrl2dma <= ctrl2dma_local;
        ctrl2uca.exec <= ctrl2uca_exec;
        if ctrl2uca_exec = '1' then   -- launch Fast Path
          ongoing_fast_path <= true;
        elsif uca2ctrl.eot = '1' then -- end of Fast Path
          ongoing_fast_path <= false;
        end if;
      end if;
    end if;
  end process regs_p;

-- pragma translate_off
  --* Debug
  debug_p: process(clk)
    variable ctrl2dma_cnt: natural := 0;
    variable dma2ctrl_cnt: natural := 0;
    variable ctrl2pss_cnt:  natural := 0;
    variable pss2ctrl_cnt:  natural := 0;
    variable l: line;
  begin
    if rising_edge(clk) then
      if srstn = '0' then
        ctrl2dma_cnt := 0;
        dma2ctrl_cnt := 0;
        ctrl2pss_cnt  := 0;
        pss2ctrl_cnt  := 0;
      else
        if debug and ctrl2dma_local.exec = '1' then
          print(ctrl2dma_local, ctrl2dma_cnt, verbose, name);
        end if;
        if debug and dma2ctrl.eot = '1' then
          print(dma2ctrl, dma2ctrl_cnt, verbose, name);
        end if;
        if debug and ctrl2pss_local.exec = '1' then
          print(ctrl2pss_local, param_local, ctrl2pss_cnt, verbose, name);
        end if;
        if debug and pss2ctrl.eoc = '1' then
          print(pss2ctrl, pss2ctrl_cnt, verbose, name);
        end if;
        if tty then -- If UC write in TTY virtual register
          if c = CR then
            writeline(output, l);
          else
            write(l, c);
          end if;
        end if;
        if eos then -- If UC write in EOS virtual register
          assert false -- Stop simulation
            report "End of simulation forced by write in EOS virtual register. Written value: " & integer'image(v)
            severity failure;
        end if;
      end if;
    end if;
  end process debug_p;

  process(regs)
    variable tmp: std_ulogic_vector(n_cs_regs * 64 - 1 downto 0);
  begin
    for i in 0 to n_cs_regs - 1 loop
      tmp(64 * i + 63 downto 64 * i) := regs(fidx2idx(i));
    end loop;
    regs_debug <= bitfield_slice(tmp);
  end process;
-- pragma translate_on

end architecture rtl;
