
puts ""
puts "Starting ELFintoBIT.tcl ..."
puts ""

# one time while loop to allow break without process exit
while { 1 } {

    # Take arguments set if called through shell script
    if { [ info exists env(ETOB_WORKSPACE) ] } {
        set clWorkspace $env(ETOB_WORKSPACE)
    } else {
        set clWorkspace ""
    }
    if { [ info exists env(ETOB_APPNAME) ] } {
        set clApp $env(ETOB_APPNAME)
    } else {
        set clApp ""
    }
    if { [ info exists env(ETOB_OUTPUT) ] } {
        set clOutput $env(ETOB_OUTPUT)
    } else {
        set clOutput ""
    }

    if { [ string length [ getws ] ] == 0 } {
        if { [ string length $clWorkspace ] == 0 } {
            setws "./"
        } else {
            setws $clWorkspace
        }
    }

    # Read Vitis project path
    set WSPATH [ getws ]

    # App project name - take first app name from app list if empty
    set APPDATA [ app list -dict ]
    if { [ string length $clApp ] == 0 } {
        set idx 0
        set idx2 [ string first " " $APPDATA 0 ]
    } else {
        # find app name as substring in app list
        set idx [ string first $clApp $APPDATA 0 ]
        set idx2 [ string first " " $APPDATA $idx ]
    }
    set APPNAME [ string range $APPDATA $idx $idx2-1 ]

    # extract domain name for app
    set didx [ string first "domain" $APPDATA $idx2 ]
    set didx2 [ string first " " $APPDATA $didx+1 ]
    set didx3 [ string first " " $APPDATA $didx2+1 ]
    set DOMNAME [ string range $APPDATA $didx2+1 $didx3-1 ]

    # extract platform name for app
    set pidx [ string first "platform" $APPDATA $didx2 ]
    set pidx2 [ string first " " $APPDATA $pidx+1 ]
    set pidx3 [ string first "\}" $APPDATA $pidx2+1 ]
    set PLATNAME [ string range $APPDATA $pidx2+1 $pidx3-1 ]

    # Set platform
    platform active $PLATNAME

    # Get processor from domain
    set DOMDATA [ domain list -dict ]

    # find domain name as substring in domain list
    set idx [ string first $DOMNAME $DOMDATA 0 ]
    set idx2 [ string first " " $DOMDATA $idx ]
    set didx [ string first "processor" $DOMDATA $idx2 ]
    set didx2 [ string first " " $DOMDATA $didx+1 ]
    set didx3 [ string first " " $DOMDATA $didx2+1 ]
    set MB_INSTANCE [ string range $DOMDATA $didx2+1 $didx3-1 ]

    set PLATHW_PATH "${WSPATH}/${PLATNAME}/hw/*.xsa"
    set result [catch { glob $PLATHW_PATH } XSA_PATH]
    if { $result != 0 } {
        puts "ERROR: No XSA_PATH found"
        puts ""
        puts "ELFintoBIT.tcl aborted."
        break
    }
    #puts "XSA_PATH       : ${XSA_PATH}"

    # extract block design instance from XSA/sysdef.xml
    set XSAGREP [ exec unzip -p ${XSA_PATH} sysdef.xml | grep DEFAULT_BD ]
    set idx [ string first "DESIGN_HIERARCHY" $XSAGREP ]
    set idx2 [ string first "\"" $XSAGREP $idx+18 ]
    set BD_INSTANCE [ string range $XSAGREP $idx+18 $idx2-1 ]

    # extract BIT file name from XSA/sysdef.xml
    set XSAGREP [ exec unzip -p ${XSA_PATH} sysdef.xml | grep BIT ]
    set idx [ string first "Name=" $XSAGREP ]
    set idx2 [ string first "\"" $XSAGREP $idx+6 ]
    set BIT_FILE [ string range $XSAGREP $idx+6 $idx2-1 ]

    # extract MMI file name from XSA/sysdef.xml
    set XSAGREP [ exec unzip -p ${XSA_PATH} sysdef.xml | grep MMI ]
    set idx [ string first "Name=" $XSAGREP ]
    set idx2 [ string first "\"" $XSAGREP $idx+6 ]
    set MMI_FILE [ string range $XSAGREP $idx+6 $idx2-1 ]

    puts "App name       : ${APPNAME}"
    puts "Domain         : ${DOMNAME}"
    puts "Platform       : ${PLATNAME}"
    puts "Processor      : ${MB_INSTANCE}"
    puts "Block instance : ${BD_INSTANCE}"
    puts ""

    # Generate arguments
    set MMI "${WSPATH}/${APPNAME}/_ide/bitstream/${MMI_FILE}"
    set BIT "${WSPATH}/${APPNAME}/_ide/bitstream/${BIT_FILE}"
    set RELF "${WSPATH}/${APPNAME}/Release/${APPNAME}.elf"
    set DELF "${WSPATH}/${APPNAME}/Debug/${APPNAME}.elf"
    set PROC "${BD_INSTANCE}/${MB_INSTANCE}"
    if { [ string length $clOutput ] == 0 } {
        set OUT "${WSPATH}/${APPNAME}/_ide/bitstream/download.bit"
    } else {
        set OUT $clOutput
    }

    # Check if file paths exist
    set COMPLETE 1
    if { [ file exists $MMI ] } { puts "MMI file exists." ;  } else {
        puts "ERROR: ${MMI}  missing." ; set COMPLETE 0 }
    if { [ file exists $BIT ] } { puts "BIT file exists." ;  } else {
        puts "ERROR: ${BIT}  missing." ; set COMPLETE 0 }
    # Prefer Release ELF path to Debug ELF path
    if { [ file exists $RELF ] } { puts "ELF file (Release) exists." ; set ELF "$RELF" } else {
        if { [ file exists $DELF ] } { puts "ELF file (Debug) exists." ; set ELF "$DELF" } else {
            puts "ERROR - neither Release nor Debug ELF file found:"
            puts "  ${RELF}"
            puts "  ${DELF}"
            set COMPLETE 0 }
    }

    # Execute updatemem if input files available
    if { $COMPLETE } {
        puts "updatemem -force -meminfo $MMI"
        puts "                 -bit     $BIT"
        puts "                 -data    $ELF"
        puts "                 -proc    $PROC"
        puts "                 -out     $OUT"
        puts ""

        set result [catch {exec updatemem -force -meminfo $MMI -bit $BIT -data $ELF -proc $PROC -out $OUT} output]
        if { $result == 0 } {
            puts "updatemem  executed successfully:"
            puts "---------------------------------"
            puts $output
        } else {
            puts "updatemem  failed:"
            puts "------------------"
            puts $output
            puts ""
            puts "ELFintoBIT.tcl aborted."
            break
        }    
    } else {
        puts ""
        puts "ELFintoBIT.tcl aborted."
        break
    }
    # exit while loop after one iteration
    puts ""
    puts "ELFintoBIT.tcl finished."
    break
}
