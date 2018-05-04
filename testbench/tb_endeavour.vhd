library ieee;
use ieee.std_logic_1164.all;

entity tb_endeavour is
  port (
    clock : in  std_logic;
    reset : in  std_logic
  );
end entity tb_endeavour;

architecture behavioural of tb_endeavour is

  component endeavour
    port (
      hardrstb          : in  std_logic;
      softrstb          : in  std_logic;
      clk               : in  std_logic;
      chipid_pads       : in  std_logic_vector(  4 downto 0);
      efuse_chipid      : in  std_logic_vector( 19 downto 0);
      serialin          : in  std_logic;
      serialout         : out std_logic;
      serialout_en      : out std_logic;
      wstrobe           : out std_logic;
      rstrobe           : out std_logic;
      rshift            : out std_logic;
      addr              : out std_logic_vector(  7 downto 0);
      wdata             : out std_logic_vector( 31 downto 0);
      rdata             : in  std_logic_vector(255 downto 0)

      );
  end component endeavour;

  component endeavoureos is
    port (
      clock       : in  std_logic;
      reset       : in  std_logic;
      busy        : out std_logic;
      error       : out std_logic;
      datain      : in  std_logic_vector(63 downto 0);
      nbitsin     : in  integer range 0 to 63;
      dataout     : out std_logic_vector(63 downto 0);
      nbitsout    : out integer range 0 to 63;
      send        : in  std_logic;
      serialin    : in  std_logic;
      serialout   : out std_logic
      );
  end component endeavoureos;

  signal resetn         : std_logic;
  
  signal serial0        : std_logic;
  signal serial1        : std_logic;
begin
  resetn        <= not reset;
  
  inst_amac : endeavour
    port map(
      hardrstb => resetn,
      softrstb => resetn,
      clk      => clock,
      chipid_pads => (others => '0'),
      efuse_chipid => (others => '0'),
      serialin => serial1,
      serialout => serial0,
      rdata => (others => '0')
      );

  inst_eos : endeavoureos
    port map(
      clock     => clock,
      reset     => reset,

      send      => '0',
      
      datain    => (others => '0'),
      nbitsin   => 0,

      serialin  => serial0,
      serialout => serial1
      );
  
end behavioural; 
