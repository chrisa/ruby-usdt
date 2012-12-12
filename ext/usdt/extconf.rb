require 'mkmf'

system("cd ../libusdt && make")
system("cp ../libusdt/usdt.h ../libusdt/*.a ./")
have_library('usdt')
have_header('usdt.h')

create_makefile('usdt')
