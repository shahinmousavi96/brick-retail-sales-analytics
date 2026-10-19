/* =====================================================================
   Brick Retail Sales Analytics: File 05, data quality checks and cleaning.
   Rule: check the data before analysing it.
   Concepts: COUNT vs COUNT(column), IS NULL, GROUP BY + HAVING for
             duplicates, CTE + ROW_NUMBER to delete duplicates, UNIQUE constraint.
   Run after 04_load_sales.sql.
   ===================================================================== */
USE LegoSalesAnalytics;
GO

/* DQ1. Profile: how many rows does each table have? */
SELECT 'Products' AS TableName, COUNT(*) AS RowCnt FROM dbo.Products
UNION ALL SELECT 'Customers',  COUNT(*) FROM dbo.Customers
UNION ALL SELECT 'Orders',     COUNT(*) FROM dbo.Orders
UNION ALL SELECT 'OrderItems', COUNT(*) FROM dbo.OrderItems;

/* DQ2. Missing values. COUNT(*) counts rows, COUNT(column) skips NULLs,
        so the difference is the number of missing values. */
SELECT
    COUNT(*)                     AS Products,
    COUNT(*) - COUNT(UnitCost)   AS ProductsWithoutCost
FROM dbo.Products;

SELECT
    COUNT(*)                     AS Customers,
    COUNT(*) - COUNT(City)       AS CustomersWithoutCity
FROM dbo.Customers;

/* DQ3. NULL CustomerID in Orders is NOT an error: it is a walk-in or B2B order.
        Show the split by store, so the rule is documented. */
SELECT
    StoreID,
    COUNT(*)                         AS Orders,
    COUNT(*) - COUNT(CustomerID)     AS OrdersWithoutCustomer
FROM dbo.Orders
GROUP BY StoreID
ORDER BY StoreID;

/* DQ4. Duplicate order lines: the same product appears twice in the
        same order with identical quantity, price and discount. */
SELECT
    OrderID, SetNum, Quantity, UnitPrice, DiscountPct,
    COUNT(*) AS Copies
FROM dbo.OrderItems
GROUP BY OrderID, SetNum, Quantity, UnitPrice, DiscountPct
HAVING COUNT(*) > 1
ORDER BY OrderID;

/* DQ5. How many extra rows will be removed? */
SELECT COUNT(*) - COUNT(DISTINCT CONCAT(OrderID, '|', SetNum)) AS DuplicateRows
FROM dbo.OrderItems;

/* DQ6. Remove duplicates: keep the first copy (lowest OrderItemID).
        ROW_NUMBER numbers the copies 1, 2, 3 inside each group;
        everything with number > 1 is a duplicate. */
WITH Numbered AS (
    SELECT
        OrderItemID,
        ROW_NUMBER() OVER (
            PARTITION BY OrderID, SetNum, Quantity, UnitPrice, DiscountPct
            ORDER BY OrderItemID
        ) AS CopyNo
    FROM dbo.OrderItems
)
DELETE FROM Numbered
WHERE CopyNo > 1;
GO

/* DQ7. Prevent the problem from coming back: one product per order line. */
ALTER TABLE dbo.OrderItems
    ADD CONSTRAINT UQ_OrderItems_Order_Set UNIQUE (OrderID, SetNum);
GO

/* DQ8. Verify: no duplicates left (expected result: 0). */
SELECT COUNT(*) - COUNT(DISTINCT CONCAT(OrderID, '|', SetNum)) AS DuplicateRowsLeft
FROM dbo.OrderItems;

/* DQ9. Business rule: returned orders are excluded from revenue.
        How many are there? */
SELECT
    OrderStatus,
    COUNT(*) AS Orders
FROM dbo.Orders
GROUP BY OrderStatus;

/* DQ10. Consistency check: every product sold must be released
         no later than the order year (expected result: 0). */
SELECT COUNT(*) AS SoldBeforeRelease
FROM dbo.OrderItems AS oi
JOIN dbo.Orders     AS o ON o.OrderID = oi.OrderID
JOIN dbo.Products   AS p ON p.SetNum  = oi.SetNum
WHERE p.ReleaseYear > YEAR(o.OrderDate);
