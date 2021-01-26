# The household tariff model

# Model elements
## Data folder
Data folder contains the following files:
- Battery_par.csv - this file includes specific technical and economic data about battery bank in the households. It includes the following parameters:
    - Capital_cost - capital cost of the battery in DKK/kW
    - OM_cost - Yearly Operation and Maintenance costs in DKK/kW
    - OP_cost - Operational costs in DKK/MWh charged and discharged
    - Charging_eff - Charging efficiency in % of capacity
    - Discharging_eff - Discharging efficiency in % of capacity
    - Charging_lim - Limit of charging in one hour in in % of capacity
    - Discharging_lim - Limit of discharging in one hour in in % of capacity
    - Min_charge - Minimum level of state of charge in % of capacity
    - Max_charge - Maximum level of state of charge in $ of capacity
    - Lifetime - Battery lifetime in years

## ModelDataImport()
ModelDataImport() function imports data from Data folder.
