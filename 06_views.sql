/* =====================================================================
   Brick Retail Sales Analytics: File 06, reporting views.
   A view is a saved SELECT. vw_SalesLines joins all tables into one
   flat sales table: it is used by the Stage 2 queries and by Power BI.
   Run after 05_data_quality.sql.
   ===================================================================== */
USE LegoSalesAnalytics;
GO

/* One row per order line, with all descriptive fields and money columns.
   NetRevenue  = Quantity x UnitPrice x (1 - DiscountPct)
   CostAmount  = Quantity x product UnitCost (NULL when cost is unknown)
   GrossProfit = NetRevenue - CostAmount */
CREATE OR ALTER VIEW dbo.vw_SalesLines
AS
SELECT
    oi.OrderItemID,
    o.OrderID,
    o.OrderDate,
    YEAR(o.OrderDate)                                        AS OrderYear,
    MONTH(o.OrderDate)                                       AS OrderMonth,
    DATEFROMPARTS(YEAR(o.OrderDate), MONTH(o.OrderDate), 1)  AS MonthStart,
    o.OrderStatus,
    s.StoreID,
    s.StoreName,
    ch.ChannelName,
    o.CustomerID,
    c.IsInsider,
    p.SetNum,
    p.ProductName,
    p.ProductLine,
    p.IsLicensed,
    p.ReleaseYear,
    oi.Quantity,
    oi.UnitPrice                                             AS ListPrice,
    oi.DiscountPct,
    CAST(oi.Quantity * oi.UnitPrice * (1 - oi.DiscountPct) AS DECIMAL(12,2))  AS NetRevenue,
    CAST(oi.Quantity * p.UnitCost AS DECIMAL(12,2))                           AS CostAmount,
    CAST(oi.Quantity * oi.UnitPrice * (1 - oi.DiscountPct)
         - oi.Quantity * p.UnitCost AS DECIMAL(12,2))                         AS GrossProfit
FROM dbo.OrderItems     AS oi
JOIN dbo.Orders         AS o  ON o.OrderID    = oi.OrderID
JOIN dbo.Stores         AS s  ON s.StoreID    = o.StoreID
JOIN dbo.Channels       AS ch ON ch.ChannelID = s.ChannelID
JOIN dbo.Products       AS p  ON p.SetNum     = oi.SetNum
LEFT JOIN dbo.Customers AS c  ON c.CustomerID = o.CustomerID;
GO

/* Monthly summary of completed sales (used for trend analysis). */
CREATE OR ALTER VIEW dbo.vw_MonthlySales
AS
SELECT
    MonthStart,
    OrderYear,
    OrderMonth,
    COUNT(DISTINCT OrderID)  AS Orders,
    SUM(Quantity)            AS Units,
    SUM(NetRevenue)          AS Revenue,
    SUM(GrossProfit)         AS GrossProfit
FROM dbo.vw_SalesLines
WHERE OrderStatus = 'Completed'
GROUP BY MonthStart, OrderYear, OrderMonth;
GO

/* Check */
SELECT TOP (5) * FROM dbo.vw_SalesLines ORDER BY OrderItemID;
SELECT TOP (5) * FROM dbo.vw_MonthlySales ORDER BY MonthStart;
