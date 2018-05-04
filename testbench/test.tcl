source libendeavour.tcl

restart

close_wave_config -force

add_wave_divider Generic
add_wave {{/tb_endeavour/clock}}
add_wave {{/tb_endeavour/reset}}
add_wave {{/tb_endeavour/resetn}}

add_wave_divider EOS
add_wave {{/tb_endeavour/inst_eos/clock}}
add_wave {{/tb_endeavour/inst_eos/reset}}
add_wave {{/tb_endeavour/inst_eos/serialin}}
add_wave {{/tb_endeavour/inst_eos/serialout}}
add_wave {{/tb_endeavour/inst_eos/busy}}
add_wave {{/tb_endeavour/inst_eos/send}}
add_wave {{/tb_endeavour/inst_eos/nbitsin}}
add_wave {{/tb_endeavour/inst_eos/datain}}
add_wave {{/tb_endeavour/inst_eos/error}}
add_wave {{/tb_endeavour/inst_eos/datavalid}}
add_wave {{/tb_endeavour/inst_eos/nbitsout}}
add_wave {{/tb_endeavour/inst_eos/dataout}}
add_wave {{/tb_endeavour/inst_eos/fsm_wr}}
add_wave {{/tb_endeavour/inst_eos/reg_nbitsin}}
add_wave {{/tb_endeavour/inst_eos/reg_datain}}
add_wave {{/tb_endeavour/inst_eos/fsm_rd}}
add_wave {{/tb_endeavour/inst_eos/reg_nbitsout}}
add_wave {{/tb_endeavour/inst_eos/reg_dataout}}

add_wave_divider AMAC 
add_wave {{/tb_endeavour/inst_amac/clk}}
add_wave {{/tb_endeavour/inst_amac/softrstb}}
add_wave {{/tb_endeavour/inst_amac/hardrstb}}
add_wave {{/tb_endeavour/inst_amac/rstb}}
add_wave {{/tb_endeavour/inst_amac/serialin}}
add_wave {{/tb_endeavour/inst_amac/serialout}}
add_wave {{/tb_endeavour/inst_amac/efuse_chipid}}
add_wave {{/tb_endeavour/inst_amac/chipid_pads}}
add_wave {{/tb_endeavour/inst_amac/din}}
add_wave {{/tb_endeavour/inst_amac/din_sync}}
add_wave {{/tb_endeavour/inst_amac/fsm}}
add_wave {{/tb_endeavour/inst_amac/ticks}}
add_wave {{/tb_endeavour/inst_amac/sreg_in}}
add_wave {{/tb_endeavour/inst_amac/sreg_shift}}
add_wave {{/tb_endeavour/inst_amac/sreg_clear}}
add_wave {{/tb_endeavour/inst_amac/sreg_cmd}}
add_wave {{/tb_endeavour/inst_amac/sreg_efuseid}}
add_wave {{/tb_endeavour/inst_amac/sreg_padid}}
add_wave {{/tb_endeavour/inst_amac/sreg_calccrc}}
add_wave {{/tb_endeavour/inst_amac/sreg_crc}}
add_wave {{/tb_endeavour/inst_amac/bitcountnp}}
add_wave {{/tb_endeavour/inst_amac/id_match}}
add_wave {{/tb_endeavour/inst_amac/setid_match}}
add_wave {{/tb_endeavour/inst_amac/crcok}}
add_wave {{/tb_endeavour/inst_amac/commid}}
add_wave {{/tb_endeavour/inst_amac/commid_known}}

add_wave_divider Reg01
#add_wave {{/tb_endeavour/inst_reg01/rstb}}
add_wave {{/tb_endeavour/inst_reg01/bclk}}
add_wave {{/tb_endeavour/inst_reg01/dataOut}}
add_wave {{/tb_endeavour/inst_reg01/shiftOut}}
add_wave {{/tb_endeavour/inst_reg01/dataIn}}
add_wave {{/tb_endeavour/inst_reg01/addrIn}}
add_wave {{/tb_endeavour/inst_reg01/latchIn}}
add_wave {{/tb_endeavour/inst_reg01/latchOut}}
add_wave {{/tb_endeavour/inst_reg01/shiftEn}}


set time 0.
set period 25.

add_force {/tb_endeavour/clock} {1 0ns} "0 [expr ${period}/2]ns" -repeat_every ${period}ns
add_force {/tb_endeavour/reset} {0 0ns} {1 100ns} {0 500ns}

# Initial values
add_force {/tb_endeavour/inst_eos/datain}  0 0ns
add_force {/tb_endeavour/inst_eos/nbitsin} 0 0ns

run [expr 512*${period}]ns

# Run SETID
set cmdword [endeavour_setid 10101 [string repeat 1 20] 00000]
add_force {/tb_endeavour/inst_eos/datain}  ${cmdword} 0ns
add_force {/tb_endeavour/inst_eos/nbitsin} -radix dec [string length ${cmdword}] 0ns
add_force {/tb_endeavour/inst_eos/send} 1 ${period}ns -cancel_after [expr 2*${period}]
run 200us

# Run WRITE
set cmdword [endeavour_write 10101 00000001 D34DB347]
add_force {/tb_endeavour/inst_eos/datain}  ${cmdword} 0ns
add_force {/tb_endeavour/inst_eos/nbitsin} -radix dec [string length ${cmdword}] 0ns
add_force {/tb_endeavour/inst_eos/send} 1 ${period}ns -cancel_after [expr 2*${period}]
run 200us

# Run READ
set cmdword [endeavour_read 10101 00000001]
add_force {/tb_endeavour/inst_eos/datain}  ${cmdword} 0ns
add_force {/tb_endeavour/inst_eos/nbitsin} -radix dec [string length ${cmdword}] 0ns
add_force {/tb_endeavour/inst_eos/send} 1 ${period}ns -cancel_after [expr 2*${period}]
run 200us
