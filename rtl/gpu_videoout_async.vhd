library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all; 

library mem;
use work.pGPU.all;

entity gpu_videoout_async is
   port 
   (
      clk1x                   : in  std_logic;
      clk2x                   : in  std_logic;
      clkvid                  : in  std_logic;
      ce_1x                   : in  std_logic;
      reset_1x                : in  std_logic;
      softReset_1x            : in  std_logic;
      
      allowunpause1x          : out std_logic;
      
      videoout_settings_1x    : in  tvideoout_settings;
      videoout_reports_1x     : out tvideoout_reports;

      videoout_request_2x     : out tvideoout_request := ('0', (others => '0'), (others => '0'), 0, (others => '0'));
      videoout_request_vid    : out tvideoout_request := ('0', (others => '0'), (others => '0'), 0, (others => '0'));
      
      videoout_readAddr       : out unsigned(10 downto 0) := (others => '0');
      videoout_pixelRead      : in  std_logic_vector(15 downto 0);
      
      overlay_data            : in  std_logic_vector(23 downto 0);
      overlay_ena             : in  std_logic;
         
      videoout_out            : buffer tvideoout_out;
      
      videoout_ss_in          : in  tvideoout_ss;
      videoout_ss_out         : out tvideoout_ss
   );
end entity;

architecture arch of gpu_videoout_async is
   
   -- clk1x -> clkvid
   signal videoout_settings_s2 : tvideoout_settings;
   signal videoout_settings_s1 : tvideoout_settings;
   signal videoout_settings    : tvideoout_settings;
   
   signal ce_s2                : std_logic;        
   signal ce_s1                : std_logic;        
   signal ce                   : std_logic;        
   signal ce_1                 : std_logic;        
   
   signal reset_s2             : std_logic;        
   signal reset_s1             : std_logic;        
   signal reset                : std_logic;      
   
   signal softReset_s2         : std_logic;        
   signal softReset_s1         : std_logic;        
   signal softReset            : std_logic;      
   
   -- clkvid -> clk1x
   signal videoout_reports_s2  : tvideoout_reports;
   signal videoout_reports_s1  : tvideoout_reports;
   signal videoout_reports     : tvideoout_reports;
   
   signal allowunpause         : std_logic;
   signal allowunpause_s1      : std_logic;
   signal allowunpause_s2      : std_logic;
   
   -- clkvid -> clk2x
   
   signal videoout_request_s2  : tvideoout_request := ('0', (others => '0'), (others => '0'), 0, (others => '0'));
   signal videoout_request_s1  : tvideoout_request := ('0', (others => '0'), (others => '0'), 0, (others => '0'));
   signal videoout_request     : tvideoout_request := ('0', (others => '0'), (others => '0'), 0, (others => '0'));
   
   -- timing
   signal lineIn           : unsigned(8 downto 0) := (others => '0');
   signal nextHCount       : integer range 0 to 4095;

   signal vpos             : integer range 0 to 511;
   signal vdisp            : integer range 0 to 511;
   
   signal nextHCount_pause : integer range 0 to 4095;
   signal vpos_pause       : integer range 0 to 511;
   signal unpauseCnt       : integer range 0 to 3 := 0;
   
   signal htotal           : integer range 3406 to 3413;
   signal vtotal           : integer range 262 to 314;
   signal vDisplayStart    : integer range 0 to 314;
   signal vDisplayEnd      : integer range 0 to 314;
   
   signal InterlaceFieldN  : std_logic := '0';  
   
   -- output   
   type tState is
   (
      WAITNEWLINE,
      WAITHBLANKEND,
      DRAW
   );
   signal state : tState := WAITNEWLINE;
   
   signal pixelData_R      : std_logic_vector(7 downto 0) := (others => '0');
   signal pixelData_G      : std_logic_vector(7 downto 0) := (others => '0');
   signal pixelData_B      : std_logic_vector(7 downto 0) := (others => '0');
      
   signal clkDiv           : integer range 4 to 10 := 4; 
   signal clkCnt           : integer range 0 to 10 := 0;
   signal xmax             : integer range 0 to 1023 := 256;
      
   signal hsync_start      : integer range 0 to 4095;
   signal hsync_end        : integer range 0 to 4095;
   
   signal hCropCount       : unsigned(11 downto 0);
   signal hCropPixels      : unsigned(1 downto 0);
   
   type tReadState is
   (
      IDLE,
      READ16,
      READ24_0,
      READ24_8,
      READ24_16,
      READ24_24
   );
   signal readstate     : tReadState := IDLE;
   signal readstate24   : tReadState := READ24_0;
   
   signal fetchNext : std_logic := '0';
   
