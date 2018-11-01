onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /vga_controller/pixel_clock
add wave -noupdate /vga_controller/reset
add wave -noupdate /vga_controller/horizontal_sync
add wave -noupdate /vga_controller/vertical_sync
add wave -noupdate /vga_controller/blank
add wave -noupdate /vga_controller/s_fifo_read
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {834948 ns} 0}
quietly wave cursor active 1
configure wave -namecolwidth 225
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {1813352 ns} {2015275 ns}
