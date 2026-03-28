# airdrop

Small macOS CLI that opens the system AirDrop sharing flow for files and optional text or URL content.

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
airdrop --text "hello world"
airdrop --text "https://example.com"
airdrop --dry-run --text "https://example.com" /path/to/file
pbpaste | airdrop
printf 'https://example.com\n' | airdrop /path/to/file
```

## Build

```bash
swift build
```

## Run From Source

```bash
swift run airdrop /path/to/file
swift run airdrop /path/to/file1 /path/to/file2
swift run airdrop --text "hello world"
swift run airdrop --dry-run --text "https://example.com" /path/to/file
printf 'https://example.com\n' | swift run airdrop /path/to/file
```

Or after building:

```bash
.build/debug/airdrop /path/to/file
```

Positional arguments are treated as file paths and must exist. Text input comes from
either `--text` or stdin, is trimmed, and is shared as a URL when the trimmed value
matches a full link. Other text is written to a temporary `/tmp/*.txt` file and
shared as a file.

Use `--dry-run` to print the parsed items instead of opening the AirDrop UI.

The command validates the inputs, invokes the macOS AirDrop sharing service, and
stays alive until the share completes or fails.
