"""Generate 01_schema.sql, 02_load_catalog.sql and products_simulated.csv.

Usage: python generate_catalog.py <folder with themes.csv.gz and sets.csv.gz> <output folder>
Then: python generate_sales.py <output folder>/products_simulated.csv <output folder>
"""
import sys, os
import numpy as np
import pandas as pd

SRC = sys.argv[1]          # folder with themes.csv.gz, sets.csv.gz
OUT = sys.argv[2]          # output folder
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(2026)

themes = pd.read_csv(f"{SRC}/themes.csv.gz", keep_default_na=False, na_values=[""])
sets = pd.read_csv(f"{SRC}/sets.csv.gz", keep_default_na=False, na_values=[""])

parent = dict(zip(themes.id, themes.parent_id))
tname = dict(zip(themes.id, themes.name))
def root(i):
    while pd.notna(parent.get(i)):
        i = int(parent[i])
    return i

EXCLUDED_LINES = {"Books", "Gear", "Promotional", "Educational and Dacta",
                  "FIRST LEGO League", "LEGO Brand Store", "Collectible Minifigures",
                  "BrickLink Designer Program", "Legoland Parks", "Nike"}
LICENSED = {"Star Wars", "Harry Potter", "Super Heroes Marvel", "Super Heroes DC",
            "Disney", "Jurassic World", "Minecraft", "Super Mario", "Pokémon",
            "Sonic The Hedgehog", "Avatar", "Fortnite", "Wicked", "Indiana Jones",
            "The Legend of Zelda", "Stranger Things", "Overwatch", "Animal Crossing",
            "One Piece", "Minions", "Despicable Me 4", "Wednesday", "Bluey",
            "Gabby's Dollhouse", "Trolls: World Tour", "The Powerpuff Girls",
            "The Hobbit and Lord of the Rings", "Shrek", "KPop Demon Hunters",
            "Horizon Adventures", "Speed Champions"}

s = sets.copy()
s["line"] = s.theme_id.map(lambda i: tname[root(i)])
s = s[(s.year.between(2018, 2025)) & (s.num_parts >= 50) & (~s.line.isin(EXCLUDED_LINES))]
s = s.sort_values("set_num").reset_index(drop=True)

# Pricing rule (documented in README)
def ppp(line):
    if line == "Duplo":
        return 0.20
    return 0.13 if line in LICENSED else 0.10
raw = s.num_parts * s.line.map(ppp)
raw = raw.clip(lower=9.99, upper=899.99)
s["price"] = (np.ceil(raw) - 0.01).round(2)
s["licensed"] = s.line.isin(LICENSED).astype(int)
s["cost"] = (s.price * rng.uniform(0.45, 0.60, len(s))).round(2)
# deliberate data-quality issue: ~1% of products with cost not yet confirmed
null_idx = rng.choice(len(s), size=int(len(s) * 0.01), replace=False)
s.loc[null_idx, "cost"] = np.nan

def q(v):
    if v is None or (isinstance(v, float) and np.isnan(v)):
        return "NULL"
    if isinstance(v, str):
        return "N'" + v.replace("'", "''") + "'"
    return str(v)

def batches(rows, n=500):
    for i in range(0, len(rows), n):
        yield rows[i:i + n]

