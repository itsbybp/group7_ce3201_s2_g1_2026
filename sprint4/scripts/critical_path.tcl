# critical_path.tcl - camino critico de setup de `clk` del top de Sprint 4.
#
# Uso (desde sprint4/quartus, con la compilacion ya hecha):
#     quartus_sta -t ../scripts/critical_path.tcl
#
# Salidas (en sprint4/docs/evidencia/final/):
#   Parte 1, peor camino de todo el diseno (evidencia_atributos.md, seccion 1.5):
#     cp_peor_camino.rpt   peor camino de setup, con el detalle de cada tramo (From Node, To Node, retardos)
#     cp_20_peores.rpt     las 20 peores terminaciones de setup de clk
#     cp_hold_peor.rpt     peor camino de hold
#     cp_fmax.rpt          resumen de Fmax por reloj (debe coincidir con top_level.sta.rpt)
#   Parte 2, el mismo analisis filtrado por origen y destino (3 peores caminos de cada grupo, con detalle):
#     cp_real_cpu.rpt        destino: registros de la CPU
#     cp_real_bus_cpu.rpt    origen: alu_result_reg, rs2_data_reg o estado de la FSM; destino: registros de las M10K
#     cp_real_bus_host.rpt   origen: registros del vJTAG en top_level; destino: registros de las M10K
#     cp_real_resto.rpt      destino: cualquier registro que no sea M10K ni SignalTap
#   Parte 3, mismo analisis con dos excepciones de ruta falsa declaradas SOLO en esta sesion (no estan en el SDC
#   del proyecto ni cambian la compilacion). Justificacion en evidencia_atributos.md, seccion 1.5:
#     E1: ALU -> registros fuera de la CPU. La salida combinacional de la ALU solo llega a esos registros por
#         `wb_mux` hacia `address_data_memory`, y `wb_mux` toma `alu_result` solo en FETCH, donde `valid` vale 0.
#     E2: lectura directa del banco de registros (`forward_rs1`) -> registros `pc`. `forward_rs1` solo vale 1 en
#         DECODE con JALR, estado en que `pc` no se escribe por la condicion de salto (solo en BEQ).
#     cp_exc_peor_camino.rpt   peor camino de setup con E1 y E2, con el detalle de cada tramo
#     cp_exc_5_peores.rpt      los 5 peores
#     cp_exc_fmax.rpt          resumen de Fmax con E1 y E2
#   y en la consola una linea por grupo con la holgura peor y la Fmax = 1000 / (20 - holgura).
#
# El modelo es el lento a 85 C (el que da el Fmax de results.md y evidencia_atributos.md); la primera linea
# de cada reporte indica el modelo usado, que debe decir "Slow 1100mV 85C Model".

set script_dir [file dirname [file normalize [info script]]]
set out_dir    [file normalize [file join $script_dir .. docs evidencia final]]
file mkdir $out_dir

project_open top_level
create_timing_netlist -model slow
read_sdc
update_timing_netlist

# ---------------------------------------------------------------- Parte 1: peor camino de todo el diseno
report_timing -setup -npaths 1  -detail full_path -to_clock [get_clocks clk] -file [file join $out_dir cp_peor_camino.rpt]
report_timing -setup -npaths 20 -detail summary   -to_clock [get_clocks clk] -file [file join $out_dir cp_20_peores.rpt]
report_timing -hold  -npaths 1  -detail full_path -to_clock [get_clocks clk] -file [file join $out_dir cp_hold_peor.rpt]
report_clock_fmax_summary -file [file join $out_dir cp_fmax.rpt]

# ---------------------------------------------------------------- Parte 2: filtrado por origen y destino
# Conjuntos de registros (los patrones usan los nombres jerarquicos de los reportes cp_*.rpt).
set all_regs   [get_registers *]
set m10k_regs  [get_registers -nowarn {*altsyncram*}]
set sld_regs   [get_registers -nowarn {*sld_* *altera_reserved*}]
set cpu_regs   [get_registers -nowarn {*multicycle_rv32i:cpu|*}]
set cpu_src    [get_registers -nowarn {*alu_result_reg* *rs2_data_reg* *current_state*}]
set host_src   [get_registers -nowarn {*jtag_addr_q* *jtag_wdata_q* *vj_state*}]
set rest_regs  [remove_from_collection [remove_from_collection $all_regs $m10k_regs] $sld_regs]

