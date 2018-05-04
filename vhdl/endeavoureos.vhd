library ieee;
use ieee.std_logic_1164.all;

entity endeavoureos is
  port (
    clock       : in  std_logic;
    reset       : in  std_logic;

    -- control signals
    busy        : out std_logic;
    error       : out std_logic;
    nbitsin     : in  integer range 0 to 63;    
    datain      : in  std_logic_vector(63 downto 0);
    nbitsout    : out integer range 0 to 63;
    dataout     : out std_logic_vector(63 downto 0);
    send        : in  std_logic;

    -- serial signals
    serialin    : in  std_logic;
    serialout   : out std_logic
    );
end entity endeavoureos;

architecture behavioural of endeavoureos is
  type fsm_wr_t is (idle, senddata, sendbit, sendgap);
  signal fsm_wr : fsm_wr_t := idle;

  type fsm_rd_t is (idle, waitbit, readbit, waitgap);
  signal fsm_rd : fsm_rd_t := idle;
  
  signal reg_nbitsin    : integer range 0 to 63         := 0;  
  signal reg_datain     : std_logic_vector(63 downto 0) := (others => '0');

  signal reg_nbitsout   : integer range 0 to 63         := 0;  
  signal reg_dataout    : std_logic_vector(63 downto 0) := (others => '0');
begin
  --
  -- The FSM for writing data to AMAC
  --  
  process (clock)
    variable writebit   : std_logic;
    variable counter    : integer range 0 to 127        := 0;
  begin
    if rising_edge(clock) then
      if reset='1' then
        fsm_wr                  <= idle;
        reg_nbitsin             <= 0;
        reg_datain              <= (others => '0');
        counter                 := 0;
        serialout               <= 'U';
      else
        case fsm_wr is
          when idle =>
            serialout           <= '0';

            if send='1' then
              -- latch data to send
              reg_datain        <= datain;
              reg_nbitsin       <= nbitsin;
              fsm_wr            <= senddata;
            else
              fsm_wr            <= idle;
            end if;

          when senddata =>
            if reg_nbitsin=0 then
              fsm_wr            <= idle;
            else
              writebit          := reg_datain(reg_nbitsin-1);
              reg_nbitsin       <= reg_nbitsin - 1;
              if writebit='0' then
                counter         := 14;
              else
                counter         := 76;
              end if;
              fsm_wr            <= sendbit;
            end if;

          when sendbit =>
            if counter=0 then
              fsm_wr    <= sendgap;
              serialout <= '0';
              counter   := 43;
            else
              fsm_wr    <= sendbit;
              serialout <= '1';
              counter   := counter-1;
            end if;

          when sendgap =>
            serialout <= '0';            
            if counter=0 then
              fsm_wr    <= senddata;
            else
              fsm_wr    <= sendgap;
              counter   := counter-1;
            end if;

          when others =>
            fsm_wr              <= idle;
        end case;
      end if;
    end if;
  end process;

  --
  -- The FSM for receiving data to AMAC
  --
  process (clock)
    variable writebit   : std_logic;
    variable counter    : integer range 0 to 127        := 0;
  begin
    if rising_edge(clock) then
      if reset='1' then
        fsm_rd                  <= idle;
        reg_nbitsout            <= 0;
        reg_dataout             <= (others => '0');
        counter                 := 0;
      else
        case fsm_rd is
          when idle =>
            if serialin='1' then
              counter           := 1;
              reg_nbitsout      <= 0;
              reg_dataout       <= (others => '0');
              fsm_rd            <= waitbit;
            else
              fsm_rd            <= idle;
            end if;

          when waitbit =>
            if serialin='1' then
              counter           := counter+1;
            else
              fsm_rd            <= readbit;
            end if;

          when readbit =>
            if    ( 6 < counter) and (counter <  22) then
              reg_dataout       <= reg_dataout(62 downto 0) & '0';
            elsif (29 < counter) and (counter < 124) then
              reg_dataout       <= reg_dataout(62 downto 0) & '1';
            else
              -- TODO: Implement error?
            end if;
            counter             := 0;
            reg_nbitsout        <= reg_nbitsout + 1;
            fsm_rd              <= waitgap;

          when waitgap =>
            if serialin = '1' then
              counter           := 1;
              fsm_rd            <= waitbit;
            else
              counter           := counter + 1;
              if counter>75 then
                fsm_rd          <= idle;
              end if;
            end if;

          when others =>
            fsm_rd              <= idle;
        end case;
      end if;
    end if;
  end process;
  
end behavioural;
  
