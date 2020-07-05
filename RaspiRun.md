# Running crystowl-nest on Raspbian

To run this bot on a Raspberry Pi, the path is a bit bumpy, but it is possible.

This guide was tested for the Raspberry Pi 3, so other versions might require slight adjustments.

## Prerequisites

* A working Debian distribution (can be on WSL, tested with Kali Linux)
* Crystal installed on Debian (see https://crystal-lang.org/install/on_debian/)
* An SSH connection to the Raspberry Pi accessable from the Debian distribution

For WSL it is a bit more complicated to install Crystal. The script in the guide above might not work and you might need to edit the ```/etc/apt/sources.list.d/crystal.list``` for yourself with the required content.

## Compiling crystal for Raspbian

### Cross-compiling crystal

First, you need to clone Crystal into a dedicated development folder (here assumed to be ```~/Dev```) on your Debian machine.

```console
user@debian:~/Dev$ git clone https://github.com/crystal-lang/crystal
user@debian:~/Dev$ cd crystal
```

Then, make sure to use a recent Crystal release version (here ```0.35.0``` was used, but it can be newer).

```console
user@debian:~/Dev/crystal$ git checkout 0.35.0
```

Install also LLVM of a SPECIFIC minor version (this is VERY important, as you need the same version later on for Raspbian). In this example, LLVM 9.0.1 is used (the version can be checked using ```llvm-config-9 --version```:

```console
user@debian:~/Dev/crystal$ sudo apt install llvm-9-dev
```

Now, you can build the Crystal object file for the ARM architecture of the Raspberry Pi. The second command will take some time to run.

```console
user@debian:~/Dev/crystal$ make deps
user@debian:~/Dev/crystal$ ./bin/crystal build src/compiler/crystal.cr --cross-compile --target "armv6-unknown-linux-gnueabihf" --release -s -D without_openssl -D without_zlib
```

If everything went well, a file named ```crystal.o``` should now appear in the directory. Otherwise make sure to install any missing libraries mentioned in the install guide or error message (see also https://github.com/crystal-lang/crystal/wiki/All-required-libraries).

### Installing Crystal on the Raspberry Pi

Now switch to the Raspberry shell. Essentially you do the same steps as for Debian. Once again, it is important to have the exact same version of LLVM on both devices.

```console
user@raspbian:~/Dev$ git clone https://github.com/crystal-lang/crystal
user@raspbian:~/Dev$ cd crystal
user@raspbian:~/Dev/crystal$ git checkout 0.35.0
user@raspbian:~/Dev/crystal$ sudo apt install llvm-9-dev
user@raspbian:~/Dev/crystal$ make deps
```

The next step is to copy the object file from Debian to Raspbian:

```console
user@debian:~/Dev/crystal$ scp crystal.o user@raspbian:~/Dev/crystal/crystal.o
```

Switch to Raspbian again and create some directories for later use. Depending on your access rights on these, you can ignore the ```sudo``` here and later on.

```console
user@raspbian:~/Dev/crystal$ sudo mkdir -p /usr/share/crystal /usr/lib/crystal/bin 
user@raspbian:~/Dev/crystal$ sudo cp -R src /usr/share/crystal/src
```

You most likely also need to install additional libraries (see https://github.com/crystal-lang/crystal/wiki/All-required-libraries for a list). Then, finally compile the object file to an executable:

```console
user@raspbian:~/Dev/crystal$ sudo cc 'crystal.o' -o '/usr/lib/crystal/bin/crystal' -rdynamic /usr/share/crystal/src/llvm/ext/llvm_ext.o `/usr/bin/llvm-config-9 --libs --system-libs --ldflags 2> /dev/null` -lstdc++ -lpcre -lm -lgc -lz -lpthread /usr/share/crystal/src/ext/libcrystal.a -levent -lrt -ldl -L/usr/lib -L/usr/local/lib
```

If this works without an error, you may rejoice. Otherwise, make sure to install all missing libraries, check your LLVM version again and check each step you did again. If you need to clean up, also remove ```/usr/share/crystal``` and ```/usr/lib/crystal/bin``` completely and do all steps from the beginning again.

If everything went well, go to Debian again and copy the last required file to the Raspberry:

```console
user@debian:~/Dev/crystal$ scp /usr/bin/crystal user@raspbian:/usr/bin/crystal
```

This might yield an permission error, in which case you need to give yourself the rights to access the file on the Raspberry:

```console
user@raspbian:~/Dev/crystal$ sudo touch /usr/bin/crystal
user@raspbian:~/Dev/crystal$ sudo chown /usr/bin/crystal
```

Then, try to copy the file again. Afterwards, make the file executable, if necessary:

```console
user@debian:~/Dev/crystal$ chmod u+x /usr/bin/crystal
```

### Installing Shards

One step is still missing, namely the crystal dependency manager Shards. To install it, clone the repository first:

```console
user@raspbian:~/Dev/crystal$ cd .. 
user@raspbian:~/Dev$ git clone https://github.com/crystal-lang/shards.git
user@raspbian:~/Dev$ cd shards
user@raspbian:~/Dev/shards$ git checkout v0.11.1
```

Now, download the newest tar.gz release from https://github.com/crystal-lang/crystal-molinillo/releases/ (either on the Raspberry or on Debian, in which case you need to scp it to the Raspberry then). Create a ```lib``` folder:

```console
user@raspbian:~/Dev/shards$ mkdir lib
```

Unpack the contents of the tar.gz archive in this directory.

Rename the directory simply to ```molinillo```, for example (depending on its version):

```console
user@raspbian:~/Dev/shards$ mv crystal-molinillo-0.1.0/ molinillo/
```

Finally, build Shards:

```console
user@raspbian:~/Dev/shards$ crystal build src/shards.cr -o /usr/lib/crystal/bin/shards --release
```

If an error occurs, check missing libraries and all previous steps. Otherwise, you just build the Shards executable. Create links to it:

```console
user@raspbian:~/Dev/shards$ ln -s /usr/lib/crystal/bin/shards /usr/bin
```

Then, Crystal and Shards should be ready to use!
Do a last test to ensure both programs can be used.

```console
user@raspbian:~/Dev/shards$ cd ..
user@raspbian:~/Dev$ crystal --version
user@raspbian:~/Dev$ shards --version
```

## Compiling Crystowl-Nest

If Crystal and Shards are working, clone this repository to your Raspberry, build the shards and compile it:

```console
user@raspbian:~/Dev$ git clone https://github.com/Hadeweka/crystowl-nest
user@raspbian:~/Dev$ cd crystowl-nest
user@raspbian:~/Dev/crystowl-nest$ shards install
user@raspbian:~/Dev/crystowl-nest$ crystal build src/crystowl-nest --release
```

Debug versions might yield lengthy weird error messages for some reason, so just compile the release version directly.

## Running it

Set your Telegram Bot API Key (replace ```XXX:XXX``` with the actual key and ```CONFIG_NAME``` with the name of your own configuration) and run it:

```console
user@raspbian:~/Dev/crystowl-nest$ ./crystowl-nest XXX:XXX CONFIG_NAME
```

Done!