puts "registros: todos [get_collection_size $all_regs], M10K [get_collection_size $m10k_regs], SignalTap/JTAG [get_collection_size $sld_regs], CPU [get_collection_size $cpu_regs], origen CPU-bus [get_collection_size $cpu_src], origen host [get_collection_size $host_src]"

# Un grupo: nombre, archivo, y los conjuntos -from (vacio = cualquiera) y -to.
proc medir {nombre archivo from_regs to_regs out_dir} {
    if {[get_collection_size $to_regs] == 0 || ($from_regs ne "" && [get_collection_size $from_regs] == 0)} {
        puts "AVISO: grupo $nombre vacio (revisar los patrones de nombres); se omite."
        return
    }
    set ruta [file join $out_dir $archivo]
    if {$from_regs eq ""} {
        report_timing -setup -npaths 3 -detail full_path -to $to_regs -file $ruta
        set paths [get_timing_paths -setup -npaths 1 -to $to_regs]
    } else {
        report_timing -setup -npaths 3 -detail full_path -from $from_regs -to $to_regs -file $ruta
        set paths [get_timing_paths -setup -npaths 1 -from $from_regs -to $to_regs]
    }
    # La linea de consola es solo una comodidad: los reportes ya quedaron escritos aunque esta consulta falle.
    if {[catch {
        foreach_in_collection p $paths {
            set slack [get_path_info $p -slack]
            puts [format "%-14s holgura peor = %s ns  ->  Fmax = %.2f MHz" $nombre $slack [expr {1000.0 / (20.0 - $slack)}]]
        }
    } err]} {
        puts "AVISO: $nombre: no se pudo leer la holgura por consola ($err); ver $archivo"
    }
}

medir "cpu"       cp_real_cpu.rpt       ""        $cpu_regs  $out_dir
medir "bus_cpu"   cp_real_bus_cpu.rpt   $cpu_src  $m10k_regs $out_dir
medir "bus_host"  cp_real_bus_host.rpt  $host_src $m10k_regs $out_dir
medir "resto"     cp_real_resto.rpt     ""        $rest_regs $out_dir

# ---------------------------------------------------------------- Parte 3: con las excepciones E1 y E2
set alu_pins   [get_pins -nowarn {u_rv32i_top|cpu|rv32i_alu|*|combout}]
set rf_pins    [get_pins -nowarn {u_rv32i_top|cpu|rv32i_reg_file|rs1_data*|combout}]
set pc_regs    [get_registers -nowarn {*multicycle_rv32i:cpu|pc[*]}]
set out_regs   [add_to_collection [remove_from_collection $rest_regs $cpu_regs] $m10k_regs]

puts "excepciones: pines de la ALU [get_collection_size $alu_pins], pines de lectura del banco [get_collection_size $rf_pins], registros pc [get_collection_size $pc_regs], registros fuera de la CPU [get_collection_size $out_regs]"

if {[get_collection_size $alu_pins] == 0 || [get_collection_size $rf_pins] == 0 || [get_collection_size $pc_regs] == 0} {
    puts "AVISO: algun conjunto de las excepciones esta vacio (revisar los patrones de nombres); la parte 3 se omite."
} else {
    set_false_path -through $alu_pins -to $out_regs
    set_false_path -through $rf_pins  -to $pc_regs
    update_timing_netlist

    report_timing -setup -npaths 1 -detail full_path -to_clock [get_clocks clk] -file [file join $out_dir cp_exc_peor_camino.rpt]
    report_timing -setup -npaths 5 -detail summary   -to_clock [get_clocks clk] -file [file join $out_dir cp_exc_5_peores.rpt]
    report_clock_fmax_summary -file [file join $out_dir cp_exc_fmax.rpt]

    if {[catch {
        foreach_in_collection p [get_timing_paths -setup -npaths 1 -to_clock [get_clocks clk]] {
            set slack [get_path_info $p -slack]
            puts [format "%-14s holgura peor = %s ns  ->  Fmax = %.2f MHz" "con E1 y E2" $slack [expr {1000.0 / (20.0 - $slack)}]]
        }
    } err]} {
        puts "AVISO: no se pudo leer la holgura por consola ($err); ver cp_exc_peor_camino.rpt"
    }
}

delete_timing_netlist
project_close