.SECONDARY:
PREFIX ?= arm-none-eabi
CC      = $(PREFIX)-gcc
LD      = $(PREFIX)-gcc
AR      = $(PREFIX)-ar
OBJCOPY = $(PREFIX)-objcopy

ARCH_FLAGS  = -mthumb -mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16
DEFINES     = -DEFM32GG11B820F2048GL192

INCLUDES    = -Iefm32-base/device/EFM32GG11B/Include \
              -Iefm32-base/cmsis/Include -Iefm32-base/emlib/inc


ifndef CRYPTO_ITERATIONS
CRYPTO_ITERATIONS=1
endif

ifndef PRECOMPUTE_BITSLICING
PRECOMPUTE_BITSLICING=0
endif

ifndef USE_HARDWARE_CRYPTO
USE_HARDWARE_CRYPTO=0
endif

CFLAGS += -O3 \
          -Wall -Wextra -Wimplicit-function-declaration \
          -Wredundant-decls -Wmissing-prototypes -Wstrict-prototypes \
          -Wundef -Wshadow \
		  -ffunction-sections -fdata-sections \
          -fno-common $(ARCH_FLAGS) -MD $(DEFINES) $(INCLUDES) -DCRYPTO_ITERATIONS=$(CRYPTO_ITERATIONS) -DPRECOMPUTE_BITSLICING=$(PRECOMPUTE_BITSLICING) -DUSE_HARDWARE_CRYPTO=$(USE_HARDWARE_CRYPTO)

EFM32GG11BOBJ    = GCC/startup_efm32gg11b.o system_efm32gg11b.o
LIBEFM32GG11BOBJ = $(addprefix build/efm32-base/device/EFM32GG11B/Source/,$(EFM32GG11BOBJ))
LIBEFM32GG11B    = build/efm32-base/device/EFM32GG11B/libdevice.a

