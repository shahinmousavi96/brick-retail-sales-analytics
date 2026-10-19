/* =====================================================================
   Brick Retail Sales Analytics: Stage 2, sales analysis.
   Concepts: WHERE, GROUP BY, HAVING, COUNT, COUNT(DISTINCT), SUM, AVG,
             MIN, MAX, ROUND, CASE inside aggregates.
   Source: dbo.vw_SalesLines (one row per order line, see 06_views.sql).
   Business rule: revenue counts only OrderStatus = 'Completed'.
   ===================================================================== */
USE LegoSalesAnalytics;
GO

/* S1. What period does the data cover, and how big is it? */
SELECT
    MIN(OrderDate)            AS FirstOrder,
    MAX(OrderDate)            AS LastOrder,
    COUNT(DISTINCT OrderID)   AS Orders,
    COUNT(*)                  AS OrderLines,
    SUM(Quantity)             AS UnitsSold
FROM dbo.vw_SalesLines;

/* S2. Total revenue, units and gross profit 2023 to 2025 (completed orders). */
SELECT
    SUM(NetRevenue)   AS Revenue,
    SUM(Quantity)     AS Units,
    SUM(GrossProfit)  AS GrossProfit
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed';

/* S3. Revenue, orders and average order value (AOV) per year. */
SELECT
    OrderYear,
    COUNT(DISTINCT OrderID)                                AS Orders,
    SUM(NetRevenue)                                        AS Revenue,
    ROUND(SUM(NetRevenue) / COUNT(DISTINCT OrderID), 2)    AS AvgOrderValue
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY OrderYear
ORDER BY OrderYear;

/* S4. Which sales channel brings the most revenue and the best margin?
       Margin % uses only lines with a known cost. */
SELECT
    ChannelName,
    SUM(NetRevenue)    AS Revenue,
    SUM(Quantity)      AS Units,
    SUM(GrossProfit)   AS GrossProfit,
    CAST(SUM(GrossProfit) * 100.0
         / SUM(CASE WHEN CostAmount IS NOT NULL THEN NetRevenue END) AS DECIMAL(5,1)) AS MarginPct
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY ChannelName
ORDER BY Revenue DESC;

/* S5. Store ranking by revenue in 2025. */
SELECT
    StoreName,
    COUNT(DISTINCT OrderID)  AS Orders,
    SUM(NetRevenue)          AS Revenue
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
  AND OrderYear = 2025
GROUP BY StoreName
ORDER BY Revenue DESC;

/* S6. Top 10 product lines by revenue. */
SELECT TOP (10)
    ProductLine,
    SUM(NetRevenue)   AS Revenue,
    SUM(Quantity)     AS Units
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY ProductLine
ORDER BY Revenue DESC;

/* S7. HAVING: product lines with more than 50,000 EUR revenue in 2025.
       WHERE filters rows before grouping, HAVING filters groups after. */
SELECT
    ProductLine,
    SUM(NetRevenue) AS Revenue2025
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
  AND OrderYear = 2025
GROUP BY ProductLine
HAVING SUM(NetRevenue) > 50000
ORDER BY Revenue2025 DESC;

/* S8. Top 10 best-selling sets by units (all years). */
SELECT TOP (10)
    SetNum,
    ProductName,
    ProductLine,
    SUM(Quantity)    AS Units,
    SUM(NetRevenue)  AS Revenue
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY SetNum, ProductName, ProductLine
ORDER BY Units DESC;

/* S9. Seasonality: revenue by calendar month (all years combined). */
SELECT
    OrderMonth,
    SUM(NetRevenue)  AS Revenue
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY OrderMonth
ORDER BY OrderMonth;

/* S10. Licensed vs own themes: revenue and margin. */
SELECT
    CASE WHEN IsLicensed = 1 THEN 'Licensed' ELSE 'Own IP' END AS ThemeType,
    SUM(NetRevenue)   AS Revenue,
    SUM(GrossProfit)  AS GrossProfit,
    CAST(SUM(GrossProfit) * 100.0
         / SUM(CASE WHEN CostAmount IS NOT NULL THEN NetRevenue END) AS DECIMAL(5,1)) AS MarginPct
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY CASE WHEN IsLicensed = 1 THEN 'Licensed' ELSE 'Own IP' END;

/* S11. Discounts: how much revenue was sold at each discount level? */
SELECT
    DiscountPct,
    COUNT(*)          AS OrderLines,
    SUM(NetRevenue)   AS Revenue
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY DiscountPct
ORDER BY DiscountPct;

/* S12. Return rate per channel (returned orders / all orders). */
SELECT
    ChannelName,
    COUNT(DISTINCT OrderID)                                                   AS AllOrders,
    COUNT(DISTINCT CASE WHEN OrderStatus = 'Returned' THEN OrderID END)       AS ReturnedOrders,
    CAST(COUNT(DISTINCT CASE WHEN OrderStatus = 'Returned' THEN OrderID END) * 100.0
         / COUNT(DISTINCT OrderID) AS DECIMAL(5,2))                           AS ReturnRatePct
FROM dbo.vw_SalesLines
GROUP BY ChannelName;

/* S13. Loyalty: do Insider members spend more per order than others?
        (orders without a customer are not identified and are excluded) */
SELECT
    CASE WHEN IsInsider = 1 THEN 'Insider' ELSE 'Non-member account' END AS CustomerType,
    COUNT(DISTINCT CustomerID)                              AS Customers,
    COUNT(DISTINCT OrderID)                                 AS Orders,
    ROUND(SUM(NetRevenue) / COUNT(DISTINCT OrderID), 2)     AS AvgOrderValue
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
  AND CustomerID IS NOT NULL
GROUP BY CASE WHEN IsInsider = 1 THEN 'Insider' ELSE 'Non-member account' END;

/* S14. COUNT(*) vs COUNT(column) vs COUNT(DISTINCT column) in one result. */
SELECT
    COUNT(*)                     AS AllOrders,
    COUNT(CustomerID)            AS OrdersWithCustomer,
    COUNT(DISTINCT CustomerID)   AS UniqueCustomers
FROM dbo.Orders;

/* S15. Average, smallest and largest order line value per channel. */
SELECT
    ChannelName,
    ROUND(AVG(NetRevenue), 2)  AS AvgLineValue,
    MIN(NetRevenue)            AS MinLineValue,
    MAX(NetRevenue)            AS MaxLineValue
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY ChannelName
ORDER BY AvgLineValue DESC;
