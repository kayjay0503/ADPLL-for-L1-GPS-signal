library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity loop_filter1 is
    Generic (
        DATA_WIDTH  : integer := 16;         -- Width of phase_error input
        FCW_WIDTH   : integer := 32;         -- Width of fcw_correction output
        FRAC_BITS   : integer := 30;         -- Fixed-point scale factor (C*2^30)
        C1_INT      : integer := 250656535;  -- Proportional coeff, C1 * 2^30
        C2_INT      : integer := 33427601    -- Integral coeff, C2 * 2^30
    );
    Port (
        clk            : in  STD_LOGIC;
        reset          : in  STD_LOGIC;                             -- Active-high synchronous reset
        update_en      : in  STD_LOGIC;                             -- Pulse: new phase_error is valid
        phase_error    : in  signed(DATA_WIDTH-1 downto 0);         -- Signed error from PD
        fcw_correction : out signed(FCW_WIDTH-1 downto 0)           -- Combined steering signal to NCO
    );
end loop_filter1;

architecture Behavioral of loop_filter1 is

    -- Headroom for running integrator so C2*error accumulation doesn't overflow
    constant ACC_WIDTH : integer := DATA_WIDTH + FRAC_BITS + 8;

    signal integrator : signed(ACC_WIDTH-1 downto 0) := (others => '0');

begin

    process(clk)
        variable c1_prod  : signed(DATA_WIDTH + 31 downto 0);
        variable c2_prod  : signed(DATA_WIDTH + 31 downto 0);
        variable sum_full : signed(ACC_WIDTH downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                integrator     <= (others => '0');
                fcw_correction <= (others => '0');
            elsif update_en = '1' then
                -- Integral path: accumulate C2 * error every update
                c2_prod    := to_signed(C2_INT, 32) * phase_error;
                integrator <= integrator + resize(c2_prod, ACC_WIDTH);

                -- Proportional path: added directly on top
                c1_prod  := to_signed(C1_INT, 32) * phase_error;
                sum_full := resize(integrator, ACC_WIDTH+1) + resize(c1_prod, ACC_WIDTH+1);

                -- Descale from Q(FRAC_BITS) fixed point back to FCW integer steps
                fcw_correction <= resize(shift_right(sum_full, FRAC_BITS), FCW_WIDTH);
            end if;
        end if;
    end process;

end Behavioral;