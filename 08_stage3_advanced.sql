/* =====================================================================
   Brick Retail Sales Analytics: Stage 3, advanced business analysis.
   Concepts: INNER / LEFT JOIN, self-join, recursive CTE, subqueries,
             CTEs, CASE, window functions (ROW_NUMBER, RANK, LAG,
             running total, percent of total), INTERSECT.
   Business rule: revenue counts only completed orders.
   ===================================================================== */
USE LegoSalesAnalytics;
GO

/* A1. INNER JOIN on base tables: revenue per store and channel. */
SELECT
    ch.ChannelName,
    s.StoreName,
    SUM(oi.Quantity * oi.UnitPrice * (1 - oi.DiscountPct)) AS Revenue
FROM dbo.OrderItems AS oi
INNER JOIN dbo.Orders   AS o  ON o.OrderID    = oi.OrderID
INNER JOIN dbo.Stores   AS s  ON s.StoreID    = o.StoreID
INNER JOIN dbo.Channels AS ch ON ch.ChannelID = s.ChannelID
WHERE o.OrderStatus = 'Completed'
GROUP BY ch.ChannelName, s.StoreName
ORDER BY Revenue DESC;

/* A2. LEFT JOIN: products released 2023 to 2025 that never sold.
       Unmatched rows from the right table come back as NULL. */
SELECT
    p.SetNum, p.ProductName, p.ProductLine, p.ReleaseYear, p.UnitPrice
FROM dbo.Products AS p
LEFT JOIN dbo.OrderItems AS oi ON oi.SetNum = p.SetNum
WHERE p.ReleaseYear BETWEEN 2023 AND 2025
  AND oi.OrderItemID IS NULL
ORDER BY p.UnitPrice DESC;

/* A3. Self-join: each theme next to its parent theme. */
SELECT
    child.ThemeID,
    child.ThemeName,
    parent.ThemeName AS ParentTheme
FROM dbo.Themes AS child
LEFT JOIN dbo.Themes AS parent ON parent.ThemeID = child.ParentThemeID
ORDER BY ParentTheme, child.ThemeName;

/* A4. Recursive CTE: walk the theme tree from every theme up to its root,
       then check that Products.ProductLine matches the real root theme.
       Expected result: 0 mismatches. */
WITH ThemeTree AS (
    -- anchor: top-level themes are their own root
    SELECT ThemeID, ThemeName, ThemeID AS RootID, ThemeName AS RootName, 0 AS Depth
    FROM dbo.Themes
    WHERE ParentThemeID IS NULL
    UNION ALL
    -- recursive step: children inherit the root of their parent
    SELECT t.ThemeID, t.ThemeName, tt.RootID, tt.RootName, tt.Depth + 1
    FROM dbo.Themes AS t
    JOIN ThemeTree  AS tt ON t.ParentThemeID = tt.ThemeID
)
SELECT COUNT(*) AS ProductLineMismatches
FROM dbo.Products AS p
JOIN ThemeTree    AS tt ON tt.ThemeID = p.ThemeID
WHERE p.ProductLine <> tt.RootName;

/* A5. Correlated subquery: sets priced above the average of their own line. */
SELECT TOP (20)
    p.ProductName, p.ProductLine, p.UnitPrice,
    (SELECT CAST(AVG(p2.UnitPrice) AS DECIMAL(10,2))
     FROM dbo.Products AS p2
     WHERE p2.ProductLine = p.ProductLine) AS LineAvgPrice
FROM dbo.Products AS p
WHERE p.UnitPrice > (SELECT AVG(p2.UnitPrice)
                     FROM dbo.Products AS p2
                     WHERE p2.ProductLine = p.ProductLine)
ORDER BY p.UnitPrice DESC;

/* A6. CTE: build order totals first, then compare channels by
       average order value and items per order. */
