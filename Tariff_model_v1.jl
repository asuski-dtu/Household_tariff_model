using CSV, DataFrames
using JuMP, Gurobi, CPLEX
import XLSX

# -------------------------------------------------------------------------------------------------------------------
#                             IMPORT OF SETS AND PARAMETERS FROM CSV FILES FUNCTION
# -------------------------------------------------------------------------------------------------------------------

function ModelDataImport()

    # Sets of the model
    global Sets = CSV.read("Data/Sets.csv", DataFrame)

    # Demand profile of household types
    global Demand_profiles = CSV.read("Data/Demand_profiles.csv", DataFrame)

    # Hourly electricity profiles
    global El_price = CSV.read("Data/Electricity_prices.csv", DataFrame)

    # Network tariffs including distribution tariffs, PSO and energy tax
    global Network_tariffs  = CSV.File("Data/Network_tariffs.csv") |> Dict

    # Technical and economic parameters of PV array
    global PV_par = CSV.File("Data/PV_par.csv") |> Dict

    # Technical and economic parameters of battery
    global Battery_par = CSV.File("Data/Battery_par.csv") |> Dict
    global Grid_par = CSV.File("Data/Grid_par.csv") |> Dict
    global Scalars = CSV.File("Data/Scalars.csv") |> Dict

    # Capacity factor of PV Array
    global PV_CF = CSV.read("Data/SolarCF.csv", DataFrame)[:,"SolarCF"]

    # Parameter defining the technologies in each technology type
    global Household_types = CSV.read("Data/Household_types.csv", DataFrame)

    # Assigning sets
    global T = Sets[:,"T"]
    global Y = collect(skipmissing(Sets[:,"Y"]))
    global S = collect(skipmissing(Sets[:,"S"]))

end

# -------------------------------------------------------------------------------------------------------------------
#                                   INITIALIZE MODEL AND THE VARIABLES FUNCTION
# -------------------------------------------------------------------------------------------------------------------


function InitializeModel()
    M = Model(Gurobi.Optimizer)

    # Battery related variables
    @variable(M, C_BT[s in S], lower_bound=0, base_name="Capacity of battery [kWh]")
    @variable(M, b_st[t in T, y in Y, s in S], lower_bound=0, base_name="Battery status in hour T")
    @variable(M, b_dh[t in T, y in Y, s in S], lower_bound=0, base_name="Battery discharging in hour T")
    @variable(M, b_dh_load[t in T, y in Y, s in S], lower_bound=0, base_name="Battery discharging to the load in hour T")
    @variable(M, b_dh_ex[t in T, y in Y, s in S], lower_bound=0, base_name="Battery discharging to the grid in hour T")
    @variable(M, b_ch[t in T, y in Y, s in S], lower_bound=0, base_name="Battery charging in hour T")

    # PV related constraints
    @variable(M, C_PV[s in S], lower_bound=0, base_name="Capacity of PV array [kW]")
    @variable(M, p_PV[t in T, y in Y, s in S], lower_bound=0, base_name="Production level of PV array [kW]")
    @variable(M, p_PV_load[t in T, y in Y, s in S], lower_bound=0, base_name="Production of PV array used directly to satisfy the load [kW]")
    @variable(M, p_PV_bat[t in T, y in Y, s in S], lower_bound=0, base_name="Production level of PV array used to charge the battery [kW]")
    @variable(M, p_PV_ex[t in T, y in Y, s in S], lower_bound=0, base_name="Production level of PV array exported to the grid[kW]")

    # Grid related constraints
    @variable(M, g_ex[t in T, y in Y, s in S], lower_bound=0, base_name="Export to the grid in hour T")
    @variable(M, g_im[t in T, y in Y, s in S], lower_bound=0, base_name="Import from the grid in hour T")
    @variable(M, g_im_load[t in T, y in Y, s in S], lower_bound=0, base_name="Import from the grid to satisfy the load in hour T")
    @variable(M, g_im_bat[t in T, y in Y, s in S], lower_bound=0, base_name="Import from the grid to charge the battery in hour T")
    return(M)
end

# -------------------------------------------------------------------------------------------------------------------
#                                        FIXING THE VARIABLES FUNCTION
# -------------------------------------------------------------------------------------------------------------------


# Fixing the capacity variables
function FixingCap(M,Type, ref_PV_cap, ref_BT_cap)
    if Household_types[Household_types[!, "Type"] .== Type, "PV"][1] == 0
        for s in S
            fix(M[:C_PV][s], 0; force=true)
        end
    else
        for s in S
            fix(M[:C_PV][s], ref_PV_cap; force=true)
        end
    end
    if Household_types[Household_types[!, "Type"] .== Type, "BT"][1] == 0
        for s in S
            fix(M[:C_BT][s], 0; force=true)
        end
    else
        for s in S
            fix(M[:C_BT][s], ref_BT_cap; force=true)
        end
    end
end

# Define the objective function

