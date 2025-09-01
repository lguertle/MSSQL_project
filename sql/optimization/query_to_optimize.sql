CREATE OR ALTER PROCEDURE Sales.usp_HourlyCustomerSales
    @StartTime DATETIME2,
    @EndTime DATETIME2
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        o.CustomerID,
        c.CustomerName,
        SUM(ol.Quantity * ol.UnitPrice) AS TotalSales,
        COUNT(DISTINCT o.OrderID) AS OrdersCount
    FROM Sales.Orders o WITH (INDEX(0))
    INNER JOIN Sales.OrderLines ol WITH (INDEX(0)) ON o.OrderID = ol.OrderID
    INNER JOIN Sales.Customers c WITH (INDEX(0)) ON o.CustomerID = c.CustomerID
    WHERE o.OrderDate >= @StartTime
      AND o.OrderDate < @EndTime
    GROUP BY o.CustomerID, c.CustomerName
    ORDER BY TotalSales DESC;
END;
GO