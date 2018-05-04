# Endeavour Test Firmware
A testbench for playing with the Endeavour protocol used by AMACv2.

The documentation and the slave implementation (`endeavour.v`) of the protocol can be found in the AMACv2 SVN area
```
svn co svn+ssh://svn.cern.ch/reps/itkstrasic/AMACv2/trunk
```

An implementation of the Endeavour master is available in `vhdl/endeavour_master.vhd`.

## Running
The testbench uses [hdlmake](https://hdlmake.readthedocs.io/en/master/) for compilation and Vivado's simulator (`xsim`) for running.

```
git clone https://github.com/kkrizka/endeavour_firmware.git
cd endeavour_firmware/testbench
hdlmake
make
xsim -gui tb_endeavour -t test.tcl
```
