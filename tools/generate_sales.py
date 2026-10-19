"""Generate 04_load_sales.sql: simulated customers, orders and order items (2023-2025).

Usage: python generate_sales.py <products_simulated.csv> <output folder>
All rules are documented in README.md. Fixed seed for reproducibility.
"""
import sys, os, datetime as dt
import numpy as np
import pandas as pd

PROD, OUT = sys.argv[1], sys.argv[2]
rng = np.random.default_rng(42)
p = pd.read_csv(PROD, keep_default_na=False, na_values=[""]).rename(columns={
    "set_num": "SetNum", "year": "ReleaseYear", "line": "ProductLine", "price": "UnitPrice", "cost": "UnitCost"})

# ---------------- Customers ----------------
N_CUST = 4000
cities = ["Munich", "Berlin", "Hamburg", "Frankfurt am Main", "Cologne", "Stuttgart",
          "Duesseldorf", "Nuremberg", "Ingolstadt", "Augsburg", "Leipzig", "Dresden",
          "Hanover", "Bremen", "Mainz", "Wiesbaden", "Bonn", "Regensburg"]
cw = np.array([16, 15, 12, 10, 9, 6, 5, 4, 3, 3, 3, 3, 3, 2, 2, 2, 1, 1], float); cw /= cw.sum()
cust = pd.DataFrame({
    "CustomerID": np.arange(1, N_CUST + 1),
    "CustomerCode": [f"C{i:06d}" for i in range(1, N_CUST + 1)],
    "City": rng.choice(cities, N_CUST, p=cw),
    "IsInsider": (rng.random(N_CUST) < 0.62).astype(int),
})
start = dt.date(2019, 1, 1).toordinal()
cust["SignupDate"] = [dt.date.fromordinal(start + int(x)) for x in rng.integers(0, (dt.date(2025, 10, 31).toordinal() - start), N_CUST)]
cust.loc[rng.choice(N_CUST, 25, replace=False), "City"] = None      # data-quality issue: missing city
cust_city = dict(zip(cust.CustomerID, cust.City))
insider = dict(zip(cust.CustomerID, cust.IsInsider))
# Insiders shop more often: they are twice as likely to be the customer on an order
cust_p = np.where(cust.IsInsider == 1, 2.0, 1.0); cust_p /= cust_p.sum()

# ---------------- Stores ----------------
# StoreID: weight of order count, opened date
stores = {1: 0.15, 2: 0.11, 3: 0.14, 4: 0.12, 5: 0.09, 6: 0.36, 7: 0.03}
store_ids = np.array(list(stores)); store_w = np.array(list(stores.values())); store_w /= store_w.sum()
store_city = {1: "Munich", 2: "Frankfurt am Main", 3: "Berlin", 4: "Hamburg", 5: "Cologne"}

# ---------------- Daily order volume ----------------
month_w = {1: .70, 2: .70, 3: .80, 4: .85, 5: .85, 6: .80, 7: .75, 8: .75, 9: .85, 10: .95, 11: 1.40, 12: 2.00}
year_w = {2023: 1.00, 2024: 1.09, 2025: 1.19}
BASE = 16.0
days = pd.date_range("2023-01-01", "2025-12-31", freq="D")
orders = []
oid = 100000
for d in days:
    lam = BASE * month_w[d.month] * year_w[d.year] * (1.6 if d.dayofweek == 5 else (0.6 if d.dayofweek == 6 else 1.0))
    # Black Friday week boost
    if d.month == 11 and d.day >= 22 and d.day <= 30:
        lam *= 1.8
    n = rng.poisson(lam)
    for _ in range(n):
        s = int(rng.choice(store_ids, p=store_w))
        if d.dayofweek == 6 and s <= 5:          # brand stores closed on Sunday in Germany
            s = 6
        oid += 1
        if s == 7:
            c = None                              # B2B partner order, no consumer
        elif s == 6:
            c = int(rng.choice(cust.CustomerID.values, p=cust_p))  # online orders always have an account
        else:
            c = int(rng.choice(cust.CustomerID.values, p=cust_p)) if rng.random() < 0.55 else None   # walk-in without card
        orders.append((oid, d.date(), s, c))
orders = pd.DataFrame(orders, columns=["OrderID", "OrderDate", "StoreID", "CustomerID"])
orders["OrderStatus"] = np.where((orders.StoreID != 7) & (rng.random(len(orders)) < 0.03), "Returned", "Completed")

# ---------------- Product popularity ----------------
line_w = {"Star Wars": 1.6, "City": 1.5, "Technic": 1.3, "Friends": 1.3, "Harry Potter": 1.3, "Icons": 1.2,
          "Ninjago": 1.1, "Super Mario": 1.1, "Minecraft": 1.1, "Speed Champions": 1.1, "Botanicals": 1.2,
          "Super Heroes Marvel": 1.1, "Disney": 1.0, "Duplo": 1.0, "Creator": 1.1}
p["base_w"] = p.ProductLine.map(line_w).fillna(0.7) * (p.UnitPrice ** -0.45)
pyear = p.ReleaseYear.values; pline = p.ProductLine.values; pw = p.base_w.values
setnums = p.SetNum.values; prices = p.UnitPrice.values

def weights(year, month):
    w = pw.copy()
    alive = (pyear <= year) & (pyear >= year - 2)
    w[~alive] = 0
    w[pyear == year] *= 1.5                        # new releases sell more
    seasonal = pline == "Seasonal"
    w[seasonal] *= 3.0 if month in (10, 11, 12) else 0.25
    return w / w.sum()

