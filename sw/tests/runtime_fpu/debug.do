onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/clk_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/rst_ni
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/test_enable_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/irqs_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/jtag_tck_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/jtag_tdi_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/jtag_tdo_o
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/jtag_tms_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/jtag_trst_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/bootmode_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/fetch_enable_selector_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/fetch_enable_i
add wave -noupdate -expand -group dut -expand -subitemconfig {/tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_req_i.w -expand} /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_req_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_resp_o
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_req_o
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_resp_i
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/fetch_enable
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_instr_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/core_data_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_req_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_input_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank0_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/mem_bank1_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_output_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/xbar_slave_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/xbar_slave_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/xbar_slave_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/xbar_slave_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/error_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_reg_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_reg_rsp
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/boot_rom_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/global_prepend_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dbg_mem_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_reg_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/cl_periph_reg_rsp
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_rvalid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_we
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_be
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_wdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_rdata
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbprintf_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/all_periph_wdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/all_periph_rdata_agg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/all_periph_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/all_periph_gnt
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/debug_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dmi_rst_n
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dmi_req_valid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dmi_req_ready
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dmi_resp_valid
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dmi_resp_ready
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dmi_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/dmi_resp
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/main_idx
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/main_addr
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/periph_idx
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_reg2hw
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/soc_ctrl_hw2reg
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/tbrpintf_err
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_in_alt_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_in_alt_resp
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_in_dw32_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_in_dw32_resp
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_in_dw32_aw32_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_out_alt_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_out_alt_resp
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_out_dw32_req
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_out_dw32_resp
add wave -noupdate -expand -group dut /tb_safety_island_preloaded/fixt_safety_island/i_dut/axi_out_dw32_aw32_req
add wave -noupdate -expand -group inp_dwc -radix unsigned /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/AxiMaxReads
add wave -noupdate -expand -group inp_dwc -radix unsigned /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/AxiSlvPortDataWidth
add wave -noupdate -expand -group inp_dwc -radix unsigned /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/AxiMstPortDataWidth
add wave -noupdate -expand -group inp_dwc -radix unsigned /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/AxiAddrWidth
add wave -noupdate -expand -group inp_dwc -radix unsigned /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/AxiIdWidth
add wave -noupdate -expand -group inp_dwc /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/clk_i
add wave -noupdate -expand -group inp_dwc /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/rst_ni
add wave -noupdate -expand -group inp_dwc -expand -subitemconfig {/tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/slv_req_i.aw {-height 17 -childformat {{addr -radix hexadecimal}} -expand} /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/slv_req_i.aw.addr {-radix hexadecimal} /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/slv_req_i.w -expand} /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/slv_req_i
add wave -noupdate -expand -group inp_dwc /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/slv_resp_o
add wave -noupdate -expand -group inp_dwc -expand -subitemconfig {/tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/mst_req_o.w -expand} /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/mst_req_o
add wave -noupdate -expand -group inp_dwc /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_input_dw/mst_resp_i
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/clk_i
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/rst_ni
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/busy_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/axi_req_i
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/axi_resp_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_req_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_gnt_i
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_addr_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_wdata_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_strb_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_atop_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_we_o
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_rvalid_i
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_rdata_i
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_rdata
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/m2s_resp
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/r_cnt_d
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/r_cnt_q
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/w_cnt_d
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/w_cnt_q
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/arb_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/arb_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/rd_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/rd_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/wr_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/wr_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_b
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_buf_b
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_r
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_buf_r
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_buf_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_buf_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_lock_d
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/sel_lock_q
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta_buf_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta_buf_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta_sel_d
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta_sel_q
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/m2s_req_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/m2s_req_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/m2s_resp_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/m2s_resp_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_req_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_req_ready
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_rvalid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/m2s_req
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_req
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/rd_meta
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/rd_meta_d
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/rd_meta_q
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/wr_meta
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/wr_meta_d
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/wr_meta_q
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/meta_buf
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_join_valid
add wave -noupdate -expand -group axi2mem /tb_safety_island_preloaded/fixt_safety_island/i_dut/i_axi_to_mem/mem_join_ready
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/exit_status
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/stim_fd
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/num_stim
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_clk
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_fetchenable
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_fetchenable_selector
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_bootmode
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_rst_n
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_test_enable
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_tck
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_tdi
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_tdo
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_tms
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/s_trstn
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/from_ext_req
add wave -noupdate -expand -group fixt /tb_safety_island_preloaded/fixt_safety_island/from_ext_resp
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {6247163 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 214
configure wave -valuecolwidth 211
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {16391742 ps}
