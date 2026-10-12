library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity phase_detector_id2 is
    Generic (
        DATA_WIDTH : integer := 16;       -- Keeps 16-bit high-resolution internal DSP math
        EPOCH_LEN  : integer := 16368     -- 1 ms update interval at 16.368 MHz (Modified back to default)
    );
    Port (
        clk          : in  STD_LOGIC;     -- 16.368 MHz Fast System Clock
        reset        : in  STD_LOGIC;     -- Active-High Synchronous Reset
        ref_clk      : in  STD_LOGIC;     -- Incoming Reference Square Wave
        nco_clk      : in  STD_LOGIC;     -- Connected to sin_out(11) (MSB feedback)
        update_en    : out STD_LOGIC;     -- Pulses '1' for 1 cycle when phase_error is valid
        phase_error  : out signed(DATA_WIDTH-1 downto 0) -- Signed error output
    );
end phase_detector_id2;

architecture Behavioral of phase_detector_id2 is

    -- 16368 max value fits safely within a 15-bit unsigned range
    signal accumulator : unsigned(14 downto 0) := (others => '0');
    signal epoch_count : unsigned(14 downto 0) := (others => '0');
    
    -- Registers to stabilize clock inputs and eliminate asynchronous spikes
    signal ref_clk_reg : std_logic := '0';
    signal nco_clk_reg : std_logic := '0';
    signal xor_out     : std_logic := '0';

    -- Midpoint represents perfect 90-degree lock
    constant MID_POINT : integer := EPOCH_LEN / 2;

begin

    -------------------------------------------------------------------------
    -- 1. XOR Phase Detection Stage
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            ref_clk_reg <= ref_clk;
            nco_clk_reg <= nco_clk;
            xor_out     <= ref_clk_reg xor nco_clk_reg;
        end if;
    end process;

    -------------------------------------------------------------------------
    -- 2. Integrate and Dump Accumulator Stage (Warning Fixed)
    --    Removed variables to eliminate the [Synth 8-6014] Vivado Warning.
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                accumulator <= (others => '0');
                epoch_count <= (others => '0');
                update_en   <= '0';
                phase_error <= (others => '0');
            else
                -- Default assignment
                update_en <= '0';

                -- Check if the integration epoch is complete (0 to EPOCH_LEN-1)
                if epoch_count = to_unsigned(EPOCH_LEN - 1, 15) then
                    -- Dump stage: Calculate signed variance away from midpoint
                    if xor_out = '1' then
                        phase_error <= resize(signed(accumulator + 1) - to_signed(MID_POINT, 16), DATA_WIDTH);
                    else
                        phase_error <= resize(signed(accumulator) - to_signed(MID_POINT, 16), DATA_WIDTH);
                    end if;
                    
                    update_en   <= '1'; -- Signal to loop filter to sample
                    
                    -- Reset tracking windows
                    accumulator <= (others => '0');
                    epoch_count <= (others => '0');
                else
                    -- Continue accumulation window
                    if xor_out = '1' then
                        accumulator <= accumulator + 1;
                    end if;
                    epoch_count <= epoch_count + 1;
                end if;
            end if;
        end if;
    end process;

end Behavioral;