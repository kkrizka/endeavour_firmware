library ieee;
use ieee.std_logic_1164.all;

entity endeavoureos is
  port (
    clock       : in  std_logic;
    reset       : in  std_logic;

    -- control signals
    busy        : out std_logic;
    error       : out std_logic;
    datain      : in  std_logic_vector(63 downto 0);
    nbitsin     : in  integer range 0 to 63;
    dataout     : out std_logic_vector(63 downto 0);
    nbitsout    : out integer range 0 to 63;
    send        : in  std_logic;

    -- serial signals
    serialin    : in  std_logic;
    serialout   : out std_logic
    );
end entity endeavoureos;

architecture behavioural of endeavoureos is
  type fsm_t is (idle, senddata, sendbit, sendgap);
  signal fsm : fsm_t := idle;

  signal reg_nbitsin    : integer range 0 to 63         := 0;  
  signal reg_datain     : std_logic_vector(63 downto 0) := (others => '0');
begin
  process (clock)
    variable writebit   : std_logic;
    variable counter    : integer range 0 to 127        := 0;
  begin
    if rising_edge(clock) then
      if reset='1' then
        fsm                     <= idle;
        reg_nbitsin             <= 0;
        reg_datain              <= (others => '0');
        counter                 := 0;
        serialout               <= 'U';
      else
        case fsm is
          when idle =>
            serialout           <= '0';

            if send='1' then
              -- latch data to send
              reg_datain        <= datain;
              reg_nbitsin       <= nbitsin;
              fsm               <= senddata;
            else
              fsm               <= idle;
            end if;

          when senddata =>
            if reg_nbitsin=0 then
              fsm               <= idle;
            else
              writebit          := reg_datain(reg_nbitsin-1);
              reg_nbitsin       <= reg_nbitsin - 1;
              if writebit='0' then
                counter         := 14;
              else
                counter         := 76;
              end if;
              fsm               <= sendbit;
            end if;

          when sendbit =>
            if counter=0 then
              fsm       <= sendgap;
              serialout <= '0';
              counter   := 43;
            else
              fsm       <= sendbit;
              serialout <= '1';
              counter   := counter-1;
            end if;

          when sendgap =>
            serialout <= '0';            
            if counter=0 then
              fsm       <= senddata;
            else
              fsm       <= sendgap;
              counter   := counter-1;
            end if;

          when others =>
            fsm                 <= idle;
        end case;
      end if;
    end if;
  end process;

end behavioural;
  
