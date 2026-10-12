library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity nco_cordic1 is
    Port (
        clk       : in  STD_LOGIC;                     -- 16.368 MHz Fast Clock
        reset     : in  STD_LOGIC;                     -- Active High Synchronous Reset
        fcw       : in  STD_LOGIC_VECTOR(31 downto 0); -- Frequency Control Word
        sin_out   : out STD_LOGIC_VECTOR(11 downto 0); -- 12-bit Signed Sine Wave (Modified)
        cos_out   : out STD_LOGIC_VECTOR(11 downto 0)  -- 12-bit Signed Cosine Wave (Modified)
    );
end nco_cordic1;

architecture Behavioral of nco_cordic1 is

    constant N_STAGES  : integer := 16;
    constant GUARD_BITS : integer := 3;                 
    constant W          : integer := 12 + GUARD_BITS;    -- 15-bit internal width for 12-bit output

    constant DEG_45 : signed(31 downto 0) := to_signed(536870912, 32); -- 2^29

    -- 32-bit Phase Accumulator
    signal phase_acc : unsigned(31 downto 0) := (others => '0');

    type pipeline_array is array (0 to N_STAGES) of signed(W-1 downto 0);
    type angle_array    is array (0 to N_STAGES-1) of signed(31 downto 0);
    type quadrant_array is array (0 to N_STAGES) of unsigned(1 downto 0);

    signal x_reg    : pipeline_array := (others => (others => '0'));
    signal y_reg    : pipeline_array := (others => (others => '0'));
    signal quad_reg : quadrant_array := (others => (others => '0'));

    type z_array is array (0 to N_STAGES) of signed(31 downto 0);
    signal z_reg32 : z_array := (others => (others => '0'));

    constant CORDIC_ANGLES : angle_array := (
        0  => to_signed(536870912, 32),
        1  => to_signed(316933406, 32),
        2  => to_signed(167458907, 32),
        3  => to_signed(85004756, 32),
        4  => to_signed(42667331, 32),
        5  => to_signed(21354465, 32),
        6  => to_signed(10679838, 32),
        7  => to_signed(5340245, 32),
        8  => to_signed(2670163, 32),
        9  => to_signed(1335087, 32),
        10 => to_signed(667544, 32),
        11 => to_signed(333772, 32),
        12 => to_signed(166886, 32),
        13 => to_signed(83443, 32),
        14 => to_signed(41722, 32),
        15 => to_signed(20861, 32)
    );

    -- Recalculated gain matched to the 12-bit target depth
    constant CORDIC_GAIN : signed(W-1 downto 0) :=
        shift_left(to_signed(1243, W), GUARD_BITS); -- 0.60725 * 2^11 ≈ 1243

    signal quadrant_c : unsigned(1 downto 0);
    signal z0_c       : signed(31 downto 0);

begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                phase_acc <= (others => '0');
            else
                phase_acc <= phase_acc + unsigned(fcw);
            end if;
        end if;
    end process;

    quadrant_c <= phase_acc(31 downto 30);
    z0_c       <= signed("00" & std_logic_vector(phase_acc(29 downto 0)));

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                x_reg    <= (others => (others => '0'));
                y_reg    <= (others => (others => '0'));
                z_reg32  <= (others => (others => '0'));
                quad_reg <= (others => (others => '0'));
            else
                x_reg(0)    <= CORDIC_GAIN;
                y_reg(0)    <= (others => '0');
                z_reg32(0)  <= z0_c;
                quad_reg(0) <= quadrant_c;

                for i in 0 to N_STAGES-1 loop
                    quad_reg(i+1) <= quad_reg(i);
                    if z_reg32(i) >= DEG_45 then
                        x_reg(i+1)   <= x_reg(i) - shift_right(y_reg(i), i);
                        y_reg(i+1)   <= y_reg(i) + shift_right(x_reg(i), i);
                        z_reg32(i+1) <= z_reg32(i) - CORDIC_ANGLES(i);
                    else
                        x_reg(i+1)   <= x_reg(i) + shift_right(y_reg(i), i);
                        y_reg(i+1)   <= y_reg(i) - shift_right(x_reg(i), i);
                        z_reg32(i+1) <= z_reg32(i) + CORDIC_ANGLES(i);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    process(clk)
        variable cos_full, sin_full : signed(W-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cos_out <= (others => '0');
                sin_out <= (others => '0');
            else
                case quad_reg(N_STAGES) is
                    when "00" =>
                        cos_full := x_reg(N_STAGES);
                        sin_full := y_reg(N_STAGES);
                    when "01" =>
                        cos_full := -y_reg(N_STAGES);
                        sin_full := x_reg(N_STAGES);
                    when "10" =>
                        cos_full := -x_reg(N_STAGES);
                        sin_full := -y_reg(N_STAGES);
                    when others =>
                        cos_full := y_reg(N_STAGES);
                        sin_full := -x_reg(N_STAGES);
                end case;

                cos_out <= std_logic_vector(cos_full(W-1 downto GUARD_BITS));
                sin_out <= std_logic_vector(sin_full(W-1 downto GUARD_BITS));
            end if;
        end if;
    end process;

end Behavioral;