# ---------- 01_schema.sql ----------
schema = r"""/* =====================================================================
   Brick Retail Sales Analytics: a personal portfolio project.
   LEGO® is a trademark of the LEGO Group of companies, which does not sponsor, authorize or endorse this project.
   Catalog data: Rebrickable (https://rebrickable.com/downloads/).
   File 01: database and schema (Microsoft SQL Server, T-SQL)
   ===================================================================== */

IF DB_ID(N'LegoSalesAnalytics') IS NULL
    CREATE DATABASE LegoSalesAnalytics;
GO

USE LegoSalesAnalytics;
GO

/* Drop in reverse dependency order so the script can be re-run. */
DROP TABLE IF EXISTS dbo.OrderItems;
DROP TABLE IF EXISTS dbo.Orders;
DROP TABLE IF EXISTS dbo.Customers;
DROP TABLE IF EXISTS dbo.Stores;
DROP TABLE IF EXISTS dbo.Channels;
DROP TABLE IF EXISTS dbo.Products;
DROP TABLE IF EXISTS dbo.Themes;
GO

/* Real data (Rebrickable). Self-referencing hierarchy: a theme can have a parent theme. */
CREATE TABLE dbo.Themes (
    ThemeID         INT            NOT NULL,
    ThemeName       NVARCHAR(100)  NOT NULL,
    ParentThemeID   INT            NULL,
    CONSTRAINT PK_Themes PRIMARY KEY (ThemeID),
    CONSTRAINT FK_Themes_Parent FOREIGN KEY (ParentThemeID) REFERENCES dbo.Themes (ThemeID)
);

/* Real catalog attributes + simulated commercial attributes (price, cost). */
CREATE TABLE dbo.Products (
    SetNum          NVARCHAR(20)   NOT NULL,
    ProductName     NVARCHAR(200)  NOT NULL,
    ReleaseYear     SMALLINT       NOT NULL,
    ThemeID         INT            NOT NULL,
    ProductLine     NVARCHAR(100)  NOT NULL,   -- top-level theme, stored for reporting
    NumParts        INT            NOT NULL,
    IsLicensed      BIT            NOT NULL CONSTRAINT DF_Products_IsLicensed DEFAULT (0),
    UnitPrice       DECIMAL(10,2)  NOT NULL,   -- simulated retail price, EUR
    UnitCost        DECIMAL(10,2)  NULL,       -- simulated cost, EUR; NULL = not yet confirmed
    CONSTRAINT PK_Products PRIMARY KEY (SetNum),
    CONSTRAINT FK_Products_Themes FOREIGN KEY (ThemeID) REFERENCES dbo.Themes (ThemeID),
    CONSTRAINT CK_Products_Year  CHECK (ReleaseYear BETWEEN 1949 AND 2100),
    CONSTRAINT CK_Products_Parts CHECK (NumParts > 0),
    CONSTRAINT CK_Products_Price CHECK (UnitPrice > 0),
    CONSTRAINT CK_Products_Cost  CHECK (UnitCost IS NULL OR (UnitCost > 0 AND UnitCost < UnitPrice))
);
CREATE INDEX IX_Products_ThemeID     ON dbo.Products (ThemeID);
CREATE INDEX IX_Products_ProductLine ON dbo.Products (ProductLine);

/* Sales channels: brand store, online, retail partner. */
CREATE TABLE dbo.Channels (
    ChannelID       TINYINT        NOT NULL,
    ChannelName     NVARCHAR(50)   NOT NULL,
    CONSTRAINT PK_Channels PRIMARY KEY (ChannelID),
    CONSTRAINT UQ_Channels_Name UNIQUE (ChannelName)
);

CREATE TABLE dbo.Stores (
    StoreID         SMALLINT       NOT NULL,
    StoreName       NVARCHAR(100)  NOT NULL,
    City            NVARCHAR(50)   NULL,
    ChannelID       TINYINT        NOT NULL,
    OpenedDate      DATE           NULL,
    CONSTRAINT PK_Stores PRIMARY KEY (StoreID),
    CONSTRAINT FK_Stores_Channels FOREIGN KEY (ChannelID) REFERENCES dbo.Channels (ChannelID)
);

/* Simulated, anonymous customers (no personal data). Filled in Stage 2. */
CREATE TABLE dbo.Customers (
    CustomerID      INT            NOT NULL,
    CustomerCode    VARCHAR(12)    NOT NULL,
    City            NVARCHAR(50)   NULL,
    IsInsider       BIT            NOT NULL CONSTRAINT DF_Customers_IsInsider DEFAULT (0),  -- loyalty member
    SignupDate      DATE           NULL,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerID),
    CONSTRAINT UQ_Customers_Code UNIQUE (CustomerCode)
);

/* Order header. CustomerID NULL = anonymous walk-in purchase. Filled in Stage 2. */
CREATE TABLE dbo.Orders (
    OrderID         INT            NOT NULL,
    OrderDate       DATE           NOT NULL,
    StoreID         SMALLINT       NOT NULL,
    CustomerID      INT            NULL,
    OrderStatus     VARCHAR(10)    NOT NULL CONSTRAINT DF_Orders_Status DEFAULT ('Completed'),
    CONSTRAINT PK_Orders PRIMARY KEY (OrderID),
    CONSTRAINT FK_Orders_Stores    FOREIGN KEY (StoreID)    REFERENCES dbo.Stores (StoreID),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES dbo.Customers (CustomerID),
    CONSTRAINT CK_Orders_Status CHECK (OrderStatus IN ('Completed', 'Returned'))
);
CREATE INDEX IX_Orders_OrderDate ON dbo.Orders (OrderDate);
CREATE INDEX IX_Orders_StoreID   ON dbo.Orders (StoreID);

/* Order lines. Price is stored at time of sale (it can differ from today's list price). */
CREATE TABLE dbo.OrderItems (
    OrderItemID     INT IDENTITY(1,1) NOT NULL,
    OrderID         INT            NOT NULL,
    SetNum          NVARCHAR(20)   NOT NULL,
    Quantity        SMALLINT       NOT NULL,
    UnitPrice       DECIMAL(10,2)  NOT NULL,
    DiscountPct     DECIMAL(4,2)   NOT NULL CONSTRAINT DF_OrderItems_Discount DEFAULT (0),
    CONSTRAINT PK_OrderItems PRIMARY KEY (OrderItemID),
    CONSTRAINT FK_OrderItems_Orders   FOREIGN KEY (OrderID) REFERENCES dbo.Orders (OrderID),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (SetNum)  REFERENCES dbo.Products (SetNum),
    CONSTRAINT CK_OrderItems_Qty      CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_Discount CHECK (DiscountPct >= 0 AND DiscountPct < 1)
);
CREATE INDEX IX_OrderItems_OrderID ON dbo.OrderItems (OrderID);
CREATE INDEX IX_OrderItems_SetNum  ON dbo.OrderItems (SetNum);
GO

PRINT 'Schema created.';
"""
open(f"{OUT}/01_schema.sql", "w", encoding="utf-8-sig", newline="\r\n").write(schema)

