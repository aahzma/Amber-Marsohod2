iverilog -o qqq -g2005 -DSDRAM=1 -DICARUS=1 -DAMBER_A23_CORE=1 -DNOMEMORY=1 -csrclist_sdr -I../../../vlog/sdram/sdr_ctrl/trunk/rtl/core -I../../../vlog/sdram/sdr_ctrl/trunk/rtl/wb2sdrc -I../../../vlog/system/ -I../../../vlog/amber23/ -I../../../vlog/tb/