WITH OrderTotals AS (
    SELECT
        OrderID,
        ChannelName,
        SUM(NetRevenue) AS OrderValue,
        SUM(Quantity)   AS Items
    FROM dbo.vw_SalesLines
    WHERE OrderStatus = 'Completed'
    GROUP BY OrderID, ChannelName
)
SELECT
    ChannelName,
    COUNT(*)                                  AS Orders,
    CAST(AVG(OrderValue) AS DECIMAL(10,2))    AS AvgOrderValue,
    CAST(AVG(Items * 1.0) AS DECIMAL(10,2))   AS AvgItemsPerOrder
FROM OrderTotals
GROUP BY ChannelName
ORDER BY AvgOrderValue DESC;

/* A7. ROW_NUMBER: top 3 sets by revenue inside each of the
       5 biggest product lines (2025). */
WITH SetRevenue AS (
    SELECT ProductLine, ProductName, SUM(NetRevenue) AS Revenue
    FROM dbo.vw_SalesLines
    WHERE OrderStatus = 'Completed' AND OrderYear = 2025
    GROUP BY ProductLine, ProductName
),
Ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY ProductLine ORDER BY Revenue DESC) AS RankInLine
    FROM SetRevenue
)
SELECT ProductLine, RankInLine, ProductName, Revenue
FROM Ranked
WHERE RankInLine <= 3
  AND ProductLine IN (SELECT TOP (5) ProductLine
                      FROM SetRevenue
                      GROUP BY ProductLine
                      ORDER BY SUM(Revenue) DESC)
ORDER BY ProductLine, RankInLine;

/* A8. RANK: store ranking per year. Did the order change? */
SELECT
    OrderYear,
    StoreName,
    SUM(NetRevenue) AS Revenue,
    RANK() OVER (PARTITION BY OrderYear ORDER BY SUM(NetRevenue) DESC) AS StoreRank
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY OrderYear, StoreName
ORDER BY OrderYear, StoreRank;

/* A9. Monthly trend with month-over-month and year-over-year growth (LAG). */
SELECT
    MonthStart,
    Revenue,
    LAG(Revenue, 1)  OVER (ORDER BY MonthStart) AS PrevMonthRevenue,
    CAST((Revenue - LAG(Revenue, 1) OVER (ORDER BY MonthStart)) * 100.0
         / LAG(Revenue, 1) OVER (ORDER BY MonthStart) AS DECIMAL(6,1))  AS MoMGrowthPct,
    LAG(Revenue, 12) OVER (ORDER BY MonthStart) AS SameMonthLastYear,
    CAST((Revenue - LAG(Revenue, 12) OVER (ORDER BY MonthStart)) * 100.0
         / LAG(Revenue, 12) OVER (ORDER BY MonthStart) AS DECIMAL(6,1)) AS YoYGrowthPct
FROM dbo.vw_MonthlySales
ORDER BY MonthStart;

/* A10. Running total: cumulative revenue during 2025. */
SELECT
    MonthStart,
    Revenue,
    SUM(Revenue) OVER (ORDER BY MonthStart ROWS UNBOUNDED PRECEDING) AS CumulativeRevenue
FROM dbo.vw_MonthlySales
WHERE OrderYear = 2025
ORDER BY MonthStart;

/* A11. Percent of total: share of revenue per channel. */
SELECT
    ChannelName,
    SUM(NetRevenue) AS Revenue,
    CAST(SUM(NetRevenue) * 100.0 / SUM(SUM(NetRevenue)) OVER () AS DECIMAL(5,1)) AS SharePct
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY ChannelName
ORDER BY Revenue DESC;

/* A12. Year-over-year growth per product line, 2024 vs 2025
        (conditional aggregation with CASE). */
