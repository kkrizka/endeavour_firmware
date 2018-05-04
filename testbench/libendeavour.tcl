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

proc endeavour_setid {newamacid efuseid idpads} {
    #3,b110, 5’b11111, 3’b111, newamacid[4:0], 4’b1111, efuseid[19:0], 3’b111, idpads[4:0], crc[7:0]
    set cmdword "110"           ;# command
    append cmdword 11111        ;# pad
    append cmdword 111          ;# pad
    append cmdword ${newamacid} ;# newamacid
    append cmdword 1111         ;# pad
    append cmdword ${efuseid}   ;# euseid
    append cmdword 111          ;# pad
    append cmdword ${idpads}    ;# idpads
    append cmdword [endeavour_crc ${cmdword}] ;# CRC
    return ${cmdword}
}
