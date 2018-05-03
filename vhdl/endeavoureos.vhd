library ieee;
use ieee.std_logic_1164.all;

entity endeavoureos is
  port (
    clock       : in  std_logic;
    reset       : in  std_logic;

    -- control signals
    busy        : out std_logic;
    amac        : in  std_logic_vector( 4 downto 0);
    addr        : in  std_logic_vector( 7 downto 0);
    wdata       : in  std_logic_vector(55 downto 0);
    rdata       : out std_logic_vector(31 downto 0);
    efuseid     : in  std_logic_vector(19 downto 0);
    idpads      : in  std_logic_vector( 4 downto 0);
    istrobe     : in  std_logic;
    wstrobe     : in  std_logic;
    rstrobe     : in  std_logic;

    -- serial signals
    serialin    : in  std_logic;
    serialout   : out std_logic
    );
end entity endeavoureos;

architecture behavioural of endeavoureos is
  type mode_t is (none, setid, write, read);
  signal mode : mode_t := none;

  type fsm_t is (idle, senddata, sendbit, sendgap);
  signal fsm : fsm_t := idle;

  signal reg_nbits      : integer range 0 to 63         := 0;  
  signal reg_writeword  : std_logic_vector(55 downto 0) := (others => '0');
begin
  process (clock)
    variable writeword  : std_logic_vector(47 downto 0) := (others => '0');
    variable crc        : std_logic_vector( 7 downto 0) := (others => '0');
    variable writebit   : std_logic;
    variable counter    : integer range 0 to 127        := 0;
  begin
    if rising_edge(clock) then
      if reset='1' then
        fsm                     <= idle;
        mode                    <= none;
        reg_nbits               <= 0;
        reg_writeword           <= (others => '0');
        counter                 := 0;
        serialout               <= 'U';
      else
        case fsm is
          when idle =>
            serialout           <= '0';

            if istrobe='1' then
              writeword         := "110" & "11111" & "111" & amac & "1111" & efuseid & "111" & idpads;
              gen_crc : for i in 0 to 7 loop
                crc(i)          := writeword( 0+i) xor writeword( 8+i) xor writeword(16+i) xor writeword(24+i) xor writeword(32+i) xor writeword(40+i);
              end loop gen_crc;

              gen_writeword_data : for i in 0 to 47 loop
                reg_writeword(i)        <= writeword(47-i);
              end loop gen_writeword_data;
              gen_writeword_crc  : for i in 0 to 7 loop
                reg_writeword(48+i)     <= crc(7-i);
              end loop gen_writeword_crc;
              reg_nbits         <= 56;
              mode              <= setid;
              fsm               <= senddata;
            else
              fsm               <= idle;
            end if;
          when senddata =>
            writebit            := reg_writeword(0);
            reg_writeword(55 downto 0) <= 'U' & reg_writeword(55 downto 1);
            reg_nbits <= reg_nbits - 1;
            if writebit='0' then
              counter := 14;
            else
              counter := 76;
            end if;
            if reg_nbits=0 then
              fsm       <= idle;
            else
              fsm       <= sendbit;
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
  
