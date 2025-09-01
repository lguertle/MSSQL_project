CREATE OR ALTER PROCEDURE usp_GetMonthlyRevenue
AS
BEGIN
    SELECT 
        YEAR(i.InvoiceDate) AS [Year],
        MONTH(i.InvoiceDate) AS [MonthNumber],
        DATENAME(MONTH, i.InvoiceDate) AS [MonthName],
        SUM(il.ExtendedPrice) AS TotalRevenue
    FROM Sales.Invoices i
    INNER JOIN Sales.InvoiceLines il 
        ON i.InvoiceID = il.InvoiceID
    GROUP BY YEAR(i.InvoiceDate), MONTH(i.InvoiceDate), DATENAME(MONTH, i.InvoiceDate)
    ORDER BY [Year], [MonthNumber];
END;
GO