# System Tests

This directory contains scripts for black-box system-tests testing the whole stack from assembler to cpu-execution.

> [!TIP]   
> Maybe you are looking for the simulations in the ./sim directory?

## Prerequisites

- Install the [.NET 10 Sdk](https://dotnet.microsoft.com/en-us/download)
- Build the assembler
- Mark assembler (`./PicoAsm`) executable and add to `$PATH`
- Install [ghdl](https://github.com/ghdl/ghdl)

## Usage

Run all system-tests via the following command:

```shell
dotnet tests/system-tests.cs

# alternative on linux
chmod +x ./tests/system-tests.cs
./tests/system-tests.cs
```

> [!NOTE]   
> Execution of all system-tests may take a few minutes
