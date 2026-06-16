# Folder Size Comparison Tool

A Python utility that compares aggregated folder sizes from multiple source directories against a destination directory.

The script recursively scans all folders, calculates the total size of each top-level folder (including all nested files and subfolders), aggregates sizes from multiple source locations, and verifies whether the destination folder contains the expected data.

## Features

* Compare multiple source folders against a destination folder
* Recursive folder size calculation
* Aggregated size validation
* Detection of missing destination folders
* Detailed comparison log generation
* Execution time statistics
* UTF-8 log output
* Error handling for inaccessible files and directories

---

## Project Structure

```text
project/
│
├── compare_folders.py
├── compare_log.txt
├── README.md
├── .gitignore
│
├── folder1/
├── folder2/
└── destination/
```

---

## How It Works

### Example

Source folders:

```text
folder1/
└── Movies/
    ├── movie1.mkv (5 GB)
    └── movie2.mkv (5 GB)

folder2/
└── Movies/
    └── movie3.mkv (10 GB)
```

Destination folder:

```text
destination/
└── Movies/
    ├── movie1.mkv
    ├── movie2.mkv
    └── movie3.mkv
```

Calculated sizes:

```text
folder1/Movies      = 10 GB
folder2/Movies      = 10 GB
Aggregated Sources  = 20 GB

destination/Movies  = 20 GB
```

Result:

```text
OK
```

If the destination size differs from the aggregated source size:

```text
FAIL
```

If the destination folder does not exist:

```text
MISSING_IN_DEST
```

---

## Configuration

Edit the following variables inside the script:

```python
SOURCE_FOLDERS = [
    Path("./folder1"),
    Path("./folder2"),
]

DESTINATION_FOLDER = Path("./destination")
OUTPUT_LOG_PATH = Path("compare_log.txt")
```

You can add or remove source folders as needed.

---

## Installation

Requirements:

* Python 3.9+

Clone the repository:

```bash
git clone https://github.com/yourusername/folder-size-comparison.git
cd folder-size-comparison
```

---

## Usage

Run:

```bash
python compare_folders.py
```

Example output:

```text
Started at: 2026-08-01 10:00:00

Scanning folder: folder1
Scanning folder: folder2
Scanning folder: destination

Finished at: 2026-08-01 10:00:12
Total duration: 12 seconds

Total folders compared: 250
OK: 245
FAIL: 3
MISSING: 2
```

---

## Log File

The script generates:

```text
compare_log.txt
```

Example log entry:

```text
Folder: Movies

Aggregated size from sources: 21474836480 bytes

folder1: 10737418240 bytes
folder2: 10737418240 bytes

Destination path: destination/Movies
Destination size: 21474836480 bytes

Result: OK
```

---

## Result Codes

| Result          | Description                                    |
| --------------- | ---------------------------------------------- |
| OK              | Source aggregate size matches destination size |
| FAIL            | Size mismatch detected                         |
| MISSING_IN_DEST | Folder not found in destination                |

---

## Use Cases

* Backup verification
* NAS synchronization checks
* Data migration validation
* Media archive consistency checks
* Storage auditing

---

## Author

Created by Khayal Baylarov

Python utility for comparing aggregated folder sizes across multiple source directories.
