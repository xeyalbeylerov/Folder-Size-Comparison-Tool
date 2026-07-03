from __future__ import annotations

import argparse
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple

SOURCE_FOLDERS = [
    Path("./folder1"),
    Path("./folder2"),
]
DESTINATION_FOLDER = Path("./destination")
OUTPUT_LOG_PATH = Path("compare_log.txt")
DEFAULT_MIN_DEPTH = 1
DEFAULT_MAX_DEPTH = 1


def safe_file_size(path: Path) -> int:
    """
    Faylın ölçüsünü götürür və icazə xətası olsa 0 qaytarır.
    """
    try:
        return path.stat().st_size
    except OSError as exc:
        print(f"Warning: cannot read file size for {path}: {exc}")
        return 0


def gather_folder_sizes(root: Path, min_depth: int = DEFAULT_MIN_DEPTH, max_depth: int = DEFAULT_MAX_DEPTH) -> Dict[str, int]:
    """
    Verilmiş kök qovluğun altında bütün qovluqları gəzərək
    hər bir qovluğun ümumi ölçüsünü hesablayır.
    Ölçü həmin qovluğun daxilindəki bütün faylların cəmini ehtiva edir.
    Nəticədə fayl səviyyəsində yox, qovluq səviyyəsində 'folder size' alınır.
    """
    root = root.resolve()
    sizes: Dict[str, int] = {}

    print(f"Scanning folder: {root}")

    def on_walk_error(exc: OSError) -> None:
        print(f"Warning: cannot access {exc.filename}: {exc.strerror}")

    for dirpath, dirnames, filenames in os.walk(root, topdown=False, onerror=on_walk_error):
        current_dir = Path(dirpath)
        rel_path = os.path.relpath(current_dir, root)
        if rel_path == ".":
            continue

        total_size = 0

        for filename in filenames:
            file_path = current_dir / filename
            total_size += safe_file_size(file_path)

        for subdir in dirnames:
            child_rel = os.path.relpath(current_dir / subdir, root)
            total_size += sizes.get(child_rel, 0)

        sizes[rel_path] = total_size
        depth = len(rel_path.replace('\\', '/').split('/'))
        if min_depth <= depth <= max_depth:
            print(f"  scanned: {rel_path} -> {total_size} bytes")

    filtered_sizes = {
        path: size
        for path, size in sizes.items()
        if min_depth <= len(path.replace('\\', '/').split('/')) <= max_depth
    }
    print(f"Found {len(filtered_sizes)} folders at depth {min_depth}-{max_depth} under {root}\n")
    return filtered_sizes


def compare_aggregated_sizes(
    source_folders: List[Path],
    destination_folder: Path,
    source_sizes: List[Dict[str, int]],
    dest_sizes: Dict[str, int],
) -> Tuple[List[str], Dict[str, int]]:
    """
    Bütün source folderlərin ölçülərini relative path əsasında toplayır
    və destination folder ilə müqayisə edir.
    Burada müqayisə fayl səviyyəsində deyil, qovluq səviyyəsindədir.
    """
    entries: List[str] = []
    stats = {"TOTAL": 0, "OK": 0, "FAIL": 0, "MISSING": 0}

    # Bütün relative pathləri bir sırada toplayırıq
    all_rel_paths = set()
    for sizes in source_sizes:
        all_rel_paths.update(sizes.keys())
    all_rel_paths.update(dest_sizes.keys())
    all_rel_paths = sorted(all_rel_paths)

    print("Aggregating sizes from all source folders and comparing with destination...")

    for rel_path in all_rel_paths:
        stats["TOTAL"] += 1
        
        # Source folderlərdən toplanmış ölçü
        aggregated_size = sum(sizes.get(rel_path, 0) for sizes in source_sizes)
        
        # Destination folder ölçüsü
        dest_size = dest_sizes.get(rel_path)
        
        dest_path_str = str(destination_folder / rel_path)
        
        # Source paths siyahısı
        source_paths_list = []
        for i, source_folder in enumerate(source_folders):
            if rel_path in source_sizes[i]:
                source_paths_list.append(f"{source_folder.name}: {source_sizes[i][rel_path]} bytes")
            else:
                source_paths_list.append(f"{source_folder.name}: <missing>")
        
        if dest_size is None:
            result = "MISSING_IN_DEST"
            stats["MISSING"] += 1
            dest_size = 0
            dest_path_str = "<missing>"
        else:
            result = "OK" if aggregated_size == dest_size else "FAIL"
            stats[result] += 1

        entries.append(
            "\n".join(
                [
                    f"Folder: {rel_path}",
                    f"Aggregated size from sources: {aggregated_size} bytes",
                ]
                + [f"  {path_info}" for path_info in source_paths_list]
                + [
                    f"Destination path: {dest_path_str}",
                    f"Destination size: {dest_size} bytes",
                    f"Result: {result}",
                    "---",
                ]
            )
        )

    return entries, stats


