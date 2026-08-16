package require ::quartus::project
package require ::quartus::flow
package require ::quartus::report

set flow_name [lindex $quartus(args) 0]
set project_name [lindex $quartus(args) 1]
set revision_name [lindex $quartus(args) 2]
set dst_dir "../output_files"

if {[catch {project_open $project_name -revision $revision_name} err]} {
    post_message -type error "Failed to open project: $err"
    return
}

if {[catch {load_report} err]} {
    post_message -type error "Could not load report: $err"
    project_close
    return
}

set is_structural [get_global_assignment -name VERILOG_MACRO]

if {[string match "*STRUCTURAL=1*" $is_structural]} {
    set prefix "structural"
} else {
    set prefix "behavioral"
}

file mkdir $dst_dir

foreach ext {flow map sta} {
    set src "output_files/${revision_name}.${ext}.rpt"
    set dst "$dst_dir/${prefix}_${ext}.rpt"
    
    if {[file exists $src]} {
        file copy -force $src $dst
        post_message -type info "post_flow.tcl: copied $src -> $dst"
    } else {
        post_message -type warning "post_flow.tcl: $src not found, report was not synced"
    }
}

unload_report
project_close