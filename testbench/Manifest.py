action = "simulation"
sim_tool = "vivado_sim"
sim_top="tb_endeavour"

files = [
    "tb_endeavour.vhd",
]

modules = {
    "local" : [ "../verilog",
                "../vhdl" ],
}