def write_log(output_path: Path, entries: List[str], stats: Dict[str, int], start_time: datetime, end_time: datetime) -> None:
	"""
	UTF-8 formatında compare_log.txt faylı yaradır və nəticələri yazır.
	Timestamp məlumatlarını da daxil edir.
	"""
	output_path.parent.mkdir(parents=True, exist_ok=True)
	
	duration = end_time - start_time
	duration_seconds = duration.total_seconds()

	with output_path.open("w", encoding="utf-8") as output_file:
		output_file.write(f"Start time: {start_time.strftime('%Y-%m-%d %H:%M:%S')}\n")
		output_file.write(f"End time: {end_time.strftime('%Y-%m-%d %H:%M:%S')}\n")
		output_file.write(f"Duration: {int(duration_seconds)} seconds\n")
		output_file.write("\n")
		output_file.write("\n".join(entries))
		output_file.write("\n")
		output_file.write(f"Total folders compared: {stats['TOTAL']}\n")
		output_file.write(f"OK: {stats['OK']}\n")
		output_file.write(f"FAIL: {stats['FAIL']}\n")
		output_file.write(f"MISSING: {stats['MISSING']}\n")

	print(f"Log written to {output_path}\n")


def main() -> None:
	parser = argparse.ArgumentParser(description="Compare folder sizes between source and destination directories.")
	parser.add_argument("--source", "-s", action="append", nargs="+", default=[], help="One or more source folders to compare. Repeat as needed.")
	parser.add_argument("--destination", "-d", default=str(DESTINATION_FOLDER), help="Destination folder to compare against.")
	parser.add_argument("--min-depth", type=int, default=DEFAULT_MIN_DEPTH, help="Minimum folder depth to include, relative to each root folder.")
	parser.add_argument("--max-depth", type=int, default=DEFAULT_MAX_DEPTH, help="Maximum folder depth to include, relative to each root folder.")
	parser.add_argument("--output", "-o", default=str(OUTPUT_LOG_PATH), help="Path to the output log file.")
	args = parser.parse_args()

	if args.min_depth < 1:
		raise SystemExit("--min-depth must be at least 1")
	if args.max_depth < args.min_depth:
		raise SystemExit("--max-depth must be greater than or equal to --min-depth")

	source_folders = [Path(item) for group in args.source for item in group] if args.source else SOURCE_FOLDERS
	destination_folder = Path(args.destination)
	output_log_path = Path(args.output)

	if len(source_folders) == 0:
		raise SystemExit("At least one source folder must be provided via --source.")

	start_time = datetime.now()
	print(f"Started at: {start_time.strftime('%Y-%m-%d %H:%M:%S')}\n")

	# Source folderlərin yoxlanılması
	for i, folder in enumerate(source_folders):
		if not folder.exists() or not folder.is_dir():
			raise SystemExit(f"Source folder {i + 1} is not a valid directory: {folder}")

	# Destination folder yoxlanılması
	if not destination_folder.exists() or not destination_folder.is_dir():
		raise SystemExit(f"Destination folder is not a valid directory: {destination_folder}")

	# Bütün source folderlərdən ölçüləri yığırıq
	source_sizes_list = []
	for folder in source_folders:
		sizes = gather_folder_sizes(folder, args.min_depth, args.max_depth)
		source_sizes_list.append(sizes)

	# Destination folder ölçülərini yığırıq
	dest_sizes = gather_folder_sizes(destination_folder, args.min_depth, args.max_depth)

	# Müqayisə aparırıq
	entries, stats = compare_aggregated_sizes(
		source_folders, destination_folder, source_sizes_list, dest_sizes
	)
	
	end_time = datetime.now()
	write_log(OUTPUT_LOG_PATH, entries, stats, start_time, end_time)
	
	duration = end_time - start_time
	print(f"Finished at: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
	print(f"Total duration: {int(duration.total_seconds())} seconds")
	print(
		f"Total folders compared: {stats['TOTAL']}, "
		f"OK: {stats['OK']}, "
		f"FAIL: {stats['FAIL']}, "
		f"MISSING: {stats['MISSING']}"
	)


if __name__ == "__main__":
    main()
