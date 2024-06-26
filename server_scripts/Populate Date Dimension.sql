-- Run on WideWorldImportersDW

DECLARE @YearCounter int = 2013;

WHILE @YearCounter <= 2024
BEGIN
    EXEC Integration.PopulateDateDimensionForYear @YearCounter;
    SET @YearCounter += 1;
END;
GO