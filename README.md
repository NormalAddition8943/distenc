# distenc

**Distributed Batch x265 Encoder with Crop Detection**

`distenc` automates multi-pass H.265 encoding using ffmpeg and x265 with
dynamic crop detection. It enables distributed processing across many
machines by using a shared token directory to coordinate work.

## Features

- Distributed encoding via token file coordination
- Safe interrupt handling and in-progress token cleanup
- Auto crop detection from sampled timestamps
- High-quality two-pass x265 encoding with tuned presets
- Audio normalization using `dynaudnorm` and `loudnorm`

## Requirements (for each encoding machine)

- Python 3.7+
- ffmpeg and ffprobe in `PATH`
- Shared network filesystem (e.g., NFS or Samba) for source videos and token files

## Usage

On every worker machine, run the following:

```bash
./distenc \
  --inputs /readable-network-share/MyShowRemux/Season*/*.mkv ... \
  --output-dir /local/outputs/MyShow \
  --stats-dir /local/temp/stats/MyShow \
  --token-dir /writable-network-share/tokens/MyShow \
  [--jobs N]
```

## Arguments

- `--inputs One` or more video files to encode
- `--output-dir` Where encoded videos are saved
- `--stats-dir` Temp dir for x265 2-pass stats
- `--token-dir` Coordination dir for multi-host concurrency
- `--jobs` Max parallel encode jobs on this machine (default: 1)

- If you have a RAM drive, it's recommended to point `--stats-dir` at it 
  (such as `/dev/shm/` on Linux). The size used is typically ~200 MB/hr, and 
  is deleted once an encode finishes.

- To maximum throughput, increase parallel `--jobs` based on a machine's 
  available memory and number of physical cores. Each job uses two physical 
  cores and roughly 2 GB of memory. See the example below.


## Example Multi-Machine Setup

Two machines are available on the network: an Apple M1 with 8 GB of RAM 
an AMD Zen4 8-core (16-thread) PC with 16 GB; both are running Linux.
Based on the memory and cores available, the Apple will support 2 parallel
jobs and the AMD will support 4 parallel jobs.

An NFS shares the source TV shows read-only, and is mounted at mnt/videos on
both systems. It also shares a temporary directory with read-write permissions
that's mounted at /mnt/temp/tokens on both systems.

On the Apple M1:

```
./distenc -i /mnt/videos/MyShow/*/*.mkv -o ~/Videos/MyShow \
          -s /dev/shm/ -t /mnt/temp/MyShow -j 2
```

On the AMD Zen4:

```
./distenc -i /mnt/videos/MyShow/*/*.mkv -o ~/Videos/MyShow \
          -s /dev/shm/ -t /mnt/temp/MyShow -j 4
```

Note that the script will create the `MyShow` output and token 
subdirectories.
