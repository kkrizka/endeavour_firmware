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
add_wave {{/tb_endeavour/inst_eos/error}}
add_wave {{/tb_endeavour/inst_eos/send}}
add_wave {{/tb_endeavour/inst_eos/nbitsin}}
add_wave {{/tb_endeavour/inst_eos/datain}}
add_wave {{/tb_endeavour/inst_eos/fsm}}
add_wave {{/tb_endeavour/inst_eos/reg_nbitsin}}
add_wave {{/tb_endeavour/inst_eos/reg_datain}}

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


set time 0.
set period 25.

add_force {/tb_endeavour/clock} {1 0ns} "0 [expr ${period}/2]ns" -repeat_every ${period}ns
add_force {/tb_endeavour/reset} {0 0ns} {1 100ns} {0 500ns}
set time 500.

# Initial values
add_force {/tb_endeavour/inst_eos/datain}  0 0ns
add_force {/tb_endeavour/inst_eos/nbitsin} 0 0ns

# Wait 512 clock cycles to reset AMAC FSM
set time [expr ${time} + 512*${period}]

# Run SETID
#3,b110, 5’b11111, 3’b111, newamacid[4:0], 4’b1111, efuseid[19:0], 3’b111, idpads[4:0], crc[7:0]
set cmdword "110"    ;# command
append cmdword 11111 ;# pad
append cmdword 111   ;# pad
append cmdword 10101 ;# newamacid
append cmdword 1111  ;# pad
append cmdword [string repeat 1 20] ;# euseid
append cmdword 111   ;# pad
append cmdword 00000 ;# idpads

proc endeavour_crc {word} {
    set revword [string reverse ${word}]
    set crc ""
    for {set i 7} {${i} >=0 } {incr i -1} {
	puts "bit i = ${i}"
	set crcbit [expr [string index ${revword} [expr 8*0+${i}]] ^ \
		    [string index ${revword} [expr 8*1+${i}]] ^ \
		    [string index ${revword} [expr 8*2+${i}]] ^ \
		    [string index ${revword} [expr 8*3+${i}]] ^ \
		    [string index ${revword} [expr 8*4+${i}]] ^ \
		    [string index ${revword} [expr 8*5+${i}]]]
	append crc ${crcbit}
    }
    return ${crc}
}

append cmdword [endeavour_crc ${cmdword}] ;# CRC
puts ${cmdword}

add_force {/tb_endeavour/inst_eos/datain}  ${cmdword} ${time}ns
add_force {/tb_endeavour/inst_eos/nbitsin} -radix dec [string length ${cmdword}] ${time}ns
add_force {/tb_endeavour/inst_eos/send} 1 ${time}ns -cancel_after [expr ${time} + ${period}]
