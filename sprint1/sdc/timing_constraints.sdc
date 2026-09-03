# Restricciones SDC para datapath puramente combinacional
# Limita la latencia maxima de todos los puertos de entrada a salida a 20 ns
# Nombres de puerto ajustados a los usados en top_level.sv (no SW/KEY/HEX/LEDR genericos)
set_max_delay -from [get_ports {control[*] display_toggle_button src0[*] src1[*]}] -to [get_ports {carry negative operand_a_is_negative operand_b_is_negative overflow result_is_negative seven_segment_display_*[*]}] 20.0
