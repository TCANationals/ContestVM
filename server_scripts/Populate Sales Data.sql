-- Run on WideWorldImporters

EXEC DataLoadSimulation.PopulateDataToCurrentDate
    @AverageNumberOfCustomerOrdersPerDay = 350,
    @SaturdayPercentageOfNormalWorkDay = 40,
    @SundayPercentageOfNormalWorkDay = 0,
    @IsSilentMode = 0,
    @AreDatesPrinted = 1;
GO