# -------------------------------------------------------------------------------------------------------------------
#                                      DEFINING THE CONSTRAINTS FUNCTION
# -------------------------------------------------------------------------------------------------------------------
function DefineConstraints(M, scheme)
    if scheme == "new"
        @objective(M, Min, sum(sum(Scalars["CRF"]*PV_par["Capital_cost"]*M[:C_PV]
            + Scalars["CRF"]*Battery_par["Capital_cost"]*M[:C_BT] for y in Y) +
            Battery_par["OP_cost"]*sum(M[:b_dh][t,y] + M[:b_ch][t,y] for t in T for y in Y) + sum(M[:g_im][t,y]*(El_price[t,"Tariff_import"]+Network_tariffs["Var_dist"]+Network_tariffs["PSO"]) - M[:g_ex][t,y]*(El_price[t,"Tariff_export"]+Network_tariffs["Var_dist"]) for t in T for y in Y)
            + sum(Network_tariffs["Fixed_dist"] for y in Y)
            + (Network_tariffs["Tax"] * sum(M[:g_im_load][t,y] + M[:p_PV_load][t,y] + M[:g_im_bat][t,y] + M[:p_PV_bat][t,y] - M[:b_dh_ex][t,y] for t in T for y in Y)) for s in S))

    elseif scheme == "base"
        @objective(M, Min, sum(sum(Scalars["CRF"]*PV_par["Capital_cost"]*M[:C_PV]
            + Scalars["CRF"]*Battery_par["Capital_cost"]*M[:C_BT] for y in Y) +
            Battery_par["OP_cost"]*sum(M[:b_dh][t,y] + M[:b_ch][t,y] for t in T for y in Y) + sum(M[:g_im][t,y]*(El_price[t,"Tariff_import"]+Network_tariffs["Var_dist"]+Network_tariffs["PSO"]+Network_tariffs["Tax"])
            - M[:g_ex][t,y]*El_price[t,"Tariff_export"] for t in T for y in Y)
            + sum(Network_tariffs["Fixed_dist"] for y in Y) for s in S))
    end

    # Balancing constraint taking into account only load flows
    @constraint(M, Balance[t in T, y in Y, s in S], M[:g_im_load][t,y] + M[:b_dh_load][t,y] + M[:p_PV_load][t,y] - Demand[t,y] == 0)

    # SOC regular balance when the hours set is not 1
    @constraint(M, SOC[t in T, y in Y, s in S; t>1], M[:b_st][t,y] == M[:b_st][t-1,y] - M[:b_dh][t,y]/Battery_par["Discharging_eff"] + M[:b_ch][t,y]*Battery_par["Charging_eff"])

    # SOC balance for the first hour and NOT first year
    @constraint(M, SOC_LastT[t in T, y in Y, s in S; t == 1 && y!=1], M[:b_st][t,y] == M[:b_st][last(T),y-1] - M[:b_dh][t,y]/Battery_par["Discharging_eff"] + M[:b_ch][t,y]*Battery_par["Charging_eff"])

    # SOC balance for the first hour and first year
    @constraint(M, SOC_First[t in T, y in Y, s in S; t==1 && y==1], M[:b_st][t,y] == M[:C_BT] - M[:b_dh][t,y]/Battery_par["Discharging_eff"] + M[:b_ch][t,y]*Battery_par["Charging_eff"] )

    # Limit on the maximum charge state of charge of the battery
    @constraint(M, SOC_lim_up[t in T, y in Y, s in S], M[:b_st][t,y] <= Battery_par["Max_charge"]*M[:C_BT])

    # Limit on the maximum hourly charging
    @constraint(M, Charge_limit[t in T, y in Y, s in S], M[:b_ch][t,y] <= Battery_par["Charging_lim"]*M[:C_BT])

    # Limit on the maximum hourly discharging
    @constraint(M, Discharge_limit[t in T, y in Y, s in S], M[:b_ch][t,y] <= Battery_par["Discharging_lim"]*M[:C_BT])

    # Limit on the minimum battery state of charge (depth of discharge)
    @constraint(M, SOC_lim_down[t in T, y in Y, s in S], M[:b_st][t,y] >= (1-Battery_par["Depth_of_discharge"])*M[:C_BT])

    # Limit on the amount of hourly exported electricity
    @constraint(M, grid_ex_lim[t in T, y in Y, s in S], M[:g_ex][t,y] <= Grid_par["Ex_lim"])

    # Limit on the amount of hourly imported electricity
    @constraint(M, grid_im_lim[t in T, y in Y, s in S], M[:g_im][t,y] <= Grid_par["Im_lim"])

    # Balance of the imported energy
    @constraint(M, grid_im_def[t in T, y in Y, s in S], M[:g_im][t,y] == M[:g_im_load][t,y] + M[:g_im_bat][t,y])

    # Balance of the exported energy
    @constraint(M, grid_ex_def[t in T, y in Y, s in S], M[:g_ex][t,y] == M[:p_PV_ex][t,y] + M[:b_dh_ex][t,y])

    # Balance of the charging energy
    @constraint(M, bat_ch_def[t in T, y in Y, s in S], M[:b_ch][t,y] == M[:p_PV_bat][t,y] + M[:g_im_bat][t,y])

    # Balance of the discharging energy
    @constraint(M, bat_dh_def[t in T, y in Y, s in S], M[:b_dh][t,y] == M[:b_dh_ex][t,y] + M[:b_dh_load][t,y])

    # Definition of the PV array production
    @constraint(M, PV_prod_def[t in T, y in Y, s in S], M[:C_PV]*PV_CF[t,y] == M[:p_PV][t,y])

    # Balance of the PV energy
    @constraint(M, PV_prod_bal[t in T, y in Y, s in S], M[:p_PV][t,y] == M[:p_PV_bat][t,y] + M[:p_PV_ex][t,y] + M[:p_PV_load][t,y])

    return M
