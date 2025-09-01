USE WideWorldImporters;
GO

-- Index on Orders for filtering + grouping
CREATE NONCLUSTERED INDEX IX_Orders_OrderDate_CustomerID
ON Sales.Orders (OrderDate, CustomerID)
INCLUDE (OrderID);

-- Index on OrderLines for join + aggregation
CREATE NONCLUSTERED INDEX IX_OrderLines_OrderID
ON Sales.OrderLines (OrderID)
INCLUDE (Quantity, UnitPrice);

ALTER TABLE Sales.OrderLines
ADD LineAmount AS (Quantity * UnitPrice) PERSISTED;

-- Then let the index cover that single column:
CREATE NONCLUSTERED INDEX IX_OrderLines_OrderID_LineAmount
ON Sales.OrderLines(OrderID)
INCLUDE (LineAmount);