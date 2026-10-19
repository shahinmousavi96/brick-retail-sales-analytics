/* =====================================================================
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