# ---------- 02_load_catalog.sql ----------
out = []
out.append("""/* =====================================================================
   Brick Retail Sales Analytics: File 02, load catalog and reference data.
   Themes: real (Rebrickable). Products: real catalog + simulated price/cost.
   Run after 01_schema.sql. Safe to re-run.
   ===================================================================== */
USE LegoSalesAnalytics;
GO
SET NOCOUNT ON;

DELETE FROM dbo.OrderItems;
DELETE FROM dbo.Orders;
DELETE FROM dbo.Customers;
DELETE FROM dbo.Stores;
DELETE FROM dbo.Channels;
DELETE FROM dbo.Products;
DELETE FROM dbo.Themes;
GO
""")
# Themes: insert parents first by inserting all with NULL parent, then update parents
out.append("/* Themes: insert without parent first, then set ParentThemeID (avoids FK order issues). */")
trows = [f"({int(r.id)}, {q(r['name'])}, NULL)" for _, r in themes.iterrows()]
for b in batches(trows):
    out.append("INSERT INTO dbo.Themes (ThemeID, ThemeName, ParentThemeID) VALUES\n" + ",\n".join(b) + ";")
prows = [f"({int(r.id)}, {int(r.parent_id)})" for _, r in themes.iterrows() if pd.notna(r.parent_id)]
out.append("UPDATE dbo.Themes\nSET ParentThemeID = p.ParentID\nFROM (VALUES\n" + ",\n".join(prows) +
           "\n) AS p (ThemeID, ParentID)\nWHERE p.ThemeID = dbo.Themes.ThemeID;\nGO\n")

out.append("/* Products */")
prow = [f"({q(r.set_num)}, {q(r['name'])}, {int(r.year)}, {int(r.theme_id)}, {q(r.line)}, "
        f"{int(r.num_parts)}, {int(r.licensed)}, {r.price:.2f}, {q(None if pd.isna(r.cost) else round(float(r.cost),2))})"
        for _, r in s.iterrows()]
for b in batches(prow):
    out.append("INSERT INTO dbo.Products (SetNum, ProductName, ReleaseYear, ThemeID, ProductLine, NumParts, IsLicensed, UnitPrice, UnitCost) VALUES\n"
               + ",\n".join(b) + ";")
out.append("GO\n")

out.append("""/* Channels and stores (simulated). */
INSERT INTO dbo.Channels (ChannelID, ChannelName) VALUES
(1, N'Brand Store'),
(2, N'Online Shop'),
(3, N'Retail Partner');

INSERT INTO dbo.Stores (StoreID, StoreName, City, ChannelID, OpenedDate) VALUES
(1, N'Brand Store Munich',                 N'Munich',    1, '2015-04-01'),
(2, N'Brand Store Frankfurt Main-Taunus',  N'Sulzbach',  1, '2016-09-15'),
(3, N'Brand Store Berlin',                 N'Berlin',    1, '2017-03-01'),
(4, N'Brand Store Hamburg',                N'Hamburg',   1, '2018-05-20'),
(5, N'Brand Store Cologne',                N'Cologne',   1, '2019-10-10'),
(6, N'Online Shop Germany',                NULL,         2, '2014-01-01'),
(7, N'Retail Partners Germany',            NULL,         3, '2014-01-01');
GO

/* Row-count check */
SELECT 'Themes' AS TableName, COUNT(*) AS RowsLoaded FROM dbo.Themes
UNION ALL SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL SELECT 'Channels', COUNT(*) FROM dbo.Channels
UNION ALL SELECT 'Stores',   COUNT(*) FROM dbo.Stores;
""")
open(f"{OUT}/02_load_catalog.sql", "w", encoding="utf-8-sig", newline="\r\n").write("\n".join(out))

s[["set_num","name","year","theme_id","line","num_parts","licensed","price","cost"]].to_csv(f"{OUT}/products_simulated.csv", index=False)
print("themes", len(themes), "products", len(s), "null costs", s.cost.isna().sum(),
      "licensed", s.licensed.sum(), "price range", s.price.min(), s.price.max())
