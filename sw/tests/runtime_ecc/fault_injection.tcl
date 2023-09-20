# Fault injection file by Michael Rogenmoser
# 
# This script flips a single bit in each memory word at the halfway point in the simulation.
# Not each flip will be tested, as not every bit is read.
# 
# Based in part on:
#   - https://diglib.tugraz.at/download.php?id=576a7490f01c3&location=browse

# This script is hard-coded to the expected timings in the ecc error test.

echo "Bitflip script enabled\n"

when {$now == 700000ns} {
  echo "Flipping!"
  set bitflippaddr 2048
  set indent [expr int(floor(rand()*39))]
  set current_value [examine /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent)]
  if {$current_value == "1'h0"} {
    force -deposit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent) 1
  }
  if {$current_value == "1'h1"} {
    force -deposit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent) 0
  }

}


when {$now == 3200000ns} {
  echo "Flipping two!"
  set bitflippaddr 2048
  set indent [expr int(floor(rand()*39))]
  set indent2 [expr (int(floor(rand()*39))+1)%39]
  set current_value [examine /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent)]
  if {$current_value == "1'h0"} {
    force -deposit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent) 1
  }
  if {$current_value == "1'h1"} {
    force -deposit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent) 0
  }
  set current_value [examine /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent2)]
  if {$current_value == "1'h0"} {
    force -deposit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent2) 1
  }
  if {$current_value == "1'h1"} {
    force -deposit /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_safety_island_top/gen_sram_bank(0)/i_mem_bank/i_bank/sram($bitflippaddr)($indent2) 0
  }

}
