LIBS_LOCALDIR:=$(dir $(lastword $(MAKEFILE_LIST)))

LIB_OBJS = 
libs: libc install-libs
CFLAGS += -Istage2/libs/libc/include/
include $(LIBS_LOCALDIR)/libc/Makefile

install-libs:
	@mkdir -p $(LIBS_LOCALDIR)/lib_archives
	@mv $(LIBS_LOCALDIR)/libc/*.a $(LIBS_LOCALDIR)/lib_archives/

clean_libs:
	rm -rf $(LIBS_LOCALDIR)/lib_archives/ $(LIB_OBJS)
