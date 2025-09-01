CREATE OR ALTER PROCEDURE usp_OrderStatsPerCustomer_Complete
AS
BEGIN
    ;WITH CustomerOrders AS
    (
        SELECT 
            o.OrderID,
            o.CustomerID,
            o.OrderDate,
            SUM(ol.Quantity * ol.UnitPrice) AS TotalValue
        FROM Sales.Orders o
        INNER JOIN Sales.OrderLines ol ON o.OrderID = ol.OrderID
        GROUP BY o.OrderID, o.CustomerID, o.OrderDate
    ),
    CustomerIntervals AS
    (
        SELECT
            OrderID,
            CustomerID,
            TotalValue,
            OrderDate,
            LAG(OrderDate) OVER(PARTITION BY CustomerID ORDER BY OrderDate) AS PrevOrderDate,
            DATEDIFF(DAY, LAG(OrderDate) OVER(PARTITION BY CustomerID ORDER BY OrderDate), OrderDate) AS DaysBetweenOrders
        FROM CustomerOrders
    ),
    CustomerStats AS
    (
        SELECT
            co.CustomerID,
            -- Order Value Statistics
            MIN(co.TotalValue) AS MinOrderValue,
            MAX(co.TotalValue) AS MaxOrderValue,
            AVG(co.TotalValue) AS AvgOrderValue,
            STDEV(co.TotalValue) AS OrderValueStdDev,
            
            -- Timing Statistics (excluding first order which has no previous order)
            AVG(ci.DaysBetweenOrders) AS AvgDaysBetweenOrders,
            STDEV(ci.DaysBetweenOrders) AS DaysBetweenOrdersStdDev,
            MIN(ci.DaysBetweenOrders) AS MinDaysBetweenOrders,
            MAX(ci.DaysBetweenOrders) AS MaxDaysBetweenOrders,
            
            -- Order Count
            COUNT(co.OrderID) AS NumberOfOrders,
            COUNT(ci.DaysBetweenOrders) AS NumberOfIntervals  -- For timing analysis
        FROM CustomerOrders co
        LEFT JOIN CustomerIntervals ci ON co.OrderID = ci.OrderID AND co.CustomerID = ci.CustomerID
        GROUP BY co.CustomerID
    )
    SELECT
        c.CustomerName,
        cs.NumberOfOrders,
        cs.NumberOfIntervals,
        
        -- Order Value Metrics
        ROUND(cs.MinOrderValue, 2) AS MinOrderValue,
        ROUND(cs.MaxOrderValue, 2) AS MaxOrderValue,
        ROUND(cs.AvgOrderValue, 2) AS AvgOrderValue,
        ROUND(cs.OrderValueStdDev, 2) AS OrderValueStdDev,
        
        -- Timing Metrics
        ROUND(cs.AvgDaysBetweenOrders, 1) AS AvgDaysBetweenOrders,
        ROUND(cs.DaysBetweenOrdersStdDev, 1) AS DaysBetweenOrdersStdDev,
        cs.MinDaysBetweenOrders,
        cs.MaxDaysBetweenOrders,
        
        -- VALUE STABILITY SCORES
        CAST(ROUND(
            CASE 
                WHEN cs.AvgOrderValue = 0 OR cs.OrderValueStdDev IS NULL THEN NULL
                ELSE 100 / (1 + (cs.OrderValueStdDev / cs.AvgOrderValue))
            END, 1) AS DECIMAL(5,1)) AS ValueStabilityScore,
        
        -- TIMING STABILITY SCORES
        CAST(ROUND(
            CASE 
                WHEN cs.AvgDaysBetweenOrders = 0 OR cs.DaysBetweenOrdersStdDev IS NULL OR cs.NumberOfIntervals < 2 THEN NULL
                ELSE 100 / (1 + (cs.DaysBetweenOrdersStdDev / cs.AvgDaysBetweenOrders))
            END, 1) AS DECIMAL(5,1)) AS TimingStabilityScore,
        
        -- COMBINED STABILITY SCORE (Average of both dimensions)
        CAST(ROUND(
            CASE 
                WHEN (cs.AvgOrderValue = 0 OR cs.OrderValueStdDev IS NULL) 
                  OR (cs.AvgDaysBetweenOrders = 0 OR cs.DaysBetweenOrdersStdDev IS NULL OR cs.NumberOfIntervals < 2) THEN NULL
                ELSE (
                    (100 / (1 + (cs.OrderValueStdDev / cs.AvgOrderValue))) + 
                    (100 / (1 + (cs.DaysBetweenOrdersStdDev / cs.AvgDaysBetweenOrders)))
                ) / 2
            END, 1) AS DECIMAL(5,1)) AS OverallStabilityScore,
        
        -- CONSISTENCY RATINGS
        -- Value Consistency
        CASE 
            WHEN cs.AvgOrderValue = 0 OR cs.OrderValueStdDev IS NULL THEN 'Unknown'
            WHEN cs.OrderValueStdDev = 0 THEN 'Perfect'
            WHEN (cs.OrderValueStdDev / cs.AvgOrderValue) <= 0.15 THEN 'Very Stable'
            WHEN (cs.OrderValueStdDev / cs.AvgOrderValue) <= 0.30 THEN 'Stable'
            WHEN (cs.OrderValueStdDev / cs.AvgOrderValue) <= 0.50 THEN 'Moderate'
            WHEN (cs.OrderValueStdDev / cs.AvgOrderValue) <= 1.0 THEN 'Variable'
            ELSE 'Highly Variable'
        END AS ValueConsistency,
        
        -- Timing Consistency  
        CASE 
            WHEN cs.AvgDaysBetweenOrders = 0 OR cs.DaysBetweenOrdersStdDev IS NULL OR cs.NumberOfIntervals < 2 THEN 'Unknown'
            WHEN cs.DaysBetweenOrdersStdDev = 0 THEN 'Perfect'
            WHEN (cs.DaysBetweenOrdersStdDev / cs.AvgDaysBetweenOrders) <= 0.25 THEN 'Very Regular'  -- e.g., 7±1.75 days
            WHEN (cs.DaysBetweenOrdersStdDev / cs.AvgDaysBetweenOrders) <= 0.50 THEN 'Regular'      -- e.g., 7±3.5 days  
            WHEN (cs.DaysBetweenOrdersStdDev / cs.AvgDaysBetweenOrders) <= 0.75 THEN 'Somewhat Regular' -- e.g., 7±5.25 days
            WHEN (cs.DaysBetweenOrdersStdDev / cs.AvgDaysBetweenOrders) <= 1.0 THEN 'Irregular'    -- e.g., 7±7 days
            ELSE 'Highly Irregular'
        END AS TimingConsistency,
        
        -- LOYALTY CLASSIFICATION (combining both dimensions)
        CASE 
            WHEN cs.NumberOfOrders < 3 THEN 'New/Infrequent'
            WHEN (cs.OrderValueStdDev / NULLIF(cs.AvgOrderValue,0)) <= 0.30 
                 AND (cs.DaysBetweenOrdersStdDev / NULLIF(cs.AvgDaysBetweenOrders,0)) <= 0.50 
                 AND cs.NumberOfIntervals >= 2
                THEN 'Highly Loyal'
            WHEN (cs.OrderValueStdDev / NULLIF(cs.AvgOrderValue,0)) <= 0.50 
                 AND (cs.DaysBetweenOrdersStdDev / NULLIF(cs.AvgDaysBetweenOrders,0)) <= 0.75 
                 AND cs.NumberOfIntervals >= 2
                THEN 'Loyal'
            WHEN cs.NumberOfOrders >= 5 THEN 'Regular but Variable'
            ELSE 'Occasional'
        END AS LoyaltyClassification,
        
        -- Raw coefficients for analysis
        CAST(ROUND(cs.OrderValueStdDev / NULLIF(cs.AvgOrderValue,0), 3) AS DECIMAL(6,3)) AS ValueCV,
        CAST(ROUND(cs.DaysBetweenOrdersStdDev / NULLIF(cs.AvgDaysBetweenOrders,0), 3) AS DECIMAL(6,3)) AS TimingCV
        
    FROM Sales.Customers c
    INNER JOIN CustomerStats cs ON c.CustomerID = cs.CustomerID
    WHERE cs.NumberOfOrders >= 2  -- Only customers with at least 2 orders
    ORDER BY AvgOrderValue DESC, cs.NumberOfOrders DESC;
END;
GO



