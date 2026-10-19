# Stage 4: Power BI dashboard guide

Goal: a 3-page management dashboard built on the view `dbo.vw_SalesLines`.
Prerequisite: SQL files 01 to 06 have been run in SSMS.

## 1. Connect to the database
1. Open **Power BI Desktop** and choose **Get data > SQL Server**.
2. Server: `localhost\SQLEXPRESS`  Database: `LegoSalesAnalytics`  Data connectivity mode: **Import**. Click **OK**.
3. If asked for credentials, choose **Windows > Use my current credentials > Connect**. If an encryption warning appears, click **OK**.
4. In the Navigator tick **vw_SalesLines** and click **Load**.

## 2. Date table
**Modeling > New table**, paste:
```DAX
Date =
ADDCOLUMNS (
    CALENDAR ( DATE ( 2023, 1, 1 ), DATE ( 2025, 12, 31 ) ),
    "Year", YEAR ( [Date] ),
    "Month No", MONTH ( [Date] ),
    "Month", FORMAT ( [Date], "MMM" ),
    "Year Month", FORMAT ( [Date], "YYYY-MM" ),
    "Quarter", "Q" & QUARTER ( [Date] )
)
```
Then:
- Select the table, **Table tools > Mark as date table**, column `Date`.
- Select column `Month`, **Column tools > Sort by column > Month No**.
- **Model view**: drag `Date[Date]` onto `vw_SalesLines[OrderDate]` (one to many).

## 3. Calculated column
Select `vw_SalesLines`, **New column**:
```DAX
Price Segment =
SWITCH (
    TRUE (),
    vw_SalesLines[ListPrice] < 30, "1 Budget (<30)",
    vw_SalesLines[ListPrice] < 100, "2 Mid (30-99)",
    "3 Premium (100+)"
)
```

## 4. Measures
Select `vw_SalesLines`, **New measure**, one at a time. All revenue measures count completed orders only (same rule as the SQL).
```DAX
Revenue =
CALCULATE ( SUM ( vw_SalesLines[NetRevenue] ), vw_SalesLines[OrderStatus] = "Completed" )

Gross Profit =
CALCULATE ( SUM ( vw_SalesLines[GrossProfit] ), vw_SalesLines[OrderStatus] = "Completed" )

Margin % =
DIVIDE (
    [Gross Profit],
    CALCULATE (
        SUM ( vw_SalesLines[NetRevenue] ),
        vw_SalesLines[OrderStatus] = "Completed",
        NOT ISBLANK ( vw_SalesLines[CostAmount] )
    )
)

Orders =
CALCULATE ( DISTINCTCOUNT ( vw_SalesLines[OrderID] ), vw_SalesLines[OrderStatus] = "Completed" )

Units =
CALCULATE ( SUM ( vw_SalesLines[Quantity] ), vw_SalesLines[OrderStatus] = "Completed" )

Avg Order Value =
DIVIDE ( [Revenue], [Orders] )

Revenue PY =
CALCULATE ( [Revenue], SAMEPERIODLASTYEAR ( 'Date'[Date] ) )

Revenue YoY % =
DIVIDE ( [Revenue] - [Revenue PY], [Revenue PY] )

Return Rate % =
DIVIDE (
    CALCULATE ( DISTINCTCOUNT ( vw_SalesLines[OrderID] ), vw_SalesLines[OrderStatus] = "Returned" ),
    DISTINCTCOUNT ( vw_SalesLines[OrderID] )
)
```
Formatting: Revenue, Gross Profit, Revenue PY, Avg Order Value as **Currency (EUR)**; Margin %, Revenue YoY %, Return Rate % as **Percentage, 1 decimal**.

## 5. Pages

### Page 1: Overview
| Visual | Fields |
|---|---|
| 5 Cards | Revenue, Gross Profit, Margin %, Orders, Avg Order Value |
| Line chart | X: `Date[Year Month]`, Y: Revenue and Revenue PY |
| Clustered bar | Y: ChannelName, X: Revenue (tooltip: Margin %) |
| Column chart | X: `Date[Month]`, Y: Revenue, Legend: `Date[Year]` (shows the Christmas peak) |
| Slicers | `Date[Year]`, ChannelName |

### Page 2: Products
| Visual | Fields |
|---|---|
| Bar chart | Top 10 ProductLine by Revenue (Filters pane: Top N = 10 by Revenue) |
| Table | ProductName, ProductLine, Units, Revenue, Margin % (sorted by Revenue, Top 20) |
| Scatter chart | Values: ProductLine, X: Revenue, Y: Margin %, Size: Units (growth opportunities = top-left) |
| Donut | Legend: Price Segment, Values: Revenue |

### Page 3: Stores and customers
| Visual | Fields |
|---|---|
| Bar chart | StoreName by Revenue |
| Matrix | Rows: StoreName, Columns: `Date[Year]`, Values: Revenue YoY % |
| Clustered column | X: IsInsider, Y: Avg Order Value (filter: CustomerID is not blank) |
| Card | Return Rate % |

## 6. Finish
1. Add a title text box on each page and the footer: *Simulated data. LEGO® is a trademark of the LEGO Group of companies, which does not sponsor, authorize or endorse this project.*
2. **File > Save as** `Sales_Dashboard.pbix` in the project folder.
3. Take a screenshot of each page and save as `dashboard_overview.png`, `dashboard_products.png` and `dashboard_stores.png` for GitHub.

## Check values (all years, no slicer)
Revenue 1,887,990 EUR · Gross Profit 792,950 EUR · Orders 18,829 · Avg Order Value about 100 EUR.
If your numbers match these, the model is correct.
