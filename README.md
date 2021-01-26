# The household tariff model

# Model elements
### Data folder
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
- **Scalars.csv** - this file includes scalar values used in the model. It includes the following parameters:
    - *CRF* - capital recovery factor. This is the temporary capital recovery factor that is used in the objective function to annualize capital costs of technologies.
- **Sets.csv** - this file includes the sets that are used in the model. For now it includes sets T-time, Y-year, S-scenario:
- **SolarCF.csv** - this file includes the hourly capacity factor of PV array.

### *ModelDataImport()* function
*ModelDataImport()* function imports data from Data folder. In case of the one and more dimentional parameters it saves it as a DataFrames (e.g. PV_CF, El_price). In case of scalars, it reads data as dataframes and converts it into the dictionaries (e.g. Network_tariffs PV_par) with `|> Dict` operator. Sets are saved as a regular arrays. All the parameters, after reading from the function are saved as `global`, in order to use them outside of the function without calling them each time.

### *InitializeModel()* function
*InitializeModel()* function initializes the model (with symbol *M*) and defines the variables of the model. Function returns model object *M* with all variables defined. In this function also the solver of the model is defined.

### *FixingCap()* function
*FixingCap()* function takes as an input the model object *M*, the type of the household as a string and values of the capacities of respectively PV, battery and EV. This function reads parameter *Household_types* and based on the matrix fixes the capacities to the predefined levels (as an input to the function) if element is included in specific household type and to zero otherwise.

### *CalculatingParameters()* function
*CalculatingParameters()* function calculates the parameters that are later used in the model. This function takes as an input the scalars *SOC_goal* and *EV_cons_one_trip*. The former one is a goal of SOC that is set before every EV trip. The latter one is a consumption of single EV trip.
This function calculates and returns four 3-dimentional arrays:
- *Demand* is an array containing hourly household demand in every time t, year y and scenario s. Currently this is calculated based on single yearly time series from input data and assigned for every year and scenario.
- *EV_avail* it is the binary array containing hourly availability of EV in every time t, year y and scenario s. Currently this is calculated based on single yearly time series from input data and assigned for every year and scenario.
- *EV_demand* it is an array containing hourly consumption of EV in every time t, year y and scenario s. It is calculated based on the input scalar and *EV_avail*. Practically, the whole trip demand is assigned to the one hour before returning from the trip (retrieving availability).
- *EV_SOC_goal* it is an array containing hourly goal of EV in every time t, year y and scenario s. It is calculated based on the input scalar and *EV_avail*. Goal is set one hour before the start of every trip.

### *DefineConstraints()* function
*DefineConstraints()* introduces all the constraints of the model, presented in the mathematical model document. As an input this function takes the model object *M* and the type of the objective function to run as a string. This function returns model object with defined constraints. Currently there are two possible inputs:
- *new* - is a objective function with tariff and tax scheme proposed by Fausto et al.
- *base* - it is the base case function where traditional tariff is applied.

### *ExportVariable()* function
*ExportVariable()* is a auxiliary function that is used to transform the variable object of JuMP after solving to the DataFrame format. Currently it is able to handle up to 3-dimentional sets. If more dimensions should be handled then another loop should be added to the function following the pattern.

### *ExportResults()* function
*ExportResults()* is a function that exports the variables to Excel file. As an input this function takes the model object and the name of the file with extension. First this file checks whether filename exists in the current folder. If yes it removes it and creates new files and then pushes the particular DataFrames to spreadsheets.


# Running the model
The part of the script that runs the model is included at the end of the script. Before running this part all the functions in the script should be run.
There is the example of model run section:
- First import the data from Data folder:

`ModelDataImport()`
- Then initialize the model:

`M = InitializeModel()`
- Calculate the nessesery parameters:

`Demand, EV_avail, EV_demand, EV_SOC_goal =CalculatingParameters(30, 30*0.7)`
- Select the type of household that you want to run:

`Household_type = "T4"`
- Fix the variables:

`FixingCap(M, Household_type, 10, 10, 30)`
- Call the Optimize function:

`optimize!(M)`
- Export results to excel:

`ExportResults(M, "Results.xlsx")`
