library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_adpll_top is
end tb_adpll_top;

architecture Behavioral of tb_adpll_top is

    component adpll_top
        port (
            clk             : in  STD_LOGIC;
            reset           : in  STD_LOGIC;
            ref_clk         : in  STD_LOGIC;
            sin_out         : out STD_LOGIC_VECTOR(11 downto 0);
            cos_out         : out STD_LOGIC_VECTOR(11 downto 0);
            phase_error_out : out STD_LOGIC_VECTOR(11 downto 0);
            fcw_corr_out    : out STD_LOGIC_VECTOR(31 downto 0)
        );
    end component;

    signal clk_tb         : std_logic := '0';
    signal reset_tb       : std_logic := '1'; 
    signal ref_clk_tb     : std_logic := '0';
    signal sin_out_tb     : std_logic_vector(11 downto 0);
    signal cos_out_tb     : std_logic_vector(11 downto 0);
    signal phase_error_tb : std_logic_vector(11 downto 0);
    signal fcw_corr_tb    : std_logic_vector(31 downto 0);

    constant SYS_CLK_PERIOD : time := 61.0948 ns; 
    signal ref_period       : time := 244.379 ns; 

begin

    uut: adpll_top
        port map (
            clk             => clk_tb,
            reset           => reset_tb,
            ref_clk         => ref_clk_tb,
            sin_out         => sin_out_tb,
            cos_out         => cos_out_tb,
            phase_error_out => phase_error_tb,
            fcw_corr_out    => fcw_corr_tb
        );

    sys_clk_process : process
    begin
        while true loop
            clk_tb <= '0';
            wait for SYS_CLK_PERIOD / 2; 
            clk_tb <= '1';
            wait for SYS_CLK_PERIOD / 2;
        end loop;
    end process;

    ref_clk_process : process
    begin
        while true loop
            ref_clk_tb <= '0';
            wait for ref_period / 2;
            ref_clk_tb <= '1';
            wait for ref_period / 2;
        end loop;
    end process;

    stim_process : process
    begin
        reset_tb <= '1';
        wait for SYS_CLK_PERIOD * 20;
        reset_tb <= '0'; 
        
        ref_period <= 244.379 ns; 
        wait for 25 ms;

        report "Stepping input reference frequency!" severity note;
        ref_period <= 240.964 ns;
        
        wait for 35 ms;

        report "ADPLL Simulation Finished Successfully!" severity note;
        wait;
    end process;

end Behavioral;
