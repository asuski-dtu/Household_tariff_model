using CSV, DataFrames
using JuMP, Gurobi, CPLEX

Sets = CSV.read("Data/Sets.csv", DataFrame)
#Sets = Dict( string(i) => collect(skipmissing(Sets[:,i])) for i in names(Sets))

Demand_profiles = CSV.read("Data/Demand_profiles.csv", DataFrame)

Tariffs= CSV.read("Data/Tariff.csv", DataFrame)

PV_par = CSV.File("Data/PV_par.csv") |> Dict
Battery_par = CSV.File("Data/Battery_par.csv") |> Dict
Grid_par = CSV.File("Data/Grid_par.csv") |> Dict

PV_CF = CSV.read("Data/SolarCF.csv", DataFrame)[:,"SolarCF"]

# SETS
T = Sets[:,"T"]

# SELECTING THE TYPE OF DEMAND

Demand_Type = "T1"

M = Model(CPLEX.Optimizer)

# Battery related variables
@variable(M, C_BT, lower_bound=0, base_name="Capacity of battery [kWh]")
@variable(M, b_st[t in T], lower_bound=0, base_name="Battery status in hour T")
@variable(M, b_dh[t in T], lower_bound=0, base_name="Battery discharging in hour T")
@variable(M, b_ch[t in T], lower_bound=0, base_name="Battery charging in hour T")

# PV related constraints
@variable(M, C_PV, lower_bound=0, base_name="Capacity of PV array [kW]")
@variable(M, p_PV[t in T], lower_bound=0, base_name="Production level of PV array [kW]")

# Grid related constraints
@variable(M, g_ex[t in T], lower_bound=0, base_name="Export to the grid in hour T")
@variable(M, g_im[t in T], lower_bound=0, base_name="Import from the grid in hour T")

# Fixing the capacity variables
fix(C_PV, 100; force=true);
fix(C_BT, 20; force=true);

# Define the objective function
@objective(M, Min, PV_par["Capital_cost"]*C_PV + Battery_par["Capital_cost"]*C_BT + sum(g_im[t]*Tariffs[t,"Tariff_import"] - g_ex[t]*Tariffs[t,"Tariff_export"] for t in T))

@constraint(M, Balance[t in T], C_PV*PV_CF[t] + b_dh[t] - b_ch[t] - Demand_profiles[t,Demand_Type] - g_ex[t] + g_im[t] == 0)

@constraint(M, SOC[t in T; t>1], b_st[t] == b_st[t-1] - b_dh[t]/Battery_par["Discharging_eff"] + b_ch[t]*Battery_par["Charging_eff"])

@constraint(M, SOC_1[t in T; t==1], b_st[t] == C_BT - b_dh[t]/Battery_par["Discharging_eff"] + b_ch[t]*Battery_par["Charging_eff"] )

@constraint(M, SOC_lim_up[t in T], b_st[t] <= Battery_par["Max_charge"]*C_BT)

@constraint(M, SOC_lim_down[t in T], b_st[t] >= (1-Battery_par["Depth_of_discharge"])*C_BT)

@constraint(M, grid_ex_lim[t in T], g_ex[t] <= Grid_par["Ex_lim"])

@constraint(M, grid_im_lim[t in T], g_im[t] <= Grid_par["Im_lim"])


# ---------------------------------
# SOLVING COMMANDS
optimize!(M)


println( "----------- OBJECTIVE FUNCTION ------------")
println( "OF: ",round(objective_value(M)),"\n")
println( "\n")


df_results = DataFrame(Battery_status=[value.(b_st[t]) for t in T] , Battery_charging=[value.(b_ch[t]) for t in T], Battery_discharging=[value.(b_dh[t])  for t in T], PV_prod=value.(C_PV)*PV_CF[:], Grid_export = [value.(g_ex[t])  for t in T], Grid_import = [value.(g_im[t])  for t in T], Demand = Demand_profiles[:,Demand_Type])

@show df_results[1:20,:]
