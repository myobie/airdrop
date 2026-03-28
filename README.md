# airdrop

Small macOS CLI that opens the system AirDrop sharing flow for one or more files.

Requires macOS 13 or newer.

## Install

```bash
./install.sh
```

This builds the release binary and installs it to `~/bin/airdrop`.

Add `~/bin` to your `PATH` if it is not already there:

```bash
export PATH="$HOME/bin:$PATH"
```

For a persistent setup, add that line to your shell profile.

## Usage

After installing:

```bash
airdrop /path/to/file
airdrop /path/to/file1 /path/to/file2
```

## Build

```bash
swift build
```

## Run From Source

```bash
swift run airdrop /path/to/file
swift run airdrop /path/to/file1 /path/to/file2
```

Or after building:

```bash
.build/debug/airdrop /path/to/file
```

The command validates the input paths, invokes the macOS AirDrop sharing service,
and stays alive until the share completes or fails.