end

# -------------------------------------------------------------------------------------------------------------------
#                                       EXPORTING THE RESULTS FUNCTION
# -------------------------------------------------------------------------------------------------------------------

# Function to convert variables to the data_frames
function ExportVariable(variable, sets, sets_names)
    # Create column names of the dataframe
    colnames= Symbol.(var for var in push!(sets_names, "Value"))

    # Create dataframe
    df = DataFrame(fill(Any, length(colnames)), colnames)

    for i1 in sets[1]
        if length(sets) == 1
            push!(df, Tuple([i1, value(variable[i1,i2])]))
        else
            for i2 in sets[2]
                if length(sets) == 2
                    push!(df, Tuple([i1, i2, value(variable[i1,i2])]))
                else
                    for i3 in sets[3]
                        if length(sets) == 2
                            push!(df, Tuple([i1, i2,i3, value(variable[i1,i2,i3])]))
                        end
                    end
                end
            end
        end
    end
    return df
end

# List of all variables (not in use now)
#VARS = [b_st,b_dh,b_dh_load,b_dh_ex,b_ch,p_PV,p_PV_load,p_PV_bat,p_PV_ex,g_ex,g_im,g_im_load,g_im_bat]

# If Results.xlsx exists then remove
function ExportResults(M, filename)
    if isfile(filename)
        rm(filename)
        println("Removing "*filename)
    end
    # Writing results to excel
    XLSX.writetable(filename,
                                b_st=( collect(DataFrames.eachcol(ExportVariable(M[:b_st],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:b_st],[T,Y,S],["T","Y","S"]))),

                                b_dh=( collect(DataFrames.eachcol(ExportVariable(M[:b_dh],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:b_dh],[T,Y,S],["T","Y","S"]))),

                                b_dh_load=( collect(DataFrames.eachcol(ExportVariable(M[:b_dh_load],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:b_dh_load],[T,Y,S],["T","Y","S"]))),

                                b_dh_ex=( collect(DataFrames.eachcol(ExportVariable(M[:b_dh_ex],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:b_dh_ex],[T,Y,S],["T","Y","S"]))),

                                b_ch=( collect(DataFrames.eachcol(ExportVariable(M[:b_ch],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:b_ch],[T,Y,S],["T","Y","S"]))),

                                p_PV=( collect(DataFrames.eachcol(ExportVariable(M[:p_PV],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:p_PV],[T,Y,S],["T","Y","S"]))),

                                p_PV_load=( collect(DataFrames.eachcol(ExportVariable(M[:p_PV_load],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:p_PV_load],[T,Y,S],["T","Y","S"]))),

                                p_PV_bat=( collect(DataFrames.eachcol(ExportVariable(M[:p_PV_bat],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:p_PV_bat],[T,Y,S],["T","Y","S"]))),

                                g_ex=( collect(DataFrames.eachcol(ExportVariable(M[:g_ex],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:g_ex],[T,Y,S],["T","Y","S"]))),

                                g_im=( collect(DataFrames.eachcol(ExportVariable(M[:g_im],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:g_im],[T,Y,S],["T","Y","S"]))),

                                g_im_load=( collect(DataFrames.eachcol(ExportVariable(M[:g_im_load],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:g_im_load],[T,Y,S],["T","Y","S"]))),

                                g_im_bat=( collect(DataFrames.eachcol(ExportVariable(M[:g_im_bat],[T,Y,S],["T","Y","S"]))), DataFrames.names(ExportVariable(M[:g_im_bat],[T,Y,S],["T","Y","S"]))),
                                )
end


# -------------------------------------------------------------------------------------------------------------------
#                                       RUNNING THE MODEL
# -------------------------------------------------------------------------------------------------------------------
ModelDataImport()
M = InitializeModel()
# SELECTING THE TYPE OF DEMAND
Household_type = "T2"
# Fixing the demand for a specific year
Demand = Array{Float64}(undef, length(T), length(Y), length(S))
Demand[:,:,:] .= Demand_profiles[:,Household_type]
FixingCap(M,Household_type, 20, 100)
DefineConstraints(M, "new")
optimize!(M)
ExportResults(M, "Results.xlsx")
