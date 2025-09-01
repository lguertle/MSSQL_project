CREATE OR ALTER PROCEDURE usp_GetTopCustomers
    @TopN INT = 10
AS
BEGIN
    SELECT TOP (@TopN)
        c.CustomerName,
        SUM(il.ExtendedPrice) AS TotalRevenue
    FROM Sales.Customers c
    INNER JOIN Sales.Invoices i ON c.CustomerID = i.CustomerID
    INNER JOIN Sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
    GROUP BY c.CustomerName
    ORDER BY TotalRevenue DESC;
END;
GO