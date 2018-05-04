library ieee;
use ieee.std_logic_1164.all;

entity tb_endeavour is
  port (
    clock : in  std_logic;
    reset : in  std_logic
  );
end entity tb_endeavour;

architecture behavioural of tb_endeavour is

  component mon_reg32t
    generic (
      RESET_VALUE       : std_logic_vector(31 downto 0);
      REG_ADDR          : std_logic_vector( 7 downto 0)
      );
    port (
      dataOut   : out std_logic_vector(31 downto 0);
      serOut    : out std_logic;
      shiftOut  : out std_logic;				
      bclk      : in  std_logic;
      dataIn    : in  std_logic_vector(31 downto 0);
      addrIn    : in  std_logic_vector( 7 downto 0);
      latchIn   : in  std_logic;
      latchOut  : in  std_logic;
      shiftEn   : in  std_logic;
      rstb      : in  std_logic
      );
  end component mon_reg32t;
  
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
  end component endeavoureos;

  --
  -- Signals
  --
  signal resetn         : std_logic;

  -- Serial lines (aka the bus tape)
  signal serial0        : std_logic;
  signal serial1        : std_logic;

  -- Register connections
  signal wstrobe        : std_logic;
  signal rstrobe        : std_logic;
  signal rshift         : std_logic;
  signal addr           : std_logic_vector(  7 downto 0);
  signal wdata          : std_logic_vector( 31 downto 0);
  signal rdata          : std_logic_vector(255 downto 0);
begin
  resetn        <= not reset;

  --proc_registers : process(clock)
  --begin
  --end process proc_registers;
  
  inst_reg01 : mon_reg32t
    generic map(
      RESET_VALUE       => x"00000000",
      REG_ADDR          => x"01"
      )
    port map(
      rstb              => resetn,
      bclk              => clock,
      --dataOut           => reg01,
      shiftOut          => rdata(1),
      dataIn            => wdata,
      addrIn            => addr,
      latchIn           => wstrobe,
      latchOut          => rstrobe,
      shiftEn           => rshift      
    );
  
  inst_amac : endeavour
    port map(
      hardrstb => resetn,
      softrstb => resetn,
      clk      => clock,
      chipid_pads => (others => '0'),
      efuse_chipid => (others => '0'),
      serialin => serial1,
      serialout => serial0,
      wstrobe   => wstrobe,
      rstrobe   => rstrobe,
      rshift    => rshift,
      addr      => addr,
      wdata     => wdata,
      rdata     => rdata
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
