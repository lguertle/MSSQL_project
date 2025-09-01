USE WideWorldImporters;
GO

DECLARE @obj1 int = OBJECT_ID('Sales.usp_HourlyCustomerSales');
DECLARE @obj2 int = OBJECT_ID('Sales.usp_HourlyCustomerSales_optimized');

WITH qs AS (
  SELECT
    qsq.object_id,
    OBJECT_SCHEMA_NAME(qsq.object_id) + '.' + OBJECT_NAME(qsq.object_id) AS proc_name,
    rs.count_executions,
    rs.avg_duration,          -- microseconds
    rs.avg_cpu_time,          -- microseconds
    rs.avg_logical_io_reads,  -- reads
    rs.last_execution_time
  FROM sys.query_store_query AS qsq
  JOIN sys.query_store_plan AS p
    ON qsq.query_id = p.query_id
  JOIN sys.query_store_runtime_stats AS rs
    ON p.plan_id = rs.plan_id
  WHERE qsq.object_id IN (@obj1, @obj2)
    AND rs.last_execution_time >= DATEADD(day, -1, SYSUTCDATETIME())
)
SELECT proc_name,
       SUM(count_executions)                                  AS execs,
       CAST(AVG(avg_duration)/1000.0 AS decimal(10,2))        AS avg_ms,
       CAST(AVG(avg_cpu_time)/1000.0 AS decimal(10,2))        AS avg_cpu_ms,
       CAST(AVG(avg_logical_io_reads) AS decimal(18,1))       AS avg_logical_reads,
       MAX(last_execution_time)                               AS last_run_utc
FROM qs
GROUP BY proc_name
ORDER BY avg_ms;