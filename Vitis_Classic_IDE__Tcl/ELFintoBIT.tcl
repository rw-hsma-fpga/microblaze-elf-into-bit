proc elfintobit_help {} {
    puts ""
    puts "usage: ELFintoBIT \[-h\] \[-a APP\] \[-w WORKPATH\] \[-o OUTPUT\] \[-d\] \[-l\]"
    puts ""
    puts "optional arguments: "
    puts "  -a APP        specify application project (can be used multiple times)"
    puts "  -w WORKPATH   specify Vitis workspace path (if necessary)"
    puts "  -o OUTPUT     specify non-default output bitstream file"
    puts "  -d            download bitstream to locally connected FPGA after generation"
    puts "  -l            download existing generated bitstream again"
    puts ""
}



proc ELFintoBIT { args } {

    #### START ####

    puts ""
    puts "Starting ELFintoBIT ..."
    puts ""

    #### PROCESS ARGUMENTS ####

    set clDownload 0
    set clDownloadOnly 0
    set clWorkspace ""
    set clApp ""
    set clOutput ""

    set argsList [ split $args " " ]
    # output list in a loop
    set numArgs [ llength $argsList ]
    for {set i 0} {$i < $numArgs} {incr i} {
        set arg [ lindex $argsList $i ]
        switch -regexp -- $arg {
            "-d" {  set clDownload 1  }
            "-l" {  set clDownloadOnly 1 }
            "-h" {  
                    elfintobit_help  
                    return 0
            }
            "--help" {  
                    elfintobit_help  
                    return 0
            }
            "-a" {
                    incr i
                    if {$i < $numArgs} {
                        append clApp [ lindex $argsList $i ]
                        append clApp " "
                    } else {
                        puts "ERROR: Missing argument for -a option."
                        elfintobit_help
                        return 1
                    }
            }
            "-w" {
                    incr i
                    if {$i < $numArgs} {
                        set clWorkspace [ lindex $argsList $i ]
                    } else {
                        puts "ERROR: Missing argument for -w option."
                        elfintobit_help
                        return 1
                    }
            }
            "-o" {
                    incr i
                    if {$i < $numArgs} {
                        set clOutput [ lindex $argsList $i ]
                    } else {
                        puts "ERROR: Missing argument for -o option."
                        elfintobit_help
                        return 1
                    }
            }
            default {
                if { [regexp {^-} $arg] } {
                    puts "ERROR: Unknown option '$arg' specified."
                    elfintobit_help
                    return 1
                }
            }
        }
    }
    
    # if clDownloadOnly AND clDownload are set, return error
    if { $clDownloadOnly == 1 && $clDownload == 1 } {
        puts "ERROR: -l and -d options cannot be used together."
        puts "       Can't both download the last bitstream and generate and download a new one."
        return 1
    }

    # replace all path backslashes with forward slashes
    set clWorkspace [ string map { "\\" "/" } $clWorkspace ]

    set clOutput [ string map { "\\" "/" } $clOutput ]

    # make list clApps from clApp
    set clApps [ split [ string trimright [ string trimleft $clApp " " ] " " ]  " " ]

    # get workspace path
    if { [ string length $clWorkspace ] == 0 } {
        if { [ string length [ getws ] ] == 0 } {
            setws -switch "./"
        } 
    } else {
        setws -switch $clWorkspace
    }

    # Read Vitis project path
    set WSPATH [ getws ]

    #### DOWNLOAD_ONLY ####

    if { $clDownloadOnly == 1 } {
        # read last ELFed bitstream from .last_ELFed_BIT
        set last_elfbit_file "${WSPATH}/.last_ELFed_BIT"
        set last_elfbit [ open $last_elfbit_file "r" ]
        set last_bitstream [ read $last_elfbit ]
        close $last_elfbit
        # remove trailing newlines
        set last_bitstream [ string trimright $last_bitstream "\n" ]
        set last_bitstream [ string trimright $last_bitstream "\r" ]
        if { [ string length $last_bitstream ] == 0 } {
            puts "ERROR: No last generated bitstream with ELFs found."
            return 1
        }
        # if $last_bitstream is not a file, exit
        if { ! [ file exists $last_bitstream ] } {
            puts "ERROR: Last generated bitstream not found."
            return 1
        }
        puts ""
        puts "Attempting FPGA download of bitstream"
        puts " ${last_bitstream}"
        puts ""
        # catch exception if connect doesn't work, print message in that case
        set result [ catch { connect } msg ]
        if { $result != 0 } {
            puts "ERROR: Board connect failed"
            puts $msg
            return 1
        } else {
            set result [  catch { fpga $last_bitstream } msg ]
            if { $result != 0 } {
                puts "ERROR: FPGA download failed"
                puts $msg
                return 1
            } else {
                puts "FPGA download complete."
            }
        }
        puts ""
        puts "ELFintoBIT.tcl finished."

        return 0
    }

    #### RETRIEVE AND MATCH PROJECT DATA ####

    # Retrieve app/domain/platform data for all apps in workspace

    #set APPDATA [ app list -dict ]
    set result [ catch { app list -dict } APPDATA ]
            if { $result != 0 } {
                puts "ERROR: Getting applications failed. Are you sure"
                puts "         ${WSPATH}"
                puts "       is the intended workspace?"
                return 1
            }

    set APPDATA_ELEMENTS [ split [ string trimright $APPDATA " " ]  " " ]

    # distribute into app, domain, platform lists
    set ALLAPPS [ list ]
    set ALLDOMS [ list ]
    set ALLPLATS [ list ]
    foreach { APP GAP1 DOM GAP2 PLAT } $APPDATA_ELEMENTS {
        lappend ALLAPPS $APP
        lappend ALLDOMS $DOM
        lappend ALLPLATS [string range $PLAT 0 end-1]
    }

    # if list clApps is not empty, sort out apps to be used
    if { [ llength $clApps ] > 0 } {
        set APPS [ list ]
        set DOMS [ list ]
        set PLATS [ list ]
        foreach clApp $clApps {
            set idx [ lsearch -exact $ALLAPPS $clApp ]
            if { $idx >= 0 } {
                lappend APPS $clApp
                lappend DOMS [ lindex $ALLDOMS $idx ]
                lappend PLATS [ lindex $ALLPLATS $idx ]
            } else {
                set missingApp $clApp
                break
            }
        }
        if { $idx == -1 } {
            puts "ERROR: App ${missingApp} not found in workspace."
            return 1
        }
    } else {
        set APPS $ALLAPPS
        set DOMS $ALLDOMS
        set PLATS $ALLPLATS
    }
    if { [ llength $APPS ] == 0 } {
        puts "ERROR: No apps found in workspace."
        return 1
    }
    if { [ llength $APPS ] > 1 } { 
        # check if all domains are different
        set DOMS_UNIQUE [ lsort -unique $DOMS ]
        if { [ llength $DOMS_UNIQUE ] != [ llength $DOMS ] } {
            puts "ERROR: Some selected apps have the same domain."
            return 1
        }
        # check if all platforms are the same
        set PLATS_UNIQUE [ lsort -unique $PLATS ]
        if { [ llength $PLATS_UNIQUE ] > 1 } {
            puts "ERROR: Selected apps belong to different platforms."
            return 1
        }
    }

    set PLATNAME [ lindex $PLATS 0 ]

    # Set platform
    platform active $PLATNAME
    puts ""
    puts "Platform     : ${PLATNAME}"

    # Get processor from domain
    set DOMDATA [ domain list -dict ]

    set DOMDATA_ELEMENTS [ split [ string trimright $DOMDATA " " ]  " " ]
    set ALLDOMS [ list ]
    set ALLCPUS [ list ]
    foreach { DOM GAP1 CPU GAP2 GAP3 } $DOMDATA_ELEMENTS {
        lappend ALLDOMS $DOM
        lappend ALLCPUS $CPU
    }
    # match DOMS with ALLDOMS and get MB_INSTANCES list from ALLCPUS
    set MB_INSTANCES [ list ]
    foreach DOM $DOMS {
        set idx [ lsearch -exact $ALLDOMS $DOM ]
        lappend MB_INSTANCES [ lindex $ALLCPUS $idx ]
    }

    set PLATHW_PATH "${WSPATH}/${PLATNAME}/hw/*.xsa"
    set result [catch { glob $PLATHW_PATH } XSA_PATH]
    if { $result != 0 } {
        puts "ERROR: No XSA_PATH found"
        puts ""
        puts "ELFintoBIT.tcl aborted."
        return 1
    }
    puts "XSA file     : ${XSA_PATH}"

    # extract block design instance from XSA/sysdef.xml
    set XSAGREP [ exec unzip -p ${XSA_PATH} sysdef.xml | grep DEFAULT_BD ]
    set idx [ string first "DESIGN_HIERARCHY" $XSAGREP ]
    set idx2 [ string first "\"" $XSAGREP $idx+18 ]
    set BD_INSTANCE [ string range $XSAGREP $idx+18 $idx2-1 ]
    puts "Block design : ${BD_INSTANCE}"

    # print processors and applications
    for { set i 0 } { $i < [ llength $APPS ] } { incr i } {
        set APP [ lindex $APPS $i ]
        set MB_INSTANCE [ lindex $MB_INSTANCES $i ]
        puts "Processor    : ${MB_INSTANCE}"
        puts "Application  : ${APP}"
    }
    puts ""

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


    #### BITSTREAM UPDATES ####

    set APP_BIT_PATH "/_ide/bitstream/"
    set FIRSTAPP [ lindex $APPS 0 ]

    set MMI "${WSPATH}/${FIRSTAPP}${APP_BIT_PATH}${MMI_FILE}"
    set BIT "${WSPATH}/${FIRSTAPP}${APP_BIT_PATH}${BIT_FILE}"
    set TEMPIN "${WSPATH}/${FIRSTAPP}${APP_BIT_PATH}_etob_in.bit"
    set TEMPOUT "${WSPATH}/${FIRSTAPP}${APP_BIT_PATH}_etob_out.bit"


    # if MMI or BIT file do not exist, exit
    if { ! [ file exists $MMI ] } {
        puts "ERROR: ${MMI}  missing." ; return 1 }
    if { ! [ file exists $BIT ] } {
        puts "ERROR: ${BIT}  missing." ; return 1 }
    set ELFS [ list ]

    foreach APP $APPS {
        set RELF "${WSPATH}/${APP}/Release/${APP}.elf"
        set DELF "${WSPATH}/${APP}/Debug/${APP}.elf"
        if { [ file exists $RELF ] } {
            lappend ELFS $RELF
            puts "Found Release ELF file: ${RELF}."
            puts "Delete Release ELF if you want to use the Debug ELF file."
            } else {
            if { [ file exists $DELF ] } { lappend ELFS $DELF } else {
                puts "ERROR - neither Release nor Debug ELF file for App found:"
                puts "  ${RELF}"
                puts "  ${DELF}"
                return 1
            }
        }
    }

    # make temporary copy of unELFed bitstream - copy BIT to TEMPIN
    set result [catch { exec cp $BIT $TEMPIN } output]
    if { $result != 0 } {
        puts "ERROR: cp $BIT $TEMPIN failed."
        return 1
    }

    # make counting for loop for all elements in APPS (i = 0 to length(APPS)-1)
    for { set i 0 } { $i < [ llength $APPS ] } { incr i } {
        set APP [ lindex $APPS $i ]
        set MB_INSTANCE [ lindex $MB_INSTANCES $i ]
        set ELF [ lindex $ELFS $i ]

        # Generate arguments
        set PROC "${BD_INSTANCE}/${MB_INSTANCE}"

        puts ""
        puts "Calling  updatemem  with ${APP}.elf for CPU ${MB_INSTANCE} ..."
        puts ""

        # Execute updatemem if input files available
        set result [catch {exec updatemem -force -meminfo $MMI -bit $TEMPIN -data $ELF -proc $PROC -out $TEMPOUT} output]
        if { $result == 0 } {
            puts "updatemem  executed successfully:"
            puts "---------------------------------"
            puts $output
        } else {
            puts "ERROR: updatemem  failed:"
            puts "------------------"
            puts $output
            return 1
        }

        # copy TEMPOUT to TEMPIN for next iteration
        set result [catch { exec cp $TEMPOUT $TEMPIN } output]
        if { $result != 0 } {
            puts "ERROR: cp $TEMPOUT $TEMPIN failed."
            return 1
        }
   
    }
    # end of updatemem for loop    


    set allouts [ list "" ]
    if { [ string length $clOutput ] != 0 } {
        set OUT $clOutput
        # copy TEMPOUT to OUT
        set result [catch { exec cp $TEMPOUT $OUT } output]
        if { $result != 0 } {
            puts "ERROR: cp $TEMPOUT $OUT failed."
            return 1
        }
        set firstout $OUT
        lappend allouts "${OUT}"
    } else {
        # copy to all app folders
        set numApps [ llength $APPS ]
        for {set i 0} {$i < $numApps} {incr i} {
            set APP [ lindex $APPS $i ]
            set OUT "${WSPATH}/${APP}${APP_BIT_PATH}download.bit"            
            set result [catch { exec cp $TEMPOUT $OUT } output]
            if { $result != 0 } {
                puts "ERROR: cp $TEMPOUT $OUT failed."
                return 1
            }
            lappend allouts $OUT
            if { $i == 0} {
                set firstout $OUT
            }
        }
    }
    # delete TEMPIN and TEMPOUT
    set result [catch { exec rm $TEMPIN } output]
    set result [catch { exec rm $TEMPOUT } output]

    # write string firstout into file .last_ELFed_BIT
    set last_elfbit_file "${WSPATH}/.last_ELFed_BIT"
    set last_elfbit [ open $last_elfbit_file "w" ]
    puts $last_elfbit $firstout
    close $last_elfbit

    # list output locations
    puts ""
    puts "The bitstream was written to the following location(s):"
    puts "-------------------------------------------------------"
    foreach OUT $allouts {
        puts "${OUT}"
    }
        
    #### LOCAL FPGA DOWNLOAD ####

    if { $clDownload == 1 } {
        puts ""
        puts "Attempting FPGA download of bitstream"
        puts " ${OUT}"
        puts ""
        # catch exception if connect doesn't work, print message in that case
        set result [ catch { connect } msg ]
        if { $result != 0 } {
            puts "ERROR: Board connect failed"
            puts $msg
            return 1
        } else {
            set result [  catch { fpga $OUT } msg ]
            if { $result != 0 } {
                puts "ERROR: FPGA download failed"
                puts $msg
                return 1
            } else {
                puts "FPGA download complete."
            }
        }            
    }

    #### FINISH ####

    puts ""
    puts "ELFintoBIT finished."
    return 0
}
