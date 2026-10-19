# Stage 5: Interview preparation

## 2-minute project pitch

> I built an end-to-end sales analytics project for a fictional German retailer of LEGO® sets, using Microsoft SQL Server and Power BI.
>
> **Problem.** Management wanted to understand revenue and margin by channel, the best and fastest-growing product lines, the impact of the Christmas season and discounts, and whether loyalty members are worth more.
>
> **Data.** I combined the real LEGO® set catalog from Rebrickable, about 3,400 sets and a 500-theme hierarchy, with simulated sales: 19,000 orders and 33,000 order lines from 2023 to 2025 across five brand stores, an online shop and retail partners. I documented every simulation rule, and I added realistic data-quality problems on purpose.
>
> **Method.** I designed a normalized schema with seven tables, keys and constraints. Before any analysis I profiled the data, found 167 duplicate order lines, removed them with a CTE and ROW_NUMBER, and added a unique key so it cannot happen again. Then I answered the business questions in three levels: aggregations with GROUP BY and HAVING, then joins, CTEs, a recursive CTE for the theme hierarchy, and window functions for rankings, running totals and year-over-year growth. Finally I built a three-page Power BI dashboard on a reporting view with DAX measures.
>
> **Results.** Revenue grew 12 percent in 2024 and 14 percent in 2025. Own channels earn about 46 percent gross margin while retail partners earn only 30 percent. The fourth quarter brings almost 40 percent of the year's revenue. Premium sets are 9 percent of units but 37 percent of revenue, and loyalty members spend 18 percent more per order.
>
> **What I would recommend:** protect margin by growing own channels, plan stock and staff around Q4, and push the Insider program, because members buy more per visit.

Prepare one honest sentence for "Is this real data?": *The catalog is real; the sales are simulated with documented rules, because real retail transactions are confidential. The SQL and the analysis approach are the same as on real data.*

## 25 SQL interview questions

| # | Question | Short answer | Where in the project |
|---|---|---|---|
| 1 | What is the logical order of execution of a SELECT? | FROM, JOIN, WHERE, GROUP BY, HAVING, SELECT, DISTINCT, ORDER BY, TOP | Stage 1 Q4 |
| 2 | Can you use a column alias in WHERE? | No, WHERE runs before SELECT. You can use it in ORDER BY. | Q4 |
| 3 | Difference between WHERE and HAVING? | WHERE filters rows before grouping, HAVING filters groups after aggregation. | S7 |
| 4 | COUNT(*) vs COUNT(column) vs COUNT(DISTINCT column)? | All rows; non-NULL values; unique non-NULL values. | S14, DQ2 |
| 5 | How do you test for NULL? | `IS NULL` / `IS NOT NULL`; `= NULL` is never true. | Q10 |
| 6 | How do aggregates treat NULL? | They ignore it. That is why margin % divides by revenue with known cost only. | S4 |
| 7 | How do you find duplicates? | GROUP BY all key columns HAVING COUNT(*) > 1. | DQ4 |
| 8 | How do you delete duplicates and keep one copy? | CTE with ROW_NUMBER() PARTITION BY the key columns, delete rows with number > 1. | DQ6 |
| 9 | How do you prevent duplicates in future? | A UNIQUE constraint or primary key on the business key. | DQ7 |
| 10 | INNER JOIN vs LEFT JOIN? | INNER keeps only matches; LEFT keeps all rows from the left table, NULL where no match. | A1, A2 |
| 11 | How do you find records with no match (e.g. products never sold)? | LEFT JOIN and filter the right key IS NULL (or NOT EXISTS). | A2 |
| 12 | What is a self-join? | Joining a table to itself, e.g. a theme to its parent theme. | A3 |
| 13 | What is a recursive CTE and when do you use it? | A CTE that references itself; used for hierarchies like themes or org charts. | A4 |
| 14 | CTE vs subquery? | Same result; a CTE is named, readable and can be referenced more than once. | A6, A5 |
| 15 | What is a correlated subquery? | A subquery that uses a column of the outer query and runs per outer row. | A5 |
| 16 | ROW_NUMBER vs RANK vs DENSE_RANK? | ROW_NUMBER always unique; RANK leaves gaps after ties; DENSE_RANK has no gaps. | A7, A8 |
| 17 | How do you get the top N per group? | ROW_NUMBER() OVER (PARTITION BY group ORDER BY value DESC), filter rn <= N. | A7 |
| 18 | How do you calculate month-over-month growth? | LAG(value) OVER (ORDER BY month), then (current - previous) / previous. | A9 |
| 19 | How do you calculate a running total? | SUM(value) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING). | A10 |
| 20 | How do you calculate percent of total? | value / SUM(value) OVER (). | A11 |
| 21 | How do you pivot years into columns without PIVOT? | Conditional aggregation: SUM(CASE WHEN year = 2025 THEN revenue ELSE 0 END). | A12 |
| 22 | How do you avoid division by zero? | NULLIF(denominator, 0) in SQL, DIVIDE() in DAX. | A12 |
| 23 | What is a view and why use one? | A saved query; it hides joins and gives reports one consistent definition of revenue. | 06_views |
| 24 | Primary key vs foreign key vs unique constraint? | PK identifies a row; FK enforces a valid reference to another table; UNIQUE prevents duplicate values. | 01_schema |
| 25 | Why is integer division a trap? | 5 / 2 = 2 for integers; multiply by 100.0 or CAST to DECIMAL first. | S4, A11 |

## Business questions they may ask
- **Why do retail partners have a lower margin?** They buy in bulk at a 25 % wholesale discount, so revenue per unit is lower while cost stays the same.
- **Which channel would you invest in?** Own channels: higher margin, and the online shop has a slightly higher order value.
- **How would you validate your numbers?** Reconcile totals between SQL and Power BI (check values in the Power BI guide), check row counts after every load, and test edge cases like NULL cost and returns.
- **What would you do next with real data?** Add stock levels and marketing spend, forecast Q4 demand, and measure the effect of discounts on volume.
