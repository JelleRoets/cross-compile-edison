# Generic makefile to cross compile and debug Intel Edison projects (using Docker)
A generic, platform and IDE independent makefile to cross compile  c/c++ projects for Intel Edison (or others) in a docker container. It also contains rules to upload and debug the project on the remote target.

## Motivation and use-cases
You are developing a c/c++ project for your Intel Edison board but you don't want or simply can't use the development environment that intel provides: [Intel System Studio (iot edition)](https://software.intel.com/en-us/iot/tools-ide/ide/iss-iot-edition), which is actually a version of Eclipse IDE, extended with scripts and toolchains to compile, upload and debug code. The advantages of using System Studio anyway: it (more or less) works out of the box and you don't need a profound understanding to get started with your first HelloWorld project, so definitely a good choice for beginners. The downside however: when your project starts to grow, it becomes very hard (or even impossible) to handle and configure: finding the necessary settings in this obfuscated environment is a challenge. For example: compiling and linking an external folder with libraries into your project is not trivial and not documented.

Finally Mac Osx >= 10.13 (High Sierra) users are screwed: the original and deprecated [Intel System Studio IoT edition](https://software.intel.com/en-us/intel-system-studio-iot-edition-guide-for-c-installing-on-mac) does not work on OSX 10.13 and above. Instead Intel suggests to use the generic [Intel System Studio](https://software.intel.com/en-us/system-studio), however the mac-version  doesn't contain the toolchains necessary to compile for Intel Edison.

This makefile is an alternative to these constrains. All necessary (build, upload and debug) rules and settings are contained in this single makefile, which makes development completely platform and IDE independent. You can just use your favorite text editor or IDE, like [Sublime](https://www.sublimetext.com/), [Vim](https://www.vim.org/), [VSCode](https://code.visualstudio.com/), [Atom](https://atom.io/), or whatever you're used to use. 
Since all build rules are clearly written in this makefiles, you can easily customize and extend this makefile according to your project needs.

The makefile in this repository is written to compile a simple HelloWorld program for the Intel Edison platform. However by  changing the dockerimage in the makefile, it can also be used to cross-compile projects for many other platforms e.g. Raspberry-Pi, Beaglebone, Intel Galileo, Joule, etc. 

## Usage
### Prerequisites
- *Make*: usually comes preinstalled on all *nix platforms. To understand what a makefile is or how to read / develop it, please check the [documentation](https://www.gnu.org/software/make/)
- *Docker*: install [Docker CE](https://docs.docker.com/install/). To understand what Docker is and how to use it, please check the [documentation](https://docs.docker.com/get-started/)
- ssh access to the remote target: [Generate and add sshkey to the remote device](https://www.ssh.com/ssh/copy-id)

### Understand and customize the makefile
The makefile starts with some configuration parameters:
- Project config:
    - `TARGET`: Name of the target to be build, the final executable will have this name
    - `SRCDIR`: Main source folder
    - `LIBDIRS`: Extra directories to be build and linked into this project
    - `OBJDIR`: Folder used to output build files (object and dependency files)
- Remote config:
    - `USERNAME`: User name to login in to the remote target (usually root)
    - `ADDRESS`: IP address of the remote target (usually a local address 192.168.x.y)
    - `DEBUG_PORT`: TCP port used for debugging (can be any unused port number)
    - `REMOTE_BIN`: Folder on the remote to install executable binary
    - `REMOTE_PROJECT`: Folder on the remote to upload full project including source files (can be useful to debug directly on the remote, see further)
- Docker config:
    - `IMAGE`: Docker image to use as container to build the project. For Intel Edison this is "inteliotdevkit/intel-iot-yocto" which is a public free image on the docker hub. If you wouldn't already have this docker image, docker will automatically download it while running this makefile for the first time, this can take a couple of minutes.
    - `DOCKER_WORKSPACE`: Folder in the docker container that is used as source folder. The `SRCDIR` as well as `LIBDIRS` are mounted as volumes in the workspace folder inside the docker container.
    - `DOCKER`: Docker command
    - `DOCKERFLAGS`: Flags used to start docker container
- Compiler config:
    - `CC`: C compiler (i586-poky-linux-gcc for Intel Edison)
    - `CPP`: Cpp compiler (i586-poky-linux-g++ for Intel Edison)
    - `CFLAGS`: Build flags to pass to the c compiler
    - `CPPFLAGS`: Build flags to pass to the cpp compiler
    - `LDFLAGS`: Linker flags
    - `LDLIBS`: extra libraries to link ([mraa](https://mraa.io) is an often used library to control GPIO pins on Intel edison)

Make targets:
- `all` or `$(TARGET)`: Will build entire project in docker container
- `upload`: Upload the executable binary to the remote binary folder (and build when necessary)
- `run`: Upload and run the binary
- `uploadSrc`: Upload all source files + binaries (can be useful for debugging on remote over ssh)
- `debug`: Upload binary and start gdbserver for remote debugging
- `clean`: Remove all build artifacts and the final binary 

You can build the project on your computer by opening a terminal in the folder of this makefile and simply invoking:
```
make
```
To build the project, upload the binary and run it on the remote invoke:
```
make run
```
If everything goes well the output should be something like this:
```
jelle@Jelles-MacBook-Pro:cross-compile-edison $ make run
docker run -i --rm -v /Users/jelle/github/cross-compile-edison:/workspace  -w /workspace --entrypoint= inteliotdevkit/intel-iot-yocto make HelloBlink
i586-poky-linux-g++ -m32 -march=i586 -std=c++11 -c -g -O0  -MMD -MP -Wall -ffunction-sections -fdata-sections src/HelloBlink.cpp -o obj/HelloBlink.o
i586-poky-linux-g++ -m32 -march=i586 -O0 -lmraa obj/HelloBlink.o -o HelloBlink
ssh root@192.168.1.19 killall -q HelloBlink || true
scp HelloBlink root@192.168.1.19:/home/root/bin
HelloBlink      100%   33KB 454.4KB/s   00:00
ssh -t root@192.168.1.19 /home/root/bin/HelloBlink
Hello, Internet of Things!
0 1 2 3 4 5 6 7 8 9
Bye.
Connection to 192.168.1.19 closed.
```

The advantage of cross-compilation in a docker container: for building the project and fixing compilation errors, you don't need a running device. You can call the `make` command on your host computer. This will automatically startup a docker container and re-invoke the same `make` command inside the docker container (using the same mounted makefile), which will actually build the project. After the build process the docker container is shut down and removed. This way we only need one makefile that contains all necessary logic. To determine if the makefile is called from the host or in the docker-container it checks the existence of a '/.dockerenv' file.

### Debugging
To step through your running program, you can use [gdb](https://www.gnu.org/software/gdb/), which is a cli utility to debug c/c++ programs. The `make debug` command will build and upload the project, afterwards it will also startup 'gdbserver' on the remote device for this project. On your host computer you can now start gdb and connect to the remote to start debugging.
```
gdb HelloBlink
> target remote [Host address]:[debug port]
```
Usually gdb comes preinstalled on Linux systems, Mac users can install it with
```
brew install gdb --with-all-targets
```
Although gdb is a powerful tool, it's not always easy to debug using a command line interface, luckily many IDE's come with a gdb plugin. See next section for an example.

## Example setup in VSCode
Everything discussed so far is still completely IDE independent, you can do everything just from the command line if you'd like. However a good IDE can make your life a lot easier and speedup development. What follows is an example setup of this project in [VSCode](https://code.visualstudio.com/) - a free and open source code editor developed by Microsoft, but you can probably integrate this in any IDE or text editor you want.

### Useful extensions:
VSCode out of the box is made for html - js / node projects. But you can develop c/c++ project just as easy with the help of some extensions. After installing VSCode, please also install the following extensions:
- [C/C++ development](https://marketplace.visualstudio.com/items?itemName=ms-vscode.cpptools)
- [Makefile support](https://marketplace.visualstudio.com/items?itemName=naereen.makefiles-support-for-vscode)
- [GDB debugging](https://marketplace.visualstudio.com/items?itemName=webfreak.debug)

### Include paths
To get useful feedback and intellisense during coding, it is necessary to let VSCode know where to find the used libraries and header files as used during compilation.
To give VSCode access to these files, you need to store them somewhere on your host computer. You can copy them either from the remote device itself or from the docker container. You basically need 2 folders: `/usr/include` and `/usr/lib`, store them in a folder like `.edisonSysroot` in your home folder. They are about 1GB (probably you actually don't need every file in those folders, but it's hard to filter only the necessary ones)
```
mkdir ~/.edisonSysroot
rsync -r -h -v [user]@[Host address]:/usr/include/ ~/.edisonSysroot/usr/include/
rsync -r -h -v [user]@[Host address]:/usr/lib/ ~/.edisonSysroot/usr/lib/
```
Alternatively you can also copy these folders from the docker image, this can be beneficial if your connection is slow or you don't have a running device.
```
docker run --name intel-iot-yocto-container inteliotdevkit/intel-iot-yoct
docker cp intel-iot-yocto-container:/usr/include/ ~/.edisonSysroot/usr/include/
docker cp intel-iot-yocto-container:/usr/lib/ ~/.edisonSysroot/usr/lib/
```

Next you need to specify the correct include paths in a VScode configuration file: `.vscode/c_cpp_properties.json`. This repository already contains such an [example](.vscode/c_cpp_properties.json). If you get started by cloning this repo en opening the folder in VSCode, you usually don't need to modify this json file, however you do need to first copy the sysroot folders as noted above. If you use a different path or folder, you need to match that in the json file as well.

### Specifying Tasks
You can also specify common tasks for you project in a [tasks.json](.vscode/tasks.json) file. In this case we simply add a task for every target in the makefile and mark the default `make` command as the default build task, this allows us to rapidly rebuild the project by using the shortkey to Run the Build Task.

### Setting up the debugger
In order to debug our project directly from VScode we need to specify some [launch](.vscode/launch.json) instructions. You can find 2 possible setups in this repository:
1. The first one uses the debugger that comes with the c/c++ development extension (`"type": "cppdbg"`) which can connect to a running gdbserver on the remote. In the launch.json file you also need to specify the target to debug (`"program": "${workspaceFolder}/HelloWorld"`) as well as the remote address to connect to (`"miDebuggerServerAddress": "[Host address]:[debug port]"`). To enhance debugging, gdb needs access to the library symbols linked into the project, you can do this by setting the sysroot of gdb to the same folder where you downloaded the `/usr/lib` folder. Important note: before you launch this configuration, you have to make sure gdbserver is already running on the remote, use the `make debug` target for this.
2. The second configuration comes from the extra extension GDB debugging (`"type": "gdb"`) and has a different approach: instead of running gdbserver on the remote and connecting with a locally running gdb session, this extensions directly runs gdb on the remote over ssh. In order to work, gdb on the remote device also needs access to the source files, for this we specified a `"preLaunchTask": "make uploadSrc"` which will automatically upload the source files to the remote before starting the debug session. 

The main advantage of this last approach is that you can start debugging with a single click on the 'Start Debugging (F5)' button and it runs more smoothly than the first approach. The disadvantage is that it needs the source files on the remote, which can be problematic when space is limited on the remote. Choose the approach that best fits your needs.

### Conclusion
This example integration of the generic makefile into VSCode IDE shows a fully-featured alternative to Intel System Studio Iot Edition for developing and debugging c/c++ projects for Intel Edison. This approach could be extended to other platforms and IDE's.

## Credits, feedback and contributions
This project was developed by Jelle Roets and tested on mac OSX 10.13 together with an Intel Edison. My incentive was to be able to continue my own project, but I released ([MIT](LICENSE)) this generic makefile together with an example project to hopefully help others, facing similar issue. If you would have any problems, comments, questions or suggestions: all feedback, improvements and extensions are very welcome: you can file an issue on github or even send a pull-request for this example project.

Thanks to [Mitch Allen](https://github.com/mitchallen/pi-hello-cross-compile) for his tutorial [How to cross-compile for Raspberry Pi](https://www.desertbot.io/blog/how-to-cross-compile-for-raspberry-pi/) that served as a good starting point for this tutorial!
