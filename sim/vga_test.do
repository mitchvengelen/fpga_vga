#################################
# VGA driver test file
#################################

restart -f

force pixel_clock 1 0, 0 {50 ns} -r 100

force enable	  "0"
force reset		  "1"

run 150

force reset "0"
run 50000000    