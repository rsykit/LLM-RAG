import sqlite3, glob, os
import pandas as pd

con = sqlite3.connect("data/olist.db")
for f in glob.glob("data/raw/*.csv"):
    name = os.path.basename(f).replace("olist_", "").replace("_dataset.csv", "").replace(".csv", "")
    pd.read_csv(f).to_sql(name, con, if_exists="replace", index=False)
    print("loaded", name)
con.executescript(open("sql/kpis.sql").read())