wcache = {}
items = []
for o in orders.itertuples(index=False):
    key = (o.OrderDate.year, o.OrderDate.month)
    if key not in wcache:
        wcache[key] = weights(*key)
    w = wcache[key]
    if o.StoreID == 7:
        nlines = int(rng.integers(2, 6))
    elif o.CustomerID is not None and not pd.isna(o.CustomerID) and insider.get(int(o.CustomerID)) == 1:
        nlines = int(rng.choice([1, 2, 3, 4], p=[.48, .32, .14, .06]))   # Insiders buy more per visit
    else:
        nlines = int(rng.choice([1, 2, 3, 4], p=[.62, .27, .08, .03]))
    idx = rng.choice(len(w), size=nlines, replace=False, p=w)
    bf = o.OrderDate.month == 11 and 22 <= o.OrderDate.day <= 30
    for i in idx:
        if o.StoreID == 7:
            qty = int(rng.integers(4, 13)); disc = 0.25
        else:
            qty = 1 if rng.random() < 0.9 else 2
            r = rng.random()
            if bf:
                disc = 0.20 if r < 0.45 else (0.10 if r < 0.65 else 0.0)
            else:
                disc = 0.20 if r < 0.04 else (0.10 if r < 0.13 else 0.0)
        items.append((o.OrderID, setnums[i], qty, prices[i], disc))
items = pd.DataFrame(items, columns=["OrderID", "SetNum", "Quantity", "UnitPrice", "DiscountPct"])

# data-quality issue: ~0.5 percent of order lines loaded twice (exact duplicates)
dup = items.sample(frac=0.005, random_state=7)
items = pd.concat([items, dup]).sort_values(["OrderID"], kind="stable").reset_index(drop=True)

# ---------------- write SQL ----------------
def q(v):
    if v is None or (isinstance(v, float) and np.isnan(v)):
        return "NULL"
    if isinstance(v, (str, dt.date)):
        return "N'" + str(v).replace("'", "''") + "'" if isinstance(v, str) else f"'{v.isoformat()}'"
    return str(v)

def inserts(table, cols, rows, n=1000):
    out = []
    for i in range(0, len(rows), n):
        out.append(f"INSERT INTO dbo.{table} ({', '.join(cols)}) VALUES\n" + ",\n".join(rows[i:i + n]) + ";")
    return out

L = ["""/* =====================================================================
   Brick Retail Sales Analytics: File 04, load simulated sales data (2023 to 2025).
   Customers, Orders and OrderItems are fully simulated (see README).
   Contains deliberate data-quality issues for File 05:
     - duplicate order lines, customers without city, returned orders.
   Run after 02_load_catalog.sql. Safe to re-run. Takes about 1 to 2 minutes.
   ===================================================================== */
USE LegoSalesAnalytics;
GO
SET NOCOUNT ON;

/* File 05 adds a unique key after cleaning; drop it so the raw data (with duplicates) can load again. */
ALTER TABLE dbo.OrderItems DROP CONSTRAINT IF EXISTS UQ_OrderItems_Order_Set;
TRUNCATE TABLE dbo.OrderItems;   -- also resets the IDENTITY counter to 1
DELETE FROM dbo.Orders;
DELETE FROM dbo.Customers;
GO
"""]
L.append("/* Customers (anonymous codes, no personal data) */")
rows = [f"({r.CustomerID}, {q(r.CustomerCode)}, {q(r.City)}, {r.IsInsider}, {q(r.SignupDate)})" for r in cust.itertuples()]
L += inserts("Customers", ["CustomerID", "CustomerCode", "City", "IsInsider", "SignupDate"], rows)
L.append("GO\n/* Orders */")
rows = [f"({r.OrderID}, {q(r.OrderDate)}, {r.StoreID}, {q(None if pd.isna(r.CustomerID) else int(r.CustomerID))}, '{r.OrderStatus}')" for r in orders.itertuples()]
for k, chunk in enumerate(inserts("Orders", ["OrderID", "OrderDate", "StoreID", "CustomerID", "OrderStatus"], rows)):
    L.append(chunk)
    if k % 10 == 9:
        L.append("GO")
L.append("GO\n/* Order items */")
rows = [f"({r.OrderID}, {q(r.SetNum)}, {r.Quantity}, {r.UnitPrice:.2f}, {r.DiscountPct:.2f})" for r in items.itertuples()]
for k, chunk in enumerate(inserts("OrderItems", ["OrderID", "SetNum", "Quantity", "UnitPrice", "DiscountPct"], rows)):
    L.append(chunk)
    if k % 10 == 9:
        L.append("GO")
L.append(f"""GO

/* Row-count check. Expected: Customers {len(cust)}, Orders {len(orders)}, OrderItems {len(items)} */
SELECT 'Customers' AS TableName, COUNT(*) AS RowsLoaded FROM dbo.Customers
UNION ALL SELECT 'Orders',     COUNT(*) FROM dbo.Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems;
""")
open(f"{OUT}/04_load_sales.sql", "w", encoding="utf-8-sig", newline="\r\n").write("\n".join(L))
print("customers", len(cust), "orders", len(orders), "items", len(items), "dups", len(dup),
      "returned", (orders.OrderStatus == "Returned").sum(),
      "size MB", round(os.path.getsize(f"{OUT}/04_load_sales.sql") / 1e6, 2))
