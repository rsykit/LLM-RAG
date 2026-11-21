"""Download the Olist dataset from Kaggle and copy the CSVs into data/raw/."""
import shutil
from pathlib import Path

import kagglehub

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"


def main():
    # Downloads to kagglehub's cache (~/.cache/kagglehub) and returns that path
    cache_path = Path(kagglehub.dataset_download("olistbr/brazilian-ecommerce"))
    print("Downloaded to cache:", cache_path)

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    csvs = sorted(cache_path.glob("*.csv"))
    for csv in csvs:
        shutil.copy2(csv, RAW_DIR / csv.name)
        print("  copied", csv.name)

    print(f"{len(csvs)} CSV files in {RAW_DIR}")


if __name__ == "__main__":
    main()