WITH LineYear AS (
    SELECT
        ProductLine,
        SUM(CASE WHEN OrderYear = 2024 THEN NetRevenue ELSE 0 END) AS Rev2024,
        SUM(CASE WHEN OrderYear = 2025 THEN NetRevenue ELSE 0 END) AS Rev2025
    FROM dbo.vw_SalesLines
    WHERE OrderStatus = 'Completed'
    GROUP BY ProductLine
)
SELECT TOP (15)
    ProductLine, Rev2024, Rev2025,
    CAST((Rev2025 - Rev2024) * 100.0 / NULLIF(Rev2024, 0) AS DECIMAL(6,1)) AS GrowthPct
FROM LineYear
WHERE Rev2024 >= 20000
ORDER BY GrowthPct DESC;

/* A13. Growth opportunities: product lines with above-average margin
        but below-average revenue (candidates for more shelf space and
        marketing). Lines under 5,000 EUR are too small to judge. */
WITH LineKpi AS (
    SELECT
        ProductLine,
        SUM(NetRevenue) AS Revenue,
        SUM(GrossProfit) * 1.0
            / SUM(CASE WHEN CostAmount IS NOT NULL THEN NetRevenue END) AS Margin
    FROM dbo.vw_SalesLines
    WHERE OrderStatus = 'Completed'
    GROUP BY ProductLine
    HAVING SUM(NetRevenue) > 0
)
SELECT
    ProductLine,
    Revenue,
    CAST(Margin * 100 AS DECIMAL(5,1)) AS MarginPct
FROM LineKpi
WHERE Margin  > (SELECT AVG(Margin)  FROM LineKpi)
  AND Revenue < (SELECT AVG(Revenue) FROM LineKpi)
  AND Revenue >= 5000
ORDER BY MarginPct DESC;

/* A14. Price segments with CASE: where does the money come from? */
SELECT
    CASE
        WHEN ListPrice < 30  THEN '1. Budget (< 30 EUR)'
        WHEN ListPrice < 100 THEN '2. Mid (30 to 99 EUR)'
        ELSE                      '3. Premium (100+ EUR)'
    END AS PriceSegment,
    SUM(Quantity)    AS Units,
    SUM(NetRevenue)  AS Revenue,
    CAST(SUM(NetRevenue) * 100.0 / SUM(SUM(NetRevenue)) OVER () AS DECIMAL(5,1)) AS RevenueSharePct
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY
    CASE
        WHEN ListPrice < 30  THEN '1. Budget (< 30 EUR)'
        WHEN ListPrice < 100 THEN '2. Mid (30 to 99 EUR)'
        ELSE                      '3. Premium (100+ EUR)'
    END
ORDER BY PriceSegment;

/* A15. Retention: customers who bought in both 2024 and 2025 (INTERSECT). */
SELECT COUNT(*) AS RetainedCustomers
FROM (
    SELECT CustomerID FROM dbo.vw_SalesLines
    WHERE OrderYear = 2024 AND CustomerID IS NOT NULL AND OrderStatus = 'Completed'
    INTERSECT
    SELECT CustomerID FROM dbo.vw_SalesLines
    WHERE OrderYear = 2025 AND CustomerID IS NOT NULL AND OrderStatus = 'Completed'
) AS Retained;

/* A16. Christmas dependency: share of yearly revenue earned in Q4. */
SELECT
    OrderYear,
    SUM(NetRevenue) AS YearRevenue,
    CAST(SUM(CASE WHEN OrderMonth >= 10 THEN NetRevenue ELSE 0 END) * 100.0
         / SUM(NetRevenue) AS DECIMAL(5,1)) AS Q4SharePct
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY OrderYear
ORDER BY OrderYear;

/* A17. Return rate per product line (lines with at least 300 order lines). */
SELECT
    ProductLine,
    COUNT(*) AS OrderLines,
    CAST(SUM(CASE WHEN OrderStatus = 'Returned' THEN 1 ELSE 0 END) * 100.0
         / COUNT(*) AS DECIMAL(5,2)) AS ReturnRatePct
FROM dbo.vw_SalesLines
GROUP BY ProductLine
HAVING COUNT(*) >= 300
ORDER BY ReturnRatePct DESC;
