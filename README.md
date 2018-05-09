# Endeavour Test Firmware
A testbench for playing with the Endeavour protocol used by AMACv2.

The documentation and the slave implementation (`endeavour.v`) of the protocol can be found in the AMACv2 SVN area
```
svn co svn+ssh://svn.cern.ch/reps/itkstrasic/AMACv2/trunk
```

An implementation of the Endeavour master is available in `vhdl/endeavour_master.vhd`.

## endeavour_master interface
The endeavour_master entity is very dumb, with the software responsible for most of the work. It acts only as a (de)serializer for the morse code, with the Tx and Rx parts kept separate. This is to keep it simple and generic.


Generic ports
* `clock` - Clock used for internal logic and to time the serial line (nominal 80 MHz)
* `reset` - Active high reset signal to reset internal state machines
* `serialin` - The data sent from the the Endeavour slave
* `serialout` - The data sent to the the Endeavour slave

Transfer ports
* `nbitsin` - Number of bits to transfer from the `datain`
* `datain` - The data to transfer. The least significant `nbitsin` will be send, starting with bit at `nbitsin-1`.
* `send` - Pulse to send data stored in `datain`.
* `busy` - Indicates that the Tx FSM is sending data. Any calls to `send` will be ignored.

Receive ports
* `nbitsout` - Number of valid bits received from the slave.
* `dataout` - The data recieved from the slave, stored in the `nbitsout` least significant bits. The bit at `nbitsout-1` was recieved first.
* `datavalid` - High signal indicates that `dataout` contains valid and complete data. Goes low after reset and when a new word is being serialized.
* `error` - Inidicates an error condition during serialization of `serialin`. Currently only the length of a pulse must be in  the specified number of clock cycles.

The component declaration is below.

```vhdl
component endeavour_master is
  port (
    clock       : in  std_logic;
    reset       : in  std_logic;
    nbitsin     : in  integer range 0 to 63;    
    datain      : in  std_logic_vector(63 downto 0);
    send        : in  std_logic;
    busy        : out std_logic;
    nbitsout    : out integer range 0 to 63;
    dataout     : out std_logic_vector(63 downto 0);
    datavalid   : out std_logic;
    error       : out std_logic;    
    serialin    : in  std_logic;
    serialout   : out std_logic
    );
end component endeavour_master;
```

## Running
The testbench uses [hdlmake](https://hdlmake.readthedocs.io/en/master/) for compilation and Vivado's simulator (`xsim`) for running.

```
git clone https://github.com/kkrizka/endeavour_firmware.git
cd endeavour_firmware/testbench
hdlmake
make
xsim -gui tb_endeavour -t test.tcl
```
