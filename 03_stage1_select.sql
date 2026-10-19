/* =====================================================================
   Brick Retail Sales Analytics: Stage 1, product catalog exploration.
   Concepts: SELECT, column aliases (AS), arithmetic, ROUND, CAST,
             DISTINCT, TOP, ORDER BY, WHERE basics (comparison, AND/OR,
             BETWEEN, IN, LIKE, IS NULL).
   Run after 01_schema.sql and 02_load_catalog.sql.
   ===================================================================== */
USE LegoSalesAnalytics;
GO

/* Q1. What does the product table look like? (first 10 rows) */
SELECT TOP (10) *
FROM dbo.Products;

/* Q2. Show a clean product list with business-friendly column names. */
SELECT TOP (20)
    SetNum       AS [Set Number],
    ProductName  AS [Product],
    ProductLine  AS [Product Line],
    ReleaseYear  AS [Year],
    NumParts     AS [Pieces],
    UnitPrice    AS [Price EUR]
FROM dbo.Products
ORDER BY ProductLine, ProductName;

/* Q3. Which product lines (top-level themes) do we sell? */
SELECT DISTINCT ProductLine
FROM dbo.Products
ORDER BY ProductLine;

/* Q4. Gross margin per unit in EUR and in percent.
       Margin = Price - Cost;  Margin % = Margin / Price * 100. */
SELECT TOP (20)
    ProductName,
    UnitPrice,
    UnitCost,
    UnitPrice - UnitCost                                AS MarginEUR,
    CAST((UnitPrice - UnitCost) / UnitPrice * 100 AS DECIMAL(5,1)) AS MarginPct
FROM dbo.Products
WHERE UnitCost IS NOT NULL
ORDER BY MarginPct DESC;

/* Q5. What are the 10 most expensive sets? */
SELECT TOP (10)
    ProductName, ProductLine, NumParts, UnitPrice
FROM dbo.Products
ORDER BY UnitPrice DESC, NumParts DESC;

/* Q6. Price per piece: which sets give customers the most bricks per euro?
       (only sets with at least 500 pieces, to avoid tiny sets) */
SELECT TOP (10)
    ProductName,
    NumParts,
    UnitPrice,
    CAST(UnitPrice / NumParts AS DECIMAL(10,3)) AS PricePerPiece
FROM dbo.Products
WHERE NumParts >= 500
ORDER BY PricePerPiece ASC;

/* Q7. Licensed vs own themes: list licensed Star Wars and Harry Potter
       sets released from 2023, cheapest first. */
SELECT
    ProductName, ProductLine, ReleaseYear, UnitPrice
FROM dbo.Products
WHERE IsLicensed = 1
  AND ProductLine IN (N'Star Wars', N'Harry Potter')
  AND ReleaseYear >= 2023
ORDER BY UnitPrice;

/* Q8. Gift range: sets between 20 and 50 EUR from City or Friends. */
SELECT
    ProductName, ProductLine, UnitPrice
FROM dbo.Products
WHERE UnitPrice BETWEEN 20 AND 50
  AND (ProductLine = N'City' OR ProductLine = N'Friends')
ORDER BY ProductLine, UnitPrice;

/* Q9. Search by name: all products with "Castle" in the name. */
SELECT
    SetNum, ProductName, ProductLine, ReleaseYear
FROM dbo.Products
WHERE ProductName LIKE N'%Castle%'
ORDER BY ReleaseYear DESC;

/* Q10. Data quality: which products have no confirmed cost yet?
        (UnitCost = NULL never works; NULL must be tested with IS NULL) */
SELECT
    SetNum, ProductName, UnitPrice, UnitCost
FROM dbo.Products
WHERE UnitCost IS NULL
ORDER BY UnitPrice DESC;

/* Q11. Promotion planning: price after a 20 percent discount,
        and the margin that would remain. */
SELECT TOP (15)
    ProductName,
    UnitPrice                                   AS ListPrice,
    ROUND(UnitPrice * 0.80, 2)                  AS PromoPrice,
    UnitCost,
    ROUND(UnitPrice * 0.80, 2) - UnitCost       AS PromoMarginEUR
FROM dbo.Products
WHERE UnitCost IS NOT NULL
  AND ProductLine = N'Technic'
ORDER BY PromoMarginEUR ASC;

/* Q12. Discount risk: which products keep less than 12 percent margin
        under a 30 percent discount? (20 most exposed) */
SELECT TOP (20)
    ProductName, ProductLine, UnitPrice, UnitCost,
    ROUND(UnitPrice * 0.70, 2) - UnitCost AS MarginAt30PctOff,
    CAST((ROUND(UnitPrice * 0.70, 2) - UnitCost) / UnitPrice * 100 AS DECIMAL(5,1)) AS MarginPctAt30PctOff
FROM dbo.Products
WHERE UnitCost IS NOT NULL
  AND (ROUND(UnitPrice * 0.70, 2) - UnitCost) / UnitPrice < 0.12
ORDER BY MarginPctAt30PctOff ASC, UnitPrice DESC;

/* Q13. Recent large sets: 2024 or later, more than 2,000 pieces. */
SELECT
    ProductName, ProductLine, ReleaseYear, NumParts, UnitPrice
FROM dbo.Products
WHERE ReleaseYear >= 2024
  AND NumParts > 2000
ORDER BY NumParts DESC;

/* Q14. VAT split: how much of the shelf price is German VAT (19 percent)?
        Assumption: UnitPrice is the gross shelf price, so net = price / 1.19. */
SELECT TOP (10)
    ProductName,
    UnitPrice                          AS GrossPrice,
    ROUND(UnitPrice / 1.19, 2)         AS NetPrice,
    UnitPrice - ROUND(UnitPrice / 1.19, 2) AS VatAmount
FROM dbo.Products
ORDER BY UnitPrice DESC;

/* Q15. Exclude a set of product lines with NOT IN and sort on two columns. */
SELECT TOP (20)
    ProductName, ProductLine, ReleaseYear, UnitPrice
FROM dbo.Products
WHERE ProductLine NOT IN (N'Duplo', N'Seasonal', N'Brickheadz')
  AND ReleaseYear = 2025
ORDER BY ProductLine ASC, UnitPrice DESC;
