# The household tariff model

# Model elements
## Data folder
Data folder contains the following files:
- **Battery_par.csv** - this file includes specific technical and economic data about battery bank in the household. It includes the following parameters:
    - *Capital_cost* - capital cost of the battery in DKK/kW
    - *OM_cost* - Yearly Operation and Maintenance costs in DKK/kW
    - *OP_cost* - Operational costs in DKK/MWh charged and discharged
    - *Charging_eff* - Charging efficiency in % of capacity
    - *Discharging_eff* - Discharging efficiency in % of capacity
    - *Charging_lim* - Limit of charging in one hour in in % of capacity
    - *Discharging_lim* - Limit of discharging in one hour in in % of capacity
    - *Min_charge* - Minimum level of state of charge in % of capacity
    - *Max_charge* - Maximum level of state of charge in $ of capacity
    - *Lifetime* - Battery lifetime in years
- **Demand_profiles.csv** - this file includes demand profiles (in kW) of each type of household t.
- **Electricity_prices.csv** - this file includes the prices for export and import of electricity in every hour of a year in  DKK/kWh
- **EV_avail.csv** - this file includes the hourly availability of EV in the household. It is 1 if the EV is available and 0 when not
- **EV_par.csv** - this file includes specific technical and economic data about EV in the household. It includes the following parameters:
    - *Charging_eff* - Charging efficiency in % of capacity
    - *Discharging_eff* - Discharging efficiency in % of capacity
    - *Charging_lim* - Limit of charging in one hour in in % of capacity
    - *Discharging_lim* - Limit of discharging in one hour in in % of capacity
    - *Min_charge* - Minimum level of state of charge in % of capacity
    - *Max_charge* - Maximum level of state of charge in $ of capacity
- **Grid_par.csv** - this file includes specific technical and economic data about EV in the household. It includes the following parameters:
        - *Ex_lim* - Limit of hourly electricity export to the grid in kW
        - *Im_lim* - Limit of hourly electricity import from the grid in kW

- **Household_types.csv** - this file includes the information about types of the elements that are included in each household type. The current elements to select are: PV, Battery and EV. In the matrix 1 means that element is included in the household type and 0 means that it is excluded.

- **Network_tariffs.csv** - this file includes specific information about the network tariffs and taxes. It includes the following parameters:
    - *Fixed_dist* - Value of the fixed distribution tariff payed on yearly basis in DKK
    - *Var_dist* - Level of variable distribution tariff payed on volume basis in DKK/kWh
    - *PSO* - Value of PSO tariff payed on volume basis in DKK/kWh
    - *Tax* - Level of energy tax payed on volume basis in DKK/kWh    
- **PV_par.csv** - this file includes specific technical and economic data about PV array in the household. It includes the following parameters:
    - *Capital_cost* - capital cost of the PV in DKK/kW
    - *OM_cost* - Yearly Operation and Maintenance costs in DKK/kW
    - *Lifetime* - PV lifetime in years

## ModelDataImport()
ModelDataImport() function imports data from Data folder.
