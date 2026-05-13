-- Visual Studio 2026 community
-- from inside VS Extensions, install:
--    SQL Server Integration Services Projects
--      https://marketplace.visualstudio.com/items?itemName=SSIS.MicrosoftDataToolsIntegrationServices
--    Analysis Services
-- Run on WideWorldImportersDW

DECLARE @YearCounter int = 2013;

WHILE @YearCounter <= 2026 -- set current year
BEGIN
    EXEC Integration.PopulateDateDimensionForYear @YearCounter;
    SET @YearCounter += 1;
END;
GO
