-- Run on WideWorldImporters

EXEC DataLoadSimulation.PopulateDataToCurrentDate
    @AverageNumberOfCustomerOrdersPerDay = 100,
    @SaturdayPercentageOfNormalWorkDay = 25,
    @SundayPercentageOfNormalWorkDay = 0,
    @IsSilentMode = 0,
    @AreDatesPrinted = 1;
GO
