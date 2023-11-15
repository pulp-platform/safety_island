# Fault injection file by Michael Rogenmoser
# 
# This script flips a single bit in each memory word at the halfway point in the simulation.
# Not each flip will be tested, as not every bit is read.
# 
# Based in part on:
#   - https://diglib.tugraz.at/download.php?id=576a7490f01c3&location=browse

# This script is hard-coded to the expected timings in the tcls test.


# flip a spefific bit of the given net name. returns a 1 if the bit could be flipped
proc flipbit {signal_name is_register} {
  echo $signal_name
  set success 0
  set old_value [examine -radixenumsymbolic $signal_name]
  # check if net is an enum
  if {[examine -radixenumnumeric $signal_name] != [examine -radixenumsymbolic $signal_name]} {
    set old_value_numeric [examine -radix binary,enumnumeric $signal_name]
    set new_value_numeric [expr int(rand()*([expr 2 ** [string length $old_value_numeric]]))]
    while {$old_value_numeric == $new_value_numeric && [string length $old_value_numeric] != 1} {
      set new_value_numeric [expr int(rand()*([expr 2 ** [string length $old_value_numeric]]))]
    }
    if {$is_register} {
      force -freeze $signal_name $new_value_numeric -cancel 10ns
    } else {
      force -freeze $signal_name $new_value_numeric, $old_value_numeric 10ns -cancel 10ns
    }
    set success 1
  } else {
    set flip_signal_name $signal_name
    set bin_val [examine -radix binary $signal_name]
    set len [string length $bin_val]
    set flip_index 0
    if {$len != 1} {
      set flip_index [expr int(rand()*$len)]
      set flip_signal_name $signal_name\($flip_index\)
    }
    set old_bit_value "0"
    set new_bit_value "1"
    if {[string index $bin_val [expr $len - 1 - $flip_index]] == "1"} {
      set new_bit_value "0"
      set old_bit_value "1"
    }
    if {$is_register} {
      force -freeze $flip_signal_name $new_bit_value -cancel 10ns
    } else {
      force -freeze $flip_signal_name $new_bit_value, $old_bit_value 10ns -cancel 10ns
    }
    if {[examine -radix binary $signal_name] != $bin_val} {set success 1}
  }
  set new_value [examine -radixenumsymbolic $signal_name]
  set result [list $success $old_value $new_value]
  return $result
}


echo "Bitflip script enabled\n"

when {$now == 700001ns} {
  echo "Flipping!"
  set flip_core_id 0
  set current_value [examine /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/i_core_wrap/gen_TCLS_core/gen_cores($flip_core_id)/i_cv32e40p/instr_addr_o(5)]
  flipbit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/i_core_wrap/gen_TCLS_core/gen_cores($flip_core_id)/i_cv32e40p/instr_addr_o(5) 0
}

when {$now == 800001ns} {
  echo "Flipping!"
  set flip_core_id 0
  set current_value [examine /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/i_core_wrap/gen_TCLS_core/gen_cores($flip_core_id)/i_cv32e40p/instr_addr_o(27)]
  flipbit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/i_core_wrap/gen_TCLS_core/gen_cores($flip_core_id)/i_cv32e40p/instr_addr_o(27) 0
}