begin 

   -- clk1x -> clkvid
   process (clkvid)
   begin
      if rising_edge(clkvid) then
   
         videoout_settings_s2 <= videoout_settings_1x;
         videoout_settings_s1 <= videoout_settings_s2;
         videoout_settings    <= videoout_settings_s1;
         
         ce_s2                <= ce_1x;
         ce_s1                <= ce_s2;
         ce                   <= ce_s1;
         
         reset_s2             <= reset_1x;
         reset_s1             <= reset_s2;
         reset                <= reset_s1;
         
         softReset_s2         <= softReset_1x;
         softReset_s1         <= softReset_s2;
         softReset            <= softReset_s1;
   
      end if;
   end process;

   -- clkvid -> clk1x
   process (clk1x)
   begin
      if rising_edge(clk1x) then
   
         videoout_reports_s1  <= videoout_reports;
         videoout_reports_s2  <= videoout_reports_s1;
         videoout_reports_1x  <= videoout_reports_s2;   

         allowunpause_s1      <= allowunpause;   
         allowunpause_s2      <= allowunpause_s1;   
         allowunpause1x       <= allowunpause_s2;   

      end if;
   end process;
   
   -- clkvid -> clk2x
   videoout_request_vid <= videoout_request;
   process (clk2x)
   begin
      if rising_edge(clk2x) then
   
         videoout_request_s1  <= videoout_request;
         videoout_request_s2  <= videoout_request_s1;
         videoout_request_2x  <= videoout_request_s2;         
   
      end if;
   end process;
   
   -- video timing
   videoout_ss_out.interlacedDisplayField <= videoout_reports.interlacedDisplayField;                 
   videoout_ss_out.nextHCount             <= std_logic_vector(to_unsigned(nextHCount, 12));                             
   videoout_ss_out.vpos                   <= std_logic_vector(to_unsigned(vpos, 9));                            
   videoout_ss_out.vdisp                  <= std_logic_vector(to_unsigned(vdisp, 9));                            
   videoout_ss_out.inVsync                <= videoout_reports.inVsync;                                
   videoout_ss_out.activeLineLSB          <= videoout_reports.activeLineLSB;                          
   videoout_ss_out.GPUSTAT_InterlaceField <= videoout_reports.GPUSTAT_InterlaceField;
   videoout_ss_out.GPUSTAT_DrawingOddline <= videoout_reports.GPUSTAT_DrawingOddline;

   videoout_request.fetchsize <= to_unsigned(xmax, 10);

   vDisplayStart <= to_integer(videoout_settings.vDisplayRange( 9 downto  0));
   vDisplayEnd   <= to_integer(videoout_settings.vDisplayRange(19 downto 10));

   videoout_reports.vsync <= videoout_out.vsync;

   process (clkvid)
      variable mode480i                  : std_logic;
      variable isVsync                   : std_logic;
      variable vdispNew                  : integer range 0 to 511;
      variable interlacedDisplayFieldNew : std_logic;
   begin
      if rising_edge(clkvid) then
      
         if (nextHCount <   3) then videoout_reports.hblank_tmr <= '1'; else videoout_reports.hblank_tmr <= '0'; end if; -- todo: correct hblank timer tick position to be found
                
         if (reset = '1') then
               
            videoout_reports.irq_VBLANK  <= '0';
               
            videoout_reports.interlacedDisplayField   <= videoout_ss_in.interlacedDisplayField;
            nextHCount                                <= to_integer(unsigned(videoout_ss_in.nextHCount));
            vpos                                      <= to_integer(unsigned(videoout_ss_in.vpos));
            videoout_reports.inVsync                  <= videoout_ss_in.inVsync;
            videoout_reports.activeLineLSB            <= videoout_ss_in.activeLineLSB;
            videoout_reports.GPUSTAT_DrawingOddline   <= videoout_ss_in.GPUSTAT_DrawingOddline;
            
            InterlaceFieldN                           <= videoout_ss_in.GPUSTAT_InterlaceField;
            
            vdisp            <= to_integer(unsigned(videoout_ss_in.vdisp));

            allowunpause     <= '1';
            unpauseCnt       <= 3;
            nextHCount_pause <= 1;
            vpos_pause       <= 0;
            
         else
         
            ce_1 <= ce;
            if (ce_1 = '1' and ce = '0') then
               nextHCount_pause <= nextHCount;
               vpos_pause       <= vpos;
            end if;
            
            if (unpauseCnt > 0) then
               unpauseCnt <= unpauseCnt - 1;
            else
               allowunpause <= '0';
            end if;
            
            if (vpos_pause = vpos and nextHCount_pause = nextHCount) then
               allowunpause <= '1';
               unpauseCnt   <= 3;
            end if;
            
            --gpu timing calc
            if (videoout_settings.GPUSTAT_PalVideoMode = '1' and videoout_settings.pal60 = '0') then
               htotal <= 3406;
               if (videoout_settings.GPUSTAT_VertInterlace = '0' or videoout_settings.syncInterlace = '1') then
                  vtotal <= 314;
               elsif (InterlaceFieldN = '0') then
                  vtotal <= 313;
               else
                  vtotal <= 312;
               end if;
               videoout_out.isPal <= '1';
            else
               htotal <= 3413;
               if (videoout_settings.GPUSTAT_VertInterlace = '0' or InterlaceFieldN = '0' or videoout_settings.syncInterlace = '1') then
                  vtotal <= 263;
               else
                  vtotal <= 262;
               end if;
               videoout_out.isPal <= '0';
            end if;
            
            -- gpu timing count
            if (nextHCount > 1) then
               nextHCount <= nextHCount - 1;
            else
               
               nextHCount <= htotal;
               
               vpos <= vpos + 1;
               if (vpos + 1 = vtotal) then
                  vpos <= 0;
                  if (videoout_settings.GPUSTAT_VertInterlace = '1') then
                     InterlaceFieldN <= not InterlaceFieldN;
                  else
                     InterlaceFieldN <= '0';
                  end if;
               end if;               
               
               -- todo: timer 1
               
               mode480i := '0';
               if (videoout_settings.GPUSTAT_VerRes = '1' and videoout_settings.GPUSTAT_VertInterlace = '1') then mode480i := '1'; end if;
               
               vdispNew := vdisp + 1;
               if (videoout_out.vsync = '1') then
                   vdispNew := 0;
               end if;

               vdisp <= vdispNew;

               isVsync := videoout_reports.inVsync;
               if (vdispNew = vDisplayStart) then
                  isVsync := '0';
               elsif (vdispNew = vDisplayEnd) then
                  isVsync := '1';
               end if;

               if (isVsync = '0') then
                  if (videoout_settings.GPUSTAT_VerRes = '1') then
                     if (videoout_reports.interlacedDisplayField = '1') then
                        lineIn <= to_unsigned(((vdispNew - vDisplayStart) * 2) + 1, 9);
                     else
                        lineIn <= to_unsigned((vdispNew - vDisplayStart) * 2, 9);
                     end if;
                  else
                     lineIn <= to_unsigned(vdispNew - vDisplayStart, 9);
                  end if;
               end if;

               videoout_reports.irq_VBLANK <= '0';
               interlacedDisplayFieldNew := videoout_reports.interlacedDisplayField;
               if (isVsync /= videoout_reports.inVsync) then
                  if (isVsync = '1') then
                     videoout_request.fetch      <= '0';
                     videoout_reports.irq_VBLANK <= '1';
                     if (mode480i = '1') then 
                        interlacedDisplayFieldNew := not videoout_reports.GPUSTAT_InterlaceField;
                     else 
                        interlacedDisplayFieldNew := '0';
                     end if;
                  end if;
                  videoout_reports.inVsync <= isVsync;
                  --Timer.gateChange(1, inVsync);
               end if;
               videoout_reports.interlacedDisplayField <= interlacedDisplayFieldNew;
               
             
               videoout_reports.GPUSTAT_DrawingOddline <= '0';
               videoout_reports.activeLineLSB          <= '0';
               if (mode480i = '1') then
                  if (videoout_settings.vramRange(10) = '0' and interlacedDisplayFieldNew = '1') then videoout_reports.activeLineLSB <= '1'; end if;
                  if (videoout_settings.vramRange(10) = '1' and interlacedDisplayFieldNew = '0') then videoout_reports.activeLineLSB <= '1'; end if;
               
                  if (videoout_settings.vramRange(10) = '0' and isVsync = '0' and interlacedDisplayFieldNew = '1') then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
                  if (videoout_settings.vramRange(10) = '1' and isVsync = '1' and interlacedDisplayFieldNew = '0') then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
               else
                  if (videoout_settings.vramRange(10) = '0' and (vdispNew mod 2) = 1) then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
                  if (videoout_settings.vramRange(10) = '1' and (vdispNew mod 2) = 0) then videoout_reports.GPUSTAT_DrawingOddline <= '1'; end if;
               end if;
               
               -- fetching of next line from framebuffer
               vdispNew := vdispNew + 1;
               if (vDisplayStart > 0) then
                  if (vdispNew >= vDisplayStart and vdispNew < vDisplayEnd) then
                     if (videoout_settings.GPUSTAT_VerRes = '1') then
                        if (videoout_reports.activeLineLSB = '1') then
                           videoout_request.lineInNext <= to_unsigned(((vdispNew - vDisplayStart) * 2) + 1, 9);
                        else
                           videoout_request.lineInNext <= to_unsigned((vdispNew - vDisplayStart) * 2, 9);
                        end if;
                     else
                        videoout_request.lineInNext <= to_unsigned(vdispNew - vDisplayStart, 9);
                     end if;
                     videoout_request.fetch      <= ce;
                  end if;
               else  
                  if (vdispNew = vtotal) then
                     if (videoout_settings.GPUSTAT_VerRes = '1' and videoout_reports.interlacedDisplayField = '1') then
                        videoout_request.lineInNext <= to_unsigned(1, 9);
                     else
                        videoout_request.lineInNext <= to_unsigned(0, 9);
                     end if;
                     videoout_request.fetch      <= ce;
                  elsif (vdispNew >= vDisplayStart and vdispNew < vDisplayEnd) then
                     if (videoout_settings.GPUSTAT_VerRes = '1') then
                        if (videoout_reports.activeLineLSB = '1') then
                           videoout_request.lineInNext <= to_unsigned(((vdispNew - vDisplayStart) * 2) + 1, 9);
                        else
                           videoout_request.lineInNext <= to_unsigned((vdispNew - vDisplayStart) * 2, 9);
                        end if;
                     else
                        videoout_request.lineInNext <= to_unsigned(vdispNew - vDisplayStart, 9);
                     end if;
                     videoout_request.fetch      <= ce;
                  end if;
               end if;
              
            end if;
            
            if (softReset = '1') then
               InterlaceFieldN                         <= '1';
               videoout_reports.GPUSTAT_DrawingOddline <= '0';
               videoout_reports.irq_VBLANK             <= '0';
               
               vpos                      <= 0;
               vdisp                     <= 0;
               nextHCount                <= htotal;
               videoout_reports.inVsync  <= '0';
            end if;

         end if;
      end if;
   end process;
   
   -- timing generation reading
   videoout_out.vblank         <= videoout_reports.inVsync;
   videoout_out.interlace      <= videoout_settings.GPUSTAT_VerRes and videoout_reports.interlacedDisplayField;

   videoout_out.DisplayOffsetX <= videoout_settings.vramRange(9 downto 0);
   videoout_out.DisplayOffsetY <= videoout_settings.vramRange(18 downto 10);
   
   process (clkvid)
      variable vsync_hstart : integer range 0 to 4095;
      variable vsync_vstart  : integer range 0 to 511;
   begin
      if rising_edge(clkvid) then
         
         videoout_out.ce <= '0';
         
         if (videoout_settings.GPUSTAT_HorRes2 = '1') then
            clkDiv  <= 7; videoout_out.hResMode <= "010"; -- 368
         else
            case (videoout_settings.GPUSTAT_HorRes1) is
               when "00" => clkDiv <= 10; videoout_out.hResMode <= "100"; -- 256;
               when "01" => clkDiv <= 8;  videoout_out.hResMode <= "011"; -- 320;
               when "10" => clkDiv <= 5;  videoout_out.hResMode <= "001"; -- 512;
               when "11" => clkDiv <= 4;  videoout_out.hResMode <= "000"; -- 640;
               when others => null;
            end case;
         end if;
         
         if (videoout_settings.GPUSTAT_HorRes2 = '1') then
            videoout_out.DisplayWidth  <= to_unsigned(368, 10);
         else
            case (videoout_settings.GPUSTAT_HorRes1) is
               when "00" => videoout_out.DisplayWidth <= to_unsigned(256, 10);
               when "01" => videoout_out.DisplayWidth <= to_unsigned(320, 10);
               when "10" => videoout_out.DisplayWidth <= to_unsigned(512, 10);
               when "11" => videoout_out.DisplayWidth <= to_unsigned(640, 10);
               when others => null;
            end case;
         end if;
         
         if (videoout_settings.GPUSTAT_VerRes = '1') then
            videoout_out.DisplayHeight  <= to_unsigned(480, 9);
         else
            videoout_out.DisplayHeight  <= to_unsigned(240, 9);
         end if;
         
         if (reset = '1') then
         
            state                      <= WAITNEWLINE;
         
            clkCnt                     <= 0;
            videoout_out.hblank        <= '1';
            videoout_out.vsync         <= '0';
            videoout_request.lineDisp  <= (others => '0');
            readstate                  <= IDLE;
            
            videoout_reports.GPUSTAT_InterlaceField <= videoout_ss_in.GPUSTAT_InterlaceField;
         
         else
            
            if (clkCnt < (clkDiv - 1)) then
               clkCnt <= clkCnt + 1;
            else
               clkCnt           <= 0;
               videoout_out.ce  <= '1';
            end if;
            
            hCropCount <= hCropCount + 1;
            
            case (state) is
            
               when WAITNEWLINE =>
                  videoout_out.hblank <= '1';
                  if (lineIn /= videoout_request.lineDisp) then
                     state <= WAITHBLANKEND;
                     videoout_request.lineDisp <= lineIn;
                     videoout_readAddr <= lineIn(0) & "00" & x"00";
                     if (videoout_settings.GPUSTAT_VerRes = '1') then -- interlaced mode
                        videoout_readAddr(10) <= lineIn(1);
                     end if;
                     videoout_request.xpos <= 0;
                     clkCnt                <= 0;
                     hCropCount            <= (others => '0');
                     hCropPixels           <= (others => '0');
                  end if;
            
               when WAITHBLANKEND =>
                  if (clkCnt >= (clkDiv - 1)) then
                     if (hCropCount >= videoout_settings.hDisplayRange(11 downto 0)) then
                        state       <= DRAW;
                        readstate   <= IDLE;
                        readstate24 <= READ24_0;
                     end if;
                  end if;
                  
               when DRAW =>
                  if (clkCnt >= (clkDiv - 1)) then
                     videoout_out.ce     <= '1';
                     videoout_out.hblank <= '0';
                     if (overlay_ena = '1') then
                        videoout_out.r      <= overlay_data( 7 downto 0);
                        videoout_out.g      <= overlay_data(15 downto 8);
                        videoout_out.b      <= overlay_data(23 downto 16);
                     elsif (videoout_settings.GPUSTAT_DisplayDisable = '1' or ce = '0') then
                        videoout_out.r      <= (others => '0');
                        videoout_out.g      <= (others => '0');
                        videoout_out.b      <= (others => '0');
                     else
                        videoout_out.r      <= pixelData_R;
                        videoout_out.g      <= pixelData_G;
                        videoout_out.b      <= pixelData_B;
                     end if;
                     
                     if (videoout_request.xpos < 1023) then
                        videoout_request.xpos <= videoout_request.xpos + 1;
                     end if;
                     
                     hCropPixels <= hCropPixels + 1;
                     if (((hCropCount + 1) >= videoout_settings.hDisplayRange(23 downto 12))) then
                        if ((hCropPixels + 1) = 0) then
                           state       <= WAITNEWLINE;
                           xmax        <= videoout_request.xpos + 1;
                        end if;
                     end if;
                     
                  end if;

                  case (readstate) is
            
                     when IDLE =>
                        if (clkCnt = 0) then
                           if (videoout_settings.GPUSTAT_ColorDepth24 = '1') then
                              videoout_readAddr  <= videoout_readAddr + 1;
                              if (videoout_request.xpos = 0 or readstate24 = READ24_0) then
                                 readstate <= READ24_0;
                              else
                                 readstate <= READ24_8;
                              end if;
                           else
                              readstate <= READ16;
                           end if;
                        end if;
      
                     when READ16 =>
                        readstate          <= IDLE;
                        videoout_readAddr  <= videoout_readAddr + 1;
                        pixelData_R        <= videoout_pixelRead( 4 downto  0) & videoout_pixelRead( 4 downto 2);
                        pixelData_G        <= videoout_pixelRead( 9 downto  5) & videoout_pixelRead( 9 downto 7);
                        pixelData_B        <= videoout_pixelRead(14 downto 10) & videoout_pixelRead(14 downto 12);
                        
                     when READ24_0 =>
                        readstate          <= READ24_16;
                        pixelData_R        <= videoout_pixelRead( 7 downto  0);
                        pixelData_G        <= videoout_pixelRead(15 downto  8);
                     
                     when READ24_8 =>
                        readstate          <= READ24_24;
                        pixelData_R        <= videoout_pixelRead(15 downto  8);
                        
                     when READ24_16 =>
                        readstate          <= IDLE;
                        readstate24        <= READ24_8;
                        pixelData_B        <= videoout_pixelRead( 7 downto  0);
                  
                     when READ24_24 =>
                        readstate          <= IDLE;
                        readstate24        <= READ24_0;
                        videoout_readAddr  <= videoout_readAddr + 1;
                        pixelData_G        <= videoout_pixelRead( 7 downto  0);
                        pixelData_B        <= videoout_pixelRead(15 downto  8);
            
                  end case;
               
            end case;
            
            hsync_start <= 32;
            
            if (nextHCount = hsync_start) then 
               hsync_end <= 252;
               videoout_out.hsync <= '1'; 
            end if;
               
            if (hsync_end > 0) then
               hsync_end <= hsync_end - 1;
               if (hsync_end = 1) then 
                  videoout_out.hsync <= '0';
               end if;
            end if;

            vsync_hstart := hsync_start;
            vsync_vstart := 242;
            if (videoout_settings.GPUSTAT_VertInterlace = '1' and InterlaceFieldN = '0' and videoout_settings.syncInterlace = '0') then
               -- half line later
               vsync_hstart := 32 + 3413/2;
               vsync_vstart := vsync_vstart + 1;
            end if;

            if (nextHCount = vsync_hstart) then
               if (vpos = vsync_vstart    ) then videoout_out.vsync <= '1'; end if;
               if (vpos = vsync_vstart + 3) then 
                  videoout_out.vsync <= '0'; 
                  if (videoout_settings.GPUSTAT_VertInterlace = '1') then
                     videoout_reports.GPUSTAT_InterlaceField <= not videoout_reports.GPUSTAT_InterlaceField;
                  else
                     videoout_reports.GPUSTAT_InterlaceField <= '0';
                  end if;
               end if;
            end if;
            
            if (softReset = '1') then
               videoout_reports.GPUSTAT_InterlaceField <= '1';
            end if;
         
         end if;
         
      end if;
   end process; 

end architecture;





