#
# Generic makefile to cross compile and debug Intel Edison projects (using Docker)
#
# Copyright (c) 2018 Jelle Roets
# ===============================

# Project config: Specify Target name, main source folder, extra library folders and build output directory 
TARGET = HelloBlink
SRCDIR = src
LIBDIRS =
OBJDIR = obj

# Remote config: Make sure this host has ssh access to the remote (add correct ssh key to the remote device)
USERNAME = root
ADDRESS = 192.168.1.19
DEBUG_PORT = 9876
REMOTE_BIN = /home/root/bin
REMOTE_PROJECT = /home/root/projects

# Docker config: Make sure this host computer has Docker installed (https://docs.docker.com/install/)
# Flags: -i: interactive; --rm: remove container on exit; -v: mount current working dir as /workspace folder as well as extra library dirs; -w: set working dir; --entrypoint=: overwrite default entrypoint to null
# Following docker image is automatically pulled and installed on the first run (this can take a couple of minutes)
IMAGE = inteliotdevkit/intel-iot-yocto
DOCKER_WORKSPACE = /workspace
DOCKER = docker run
MOUNT_LIBS = $(foreach dir, $(realpath $(LIBDIRS)), -v $(dir):$(DOCKER_WORKSPACE)/$(notdir $(dir)))
DOCKERFLAGS = -i --rm -v $(CURDIR):$(DOCKER_WORKSPACE) $(MOUNT_LIBS) -w $(DOCKER_WORKSPACE) --entrypoint=

# Compiler config:
# -c: compile only, do not link; -glevel: include debugging info; -olevel: optimization level; -MMD:also produce make dependancy files; -Wall: all standard warnings 
CC = i586-poky-linux-gcc
CPP = i586-poky-linux-g++
LIBDIRS_InWorkspace = $(notdir $(patsubst %/,%,$(LIBDIRS)))
CFLAGS = 
CPPFLAGS = -m32 -march=i586 -std=c++11 -c -g -O0 $(addprefix -I, $(LIBDIRS_InWorkspace)) -MMD -MP -Wall -ffunction-sections -fdata-sections
LDFLAGS = -m32 -march=i586 -O0
LDLIBS = -lmraa

# Compilation Rules
# -----------------

# Dockerize build targets: in case a make command for building sources is invoked on the host machine: redirect make command to docker container
ifeq ($(wildcard /.dockerenv),)
$(TARGET) all: FORCE
	$(DOCKER) $(DOCKERFLAGS) $(IMAGE) make $@
FORCE:

else  

# Build targets in docker container:
# add source files in source directory and (mounted) library dirs to source file list
SRC = $(wildcard $(SRCDIR)/*.c??)
SRC += $(foreach dir, $(LIBDIRS_InWorkspace), $(wildcard $(dir)/*.c??))
OBJECT_FILES = $(addprefix $(OBJDIR)/, $(addsuffix .o, $(patsubst $(SRCDIR)/%, %, $(basename $(SRC)))))
DEPENDENCY_FILES = $(OBJECT_FILES:%.o=%.d)

$(shell mkdir -p $(sort $(dir $(OBJECT_FILES))) / 2> /dev/null)
VPATH += $(sort $(dir $(SRC)))

all: $(TARGET)

$(TARGET): $(OBJECT_FILES) 
	$(CPP) $(LDFLAGS) $(LDLIBS) $^ -o $@ 

$(OBJDIR)/%.o : %.cpp
	$(CPP) $(CPPFLAGS) $< -o $@

$(OBJDIR)/%.o : %.cxx
	$(CPP) $(CPPFLAGS) $< -o $@

-include $(DEPENDENCY_FILES)

endif

# Other rules
# ------------

# Upload the binary to the given remote binary folder (and build when necessary)
upload: $(TARGET)
	ssh $(USERNAME)@$(ADDRESS) killall -q $(TARGET) || true
	scp $(TARGET) $(USERNAME)@$(ADDRESS):$(REMOTE_BIN)

# Upload and run the binary TODO: run via shell + correct cwd
run: upload
	ssh -t $(USERNAME)@$(ADDRESS) $(REMOTE_BIN)/$(TARGET)

# Upload all source files + binaries (can be useful for debugging on remote over ssh) TODO: handle libraries
uploadSrc: upload
	rsync -r -h --exclude={.*/,$(OBJDIR)} . $(USERNAME)@$(ADDRESS):$(REMOTE_PROJECT)/$(TARGET)

# Upload binary and start gdbserver for this program
debug: upload
	ssh -t $(USERNAME)@$(ADDRESS) gdbserver :$(DEBUG_PORT) $(REMOTE_BIN)/$(TARGET)

# Remove all build artifacts and the final binary 
clean:
	-rm -rf $(OBJDIR) $(TARGET)

.PHONY: all upload run uploadSrc debug clean