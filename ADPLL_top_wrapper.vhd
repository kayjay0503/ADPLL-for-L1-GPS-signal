library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity adpll_top is
    Port (
        clk              : in  STD_LOGIC;                     -- 16.368 MHz Fast System Clock
        reset            : in  STD_LOGIC;                     -- Active-High Synchronous Reset
        ref_clk          : in  STD_LOGIC;                     -- Incoming Reference Square Wave
        sin_out          : out STD_LOGIC_VECTOR(11 downto 0); -- 12-bit Output
        cos_out          : out STD_LOGIC_VECTOR(11 downto 0); -- 12-bit Output
        phase_error_out  : out STD_LOGIC_VECTOR(11 downto 0); -- 12-bit Truncated Phase Error
        fb_clk_out       : out STD_LOGIC;                     -- AD936x TX Path Interface Clock
        fcw_corr_out     : out STD_LOGIC_VECTOR(31 downto 0)  -- Loop Filter Tracking Diagnostics
    );
end adpll_top;

architecture Structural of adpll_top is

    constant N_BITS      : integer := 32;
    constant DATA_WIDTH  : integer := 16; -- PD keeps 16 for internal precision math
    constant EPOCH_LEN   : integer := 16368;     
    constant C1_FIXED    : integer := 250656535; 
    constant C2_FIXED    : integer := 33427601;  
    
    constant FCW0        : signed(N_BITS-1 downto 0) := to_signed(1073741824, N_BITS);

    component phase_detector_id2
        generic (
            DATA_WIDTH : integer;
            EPOCH_LEN  : integer
        );
        port (
            clk          : in  STD_LOGIC;
            reset        : in  STD_LOGIC;
            ref_clk      : in  STD_LOGIC;
            nco_clk      : in  STD_LOGIC;
            update_en    : out STD_LOGIC;
            phase_error  : out signed(DATA_WIDTH-1 downto 0)
        );
    end component;

    component loop_filter1
        generic (
            DATA_WIDTH  : integer;
            FCW_WIDTH   : integer;
            FRAC_BITS   : integer;
            C1_INT      : integer;
            C2_INT      : integer
        );
        port (
            clk            : in  STD_LOGIC;
            reset          : in  STD_LOGIC;
            update_en      : in  STD_LOGIC;
            phase_error    : in  signed(DATA_WIDTH-1 downto 0);
            fcw_correction : out signed(FCW_WIDTH-1 downto 0)
        );
    end component;

    component nco_cordic1
        port (
            clk       : in  STD_LOGIC;
            reset     : in  STD_LOGIC;
            fcw       : in  STD_LOGIC_VECTOR(31 downto 0);
            sin_out   : out STD_LOGIC_VECTOR(11 downto 0);
            cos_out   : out STD_LOGIC_VECTOR(11 downto 0)
        );
    end component;

    -- Internal Signals
    signal nco_clk_feedback  : std_logic;
    signal internal_sin      : std_logic_vector(11 downto 0);
    signal internal_cos      : std_logic_vector(11 downto 0);
    
    signal pd_update_en      : std_logic;
    signal pd_phase_error    : signed(DATA_WIDTH-1 downto 0);
    signal filter_correction : signed(N_BITS-1 downto 0);
    signal nco_fcw_drive     : signed(N_BITS-1 downto 0);

    -- Buffer Registers to lock all 12 digits simultaneously
    signal sin_buffer        : std_logic_vector(11 downto 0) := (others => '0');
    signal cos_buffer        : std_logic_vector(11 downto 0) := (others => '0');
    signal error_buffer      : std_logic_vector(11 downto 0) := (others => '0');

begin

    -- Drive the Source-Synchronous Transceiver Feedback Clock
    fb_clk_out <= clk;

    u_phase_detector : phase_detector_id2
        generic map (
            DATA_WIDTH => DATA_WIDTH,
            EPOCH_LEN  => EPOCH_LEN
        )
        port map (
            clk          => clk,
            reset        => reset,
            ref_clk      => ref_clk,
            nco_clk      => nco_clk_feedback, 
            update_en    => pd_update_en,
            phase_error  => pd_phase_error
        );

    u_loop_filter : loop_filter1
        generic map (
            DATA_WIDTH  => DATA_WIDTH,
            FCW_WIDTH   => N_BITS,
            FRAC_BITS   => 30,
            C1_INT      => C1_FIXED,
            C2_INT      => C2_FIXED
        )
        port map (
            clk            => clk,
            reset          => reset,
            update_en      => pd_update_en,
            phase_error    => pd_phase_error,
            fcw_correction => filter_correction
        );

    -------------------------------------------------------------------------
    -- NCO Tuning Word Process (FIXED: Removed duplicate shift operation)
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                nco_fcw_drive <= FCW0;
            else
                -- filter_correction is already descaled by the filter entity
                nco_fcw_drive <= FCW0 + filter_correction;
            end if;
        end if;
    end process;

    u_nco : nco_cordic1
        port map (
            clk       => clk,
            reset     => reset,
            fcw       => std_logic_vector(nco_fcw_drive),
            sin_out   => internal_sin,
            cos_out   => internal_cos
        );

    -------------------------------------------------------------------------
    -- Output register buffers to protect parallel lines from clock skew noise
    -------------------------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                sin_buffer   <= (others => '0');
                cos_buffer   <= (others => '0');
                error_buffer <= (others => '0');
            else
                sin_buffer   <= internal_sin;
                cos_buffer   <= internal_cos;
                -- Safe slice conversion from 16-bit signed down to 12-bit output
                error_buffer <= std_logic_vector(pd_phase_error(15 downto 4));
            end if;
        end if;
    end process;

    -- Final hardware routing assignments
    sin_out          <= sin_buffer;
    cos_out          <= cos_buffer;
    phase_error_out  <= error_buffer;
    fcw_corr_out     <= std_logic_vector(filter_correction);

    -- Sign bit of the buffered output drives the ADPLL feedback loop
    nco_clk_feedback <= sin_buffer(11); 

end Structural;
