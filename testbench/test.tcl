restart

close_wave_config -force

add_wave_divider Generic
add_wave {{/tb_endeavour/clock}}
add_wave {{/tb_endeavour/reset}}
add_wave {{/tb_endeavour/resetn}}

add_wave_divider EOS
add_wave {{/tb_endeavour/inst_eos/clock}}
add_wave {{/tb_endeavour/inst_eos/serialin}}
add_wave {{/tb_endeavour/inst_eos/serialout}}
add_wave {{/tb_endeavour/inst_eos/busy}}
add_wave {{/tb_endeavour/inst_eos/istrobe}}
add_wave {{/tb_endeavour/inst_eos/idpads}}
add_wave {{/tb_endeavour/inst_eos/efuseid}}
add_wave {{/tb_endeavour/inst_eos/amac}}
add_wave {{/tb_endeavour/inst_eos/fsm}}
add_wave {{/tb_endeavour/inst_eos/reg_nbits}}
add_wave {{/tb_endeavour/inst_eos/reg_writeword}}

add_wave_divider AMAC 
add_wave {{/tb_endeavour/inst_amac/clk}}
add_wave {{/tb_endeavour/inst_amac/serialin}}
add_wave {{/tb_endeavour/inst_amac/serialout}}
add_wave {{/tb_endeavour/inst_amac/rstb}}
add_wave {{/tb_endeavour/inst_amac/softrstb}}
add_wave {{/tb_endeavour/inst_amac/hardrstb}}
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
add_wave {{/tb_endeavour/inst_amac/bitcountnp}}
add_wave {{/tb_endeavour/inst_amac/id_match}}
add_wave {{/tb_endeavour/inst_amac/setid_match}}
add_wave {{/tb_endeavour/inst_amac/crcok}}
add_wave {{/tb_endeavour/inst_amac/commid}}
add_wave {{/tb_endeavour/inst_amac/commid_known}}


set time 0.
set period 25.

add_force {/tb_endeavour/clock} {1 0ns} "0 [expr ${period}/2]ns" -repeat_every ${period}ns
add_force {/tb_endeavour/reset} {0 0ns} {1 100ns} {0 500ns}
set time 500.

# Initial values
add_force {/tb_endeavour/inst_eos/amac}    00000 0ns
add_force {/tb_endeavour/inst_eos/istrobe} 0 0ns

# Wait 512 clock cycles to reset AMAC FSM
set time [expr ${time} + 512*${period}]

# Run SETID
add_force {/tb_endeavour/inst_eos/amac}    10101 ${time}ns
add_force {/tb_endeavour/inst_eos/istrobe} 1 ${time}ns -cancel_after [expr ${time} + ${period}]
