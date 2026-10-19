# jtag_server.tcl
set VJTAG_DATA_WIDTH 16
set TARGET_DEVICE "@2"
set write_count 0
set write_batch_started 0

if {$argc > 0} {
    set arg1 [lindex $argv 0]
    if {[string is integer -strict $arg1] && $arg1 > 0} {
        set VJTAG_DATA_WIDTH $arg1
    }
}

if {$argc > 1} {
    set TARGET_DEVICE [lindex $argv 1]
}

global usbblaster_name
global test_device
set test_device ""
set usbblaster_name ""














# CODE CHANGES SO THAT THE DEVICE CAN BE DETECTED EVEN IF IT DOESN'T START WITH "USB-Blaster*". IT STILL USES USB BLASTER.
# foreach hardware_name [get_hardware_names] {
#     if { [string match "USB-Blaster*" $hardware_name] } {
#         set usbblaster_name $hardware_name
#         foreach device_name [get_device_names -hardware_name $usbblaster_name] {
#             if { [string match "*${TARGET_DEVICE}*" $device_name] } { 
#                 set test_device $device_name
#                 puts "|INFO| Selected device: $test_device"
#             }
#         }
#     }
# }


set available_hardware [get_hardware_names]

puts "|INFO| Available hardware: $available_hardware"

if {[llength $available_hardware] > 0} {
    # Use the first hardware connection reported by Quartus.
    set usbblaster_name [lindex $available_hardware 0]

    puts "|INFO| Using hardware: $usbblaster_name"

    foreach device_name [get_device_names -hardware_name $usbblaster_name] {
        puts "|INFO| JTAG device: $device_name"

        if {[string match "*${TARGET_DEVICE}*" $device_name]} {
            set test_device $device_name
            puts "|INFO| Selected device: $test_device"
        }
    }
}













if {$test_device == ""} {
    puts "|ERROR| Target device matching '*${TARGET_DEVICE}*' not found."
    exit 1
}

proc openport {} {
    global usbblaster_name
    global test_device
    open_device -hardware_name $usbblaster_name -device_name $test_device
}

proc closeport {} {
    catch {device_unlock}
    catch {close_device}
}

proc transmit_to_fpga {bin_addr bin_data} {
    global VJTAG_DATA_WIDTH 
    global write_count
    global write_batch_started
    set ADDR_WIDTH 32

    if {$write_count == 0} {
        set write_batch_started [clock milliseconds]
    }
    
    device_lock -timeout 10000
    catch {
        device_virtual_ir_shift -instance_index 0 -ir_value 3 -no_captured_ir_value
        device_virtual_dr_shift -dr_value $bin_addr -instance_index 0 -length $ADDR_WIDTH -no_captured_dr_value
        
        device_virtual_ir_shift -instance_index 0 -ir_value 1 -no_captured_ir_value
        device_virtual_dr_shift -dr_value $bin_data -instance_index 0 -length $VJTAG_DATA_WIDTH -no_captured_dr_value
        device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
    }
    device_unlock

    incr write_count
    if {$write_count % 256 == 0} {
        set elapsed_ms [expr {[clock milliseconds] - $write_batch_started}]
        set average_ms [expr {double($elapsed_ms) / 256}]
        puts "|TIMING| $write_count writes elapsed=${elapsed_ms}ms average=${average_ms}ms/write"
        set write_batch_started [clock milliseconds]
    }
}

proc read_from_fpga {bin_addr} {
    global VJTAG_DATA_WIDTH 
    set ADDR_WIDTH 32
    set tdo_hex_value "0"
    
    device_lock -timeout 10000
    catch {
        device_virtual_ir_shift -instance_index 0 -ir_value 3 -no_captured_ir_value
        device_virtual_dr_shift -dr_value $bin_addr -instance_index 0 -length $ADDR_WIDTH -no_captured_dr_value
        
        device_virtual_ir_shift -instance_index 0 -ir_value 2 -no_captured_ir_value
        set tdo_hex_value [device_virtual_dr_shift -instance_index 0 -length $VJTAG_DATA_WIDTH -value_in_hex]
        device_virtual_ir_shift -instance_index 0 -ir_value 0 -no_captured_ir_value
    }
    device_unlock
    
    return $tdo_hex_value
}

proc Start_Server {port_num} { 
    if {[catch {openport} error_message]} {
        error "Failed to open vJTAG: $error_message"
    }
    if {[catch {socket -server ConnAccept $port_num} s]} {
        closeport
        error "Failed to start socket server: $s"
    }
    puts "Started Socket Server on port - $port_num"
    vwait forever
}

proc ConnAccept {sock addr client_port} { 
    global conn
    puts "Accept $sock from $addr port $client_port"
    set conn(addr,$sock) [list $addr $client_port]
    fconfigure $sock -buffering line
    fileevent $sock readable [list IncomingData $sock]
}

proc IncomingData {sock} {
    global conn
    if {[eof $sock] || [catch {gets $sock line}]} {
        close $sock
        unset conn(addr,$sock)
    } else {
        set trimmed_line [string trim $line]
        if {[string match "READ *" $trimmed_line]} {
            set bin_addr [lindex [split $trimmed_line " "] 1]
            if {[catch {read_from_fpga $bin_addr} response]} {
                set response "ERROR\n"
            } else {
                append response "\n"
            }
            puts -nonewline $sock $response
            flush $sock
        } elseif {[string match "WRITE *" $trimmed_line]} {
            set bin_addr [lindex [split $trimmed_line " "] 1]
            set bin_data [lindex [split $trimmed_line " "] 2]
            if {[catch {transmit_to_fpga $bin_addr $bin_data} error_message]} {
                set response "ERROR\n"
            } else {
                set response "OK\n"
            }
            puts -nonewline $sock $response
            flush $sock
        }
    }
}

# Intercept exit or Ctrl+C to close port cleanly
interp alias {} exit {} safe_exit
proc safe_exit {{code 0}} {
    catch {closeport}
    rename safe_exit {}
    exit $code
}

Start_Server 2540