EMLIBSRC = $(wildcard efm32-base/emlib/src/*.c)
EMLIBOBJ = $(addprefix build/,$(EMLIBSRC:.c=.o))
EMLIB    = build/efm32-base/emlib/emlib.a

LDSCRIPT = efm32-base/device/EFM32GG11B/Source/GCC/efm32gg11b.ld
LDFLAGS  =  $(ARCH_FLAGS) -Wl,--gc-sections -fno-builtin -ffunction-sections -fdata-sections \
           -fomit-frame-pointer -T$(LDSCRIPT) -lgcc -lc -lnosys -lm \
           $(LIBEFM32GG11B) $(EMLIB)

CC_HOST    = gcc
LD_HOST    = gcc

CFLAGS_HOST = -O3 -Wall -Wextra -Wpedantic
LDFLAGS_HOST = -lm

# override as desired
TYPE=kem

COMMONSOURCES=common/fips202.c common/sp800-185.c common/nistseedexpander.c
COMMONSOURCES_HOST=$(COMMONSOURCES) common/keccakf1600.c common/aes-ref.c  common/sha2-ref.c  common/sha2.c
COMMONSOURCES_M4=$(COMMONSOURCES) common/keccakf1600.S common/aes.c common/aes-encrypt.S common/aes-keyschedule.S common/sha2.c common/crypto_hashblocks_sha512.c common/crypto_hashblocks_sha512_inner32.s common/hal-efm32gg.c common/hal-efm32gg-aes.c common/hal-efm32gg-sha2.c

COMMONINCLUDES=-I"common"
COMMONINCLUDES_M4=$(COMMONINCLUDES)

RANDOMBYTES_M4=common/randombytes.c

DEST_HOST=bin-host
DEST=bin
TARGET_NAME = $(shell echo $(IMPLEMENTATION_PATH) | sed 's@/@_@g')
TYPE = $(shell echo $(IMPLEMENTATION_PATH) | sed 's@^\([^/]*/\)*crypto_\([^/]*\)/.*$$@\2@')
IMPLEMENTATION_SOURCES = $(wildcard $(IMPLEMENTATION_PATH)/*.c) $(wildcard $(IMPLEMENTATION_PATH)/*.s) $(wildcard $(IMPLEMENTATION_PATH)/*.S)
IMPLEMENTATION_HEADERS = $(IMPLEMENTATION_PATH)/*.h



.PHONY: all
all: lib
	@echo "Missing arguments. Specify IMPLEMENTATION_PATH and a target binary, e.g.,"
	@echo "make IMPLEMENTATION_PATH=crypto_sign/rainbowI-classic/m4 bin/crypto_sign_rainbowI-classic_m4_test.bin"

$(DEST_HOST)/%_testvectors: $(COMMONSOURCES_HOST) $(IMPLEMENTATION_SOURCES) $(IMPLEMENTATION_HEADERS)
	mkdir -p $(DEST_HOST)
	$(CC_HOST) -o $@ \
		$(CFLAGS_HOST) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE)\
		crypto_$(TYPE)/testvectors-host.c \
		$(COMMONSOURCES_HOST) \
		$(IMPLEMENTATION_SOURCES) \
		-I$(IMPLEMENTATION_PATH) \
		$(COMMONINCLUDES) \
		$(LDFLAGS_HOST)

$(DEST)/%.bin: elf/%.elf
	mkdir -p $(DEST)
	$(OBJCOPY) -Obinary $^ $@


elf/$(TARGET_NAME)_%.elf: crypto_$(TYPE)/%.c $(COMMONSOURCES_M4) $(RANDOMBYTES_M4) $(IMPLEMENTATION_SOURCES) $(IMPLEMENTATION_HEADERS) $(EMLIB) $(LIBEFM32GG11B) lib
	mkdir -p elf
	$(CC) -o $@ $(CFLAGS) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE) \
		$< $(COMMONSOURCES_M4) $(RANDOMBYTES_M4) $(IMPLEMENTATION_SOURCES) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $(LDFLAGS)


elf/$(TARGET_NAME)_testvectors.elf: crypto_$(TYPE)/testvectors.c $(COMMONSOURCES_M4) $(IMPLEMENTATION_SOURCES) $(IMPLEMENTATION_HEADERS) $(EMLIB) $(LIBEFM32GG11B) lib
	mkdir -p elf
	$(CC) -o $@ $(CFLAGS) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE)\
		$< $(COMMONSOURCES_M4) $(IMPLEMENTATION_SOURCES) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $(LDFLAGS)

elf/$(TARGET_NAME)_codesize.elf: crypto_$(TYPE)/codesize.c $(COMMONSOURCES_M4) $(RANDOMBYTES_M4) $(IMPLEMENTATION_SOURCES) $(IMPLEMENTATION_HEADERS) $(EMLIB) $(LIBEFM32GG11B) lib
	mkdir -p elf
	$(CC) -o $@ $(CFLAGS) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE) \
		$< $(COMMONSOURCES_M4) $(RANDOMBYTES_M4) $(IMPLEMENTATION_SOURCES) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $(LDFLAGS) -DINCLUDE_KEYGEN=$(INCLUDE_KEYGEN) -DINCLUDE_SIGN=$(INCLUDE_SIGN) -DINCLUDE_VERIFY=$(INCLUDE_VERIFY) -DINCLUDE_AES=$(INCLUDE_AES) -DINCLUDE_SHA2=$(INCLUDE_SHA2)

elf/$(TARGET_NAME)_nistkat.elf: crypto_$(TYPE)/nistkat.c $(COMMONSOURCES_M4) $(IMPLEMENTATION_SOURCES) $(IMPLEMENTATION_HEADERS) $(EMLIB) $(LIBEFM32GG11B) lib
	mkdir -p elf
	$(CC) -o $@ $(CFLAGS) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE)\
		$< $(COMMONSOURCES_M4) $(IMPLEMENTATION_SOURCES) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $(LDFLAGS)

elf/$(TARGET_NAME)_hashing.elf: crypto_$(TYPE)/hashing.c $(COMMONSOURCES_M4) $(IMPLEMENTATION_SOURCES) $(IMPLEMENTATION_HEADERS) $(EMLIB) $(LIBEFM32GG11B) lib
	mkdir -p elf
	$(CC) -o $@ $(CFLAGS) -DPROFILE_HASHING -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE) \
		$< $(COMMONSOURCES_M4) $(RANDOMBYTES_M4) $(IMPLEMENTATION_SOURCES) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $(LDFLAGS)

obj/$(TARGET_NAME)_%.o: $(IMPLEMENTATION_PATH)/%.c $(IMPLEMENTATION_HEADERS)
	mkdir -p obj
	$(CC) -o $@ -c $(CFLAGS) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $<

obj/$(TARGET_NAME)_%.o: $(IMPLEMENTATION_PATH)/%.s $(IMPLEMENTATION_HEADERS)
	mkdir -p obj
	$(CC) -o $@ -c $(CFLAGS) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $<

obj/$(TARGET_NAME)_%.o: $(IMPLEMENTATION_PATH)/%.S $(IMPLEMENTATION_HEADERS)
	mkdir -p obj
	$(CC) -o $@ -c $(CFLAGS) -DMUPQ_NAMESPACE=$(MUPQ_NAMESPACE) \
		-I$(IMPLEMENTATION_PATH) $(COMMONINCLUDES_M4) $<


$(EMLIB): $(EMLIBOBJ)
	$(AR) qc $@ $?

$(LIBEFM32GG11B): $(LIBEFM32GG11BOBJ)
	$(AR) qc $@ $?

build/%.o: %.S
	mkdir -p $(@D)
	$(CC) -o $@ -c $(CFLAGS) $<

build/%.o: %.c
	mkdir -p $(@D)
	$(CC) -o $@ -c $(CFLAGS) $<


lib:
	@if [ ! -d efm32-base ] ; then \
		printf "######## ERROR ########\n"; \
		printf "\tefm32-base not found.\n"; \
		printf "\tPlease run :\n"; \
		printf "\t$$ git clone https://github.com/ryankurte/efm32-base\n"; \
		printf "\t$$ cd efm32-base && git checkout ac1c323 && cd ..\n"; \
		printf "\tbefore running make.\n"; \
		printf "######## ERROR ########\n"; \
		exit 1; \
		fi

.PHONY: clean libclean
clean:
	rm -rf elf/
	rm -rf bin/
	rm -rf bin-host/
	rm -rf obj/
	rm -rf testvectors/
	rm -rf benchmarks/
	rm -rf build

libclean:
	rm -rf build/
