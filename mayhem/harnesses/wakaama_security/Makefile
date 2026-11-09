APPLICATION = fuzzing_wakaama_security
RIOTBASE ?= $(CURDIR)/../../..

TOOLCHAIN ?= afl
BOARD ?= native
FEATURES_REQUIRED += arch_native

CFLAGS += -ggdb

# the default 5 KiB pool is smaller than the TLSF control block on a 64-bit host
CFLAGS += -DCONFIG_LWM2M_TLSF_BUFFER=65536

USEMODULE += gnrc_ipv6
USEMODULE += fuzzing
USEMODULE += ssp
USEMODULE += sema_inv
USEPKG += wakaama

DEVELHELP ?= 1

include $(RIOTBASE)/Makefile.include
