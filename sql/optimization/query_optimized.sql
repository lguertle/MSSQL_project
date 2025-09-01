CREATE OR ALTER PROCEDURE Sales.usp_HourlyCustomerSales_optimized
  @StartTime datetime2,
  @EndTime   datetime2
AS
BEGIN
  SET NOCOUNT ON;

  ;WITH OrderLineAgg AS (
    SELECT ol.OrderID,
           SUM(ol.LineAmount) AS OrderTotal
    FROM Sales.OrderLines AS ol
    GROUP BY ol.OrderID
  )
  SELECT o.CustomerID,
         c.CustomerName,
         SUM(ola.OrderTotal) AS TotalSales,
         COUNT(DISTINCT o.OrderID) AS OrdersCount
  FROM Sales.Orders AS o
  JOIN OrderLineAgg AS ola ON o.OrderID = ola.OrderID
  JOIN Sales.Customers AS c ON o.CustomerID = c.CustomerID
  WHERE o.OrderDate >= @StartTime
    AND o.OrderDate <  @EndTime
  GROUP BY o.CustomerID, c.CustomerName
  ORDER BY TotalSales DESC;
END
GO

