using CSV, DataFrames
using JuMP, Gurobi, CPLEX
import XLSX

# -------------------------------------------------------------------------------------------------------------------
#                             IMPORT OF SETS AND PARAMETERS FROM CSV FILES FUNCTION
# -------------------------------------------------------------------------------------------------------------------

function ModelDataImport()

    # Sets of the model
    global Sets = DataFrame(XLSX.readtable("Data/Input_Data_Tariff_Model.xlsx", "Sets")...)

    # Demand profile of household types
    global Demand_profiles = DataFrame(XLSX.readtable("Data/Input_Data_Tariff_Model.xlsx", "Demand_profiles")...)

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
    global PV_CF = DataFrame(XLSX.readtable("Data/Input_Data_Tariff_Model.xlsx", "SolarCF")...)

    # Parameter defining the technologies in each technology type
    global Household_types  = DataFrame(XLSX.readtable("Data/Input_Data_Tariff_Model.xlsx", "Household_types")...)

    # EV parameters
    global EV_DF = DataFrame(XLSX.readtable("Data/Input_Data_Tariff_Model.xlsx", "EV_avail")...)
    global EV_par = CSV.File("Data/EV_par.csv") |> Dict

    # Assigning sets
    global T = Sets[:,"T"]
    global Y = collect(skipmissing(Sets[:,"Y"]))
    global S = collect(skipmissing(Sets[:,"S"]))
    global H = collect(skipmissing(Sets[:,"Household"]))

end

# -------------------------------------------------------------------------------------------------------------------
#                                   INITIALIZE MODEL AND THE VARIABLES FUNCTION
# -------------------------------------------------------------------------------------------------------------------

function InitializeModel()
    M = Model(Gurobi.Optimizer)

    # Battery related variables
    @variable(M,C_BT[h=H,s=S],lower_bound=0,base_name="C_BT[h=H,s=S]:")
    @variable(M,b_st[t=T,y=Y,h=H,s=S],lower_bound=0,     base_name="b_st[t=T,y=Y,h=H,s=S]:")
    @variable(M,b_dh[t=T,y=Y,h=H,s=S],lower_bound=0,     base_name="b_dh[t=T,y=Y,h=H,s=S]:")
    @variable(M,b_dh_load[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="b_dh_load[t=T,y=Y,h=H,s=S]:")
    @variable(M,b_dh_ex[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="b_dh_ex[t=T,y=Y,h=H,s=S]:")
    @variable(M,b_dh_ev[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="b_dh_ev[t=T,y=Y,h=H,s=S]:")
    @variable(M,b_ch[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="b_ch[t=T,y=Y,h=H,s=S]:")

    # EV related variables
    @variable(M,C_EV[h=H,s=S],lower_bound=0,base_name="C_EV[h=H,s=S]:")
    @variable(M,ev_st[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="ev_st[t=T,y=Y,h=H,s=S]:")
    @variable(M,ev_dh[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="ev_dh[t=T,y=Y,h=H,s=S]:")
    @variable(M,ev_ch[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="ev_ch[t=T,y=Y,h=H,s=S]:")
    @variable(M,ev_dh_load[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="ev_dh_load[t=T,y=Y,h=H,s=S]:")
    @variable(M,ev_dh_ex[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="ev_dh_ex[t=T,y=Y,h=H,s=S]:")

    # PV related constraints
    @variable(M,C_PV[h=H,s=S],lower_bound=0,base_name="C_PV[h=H,s=S]:")
    @variable(M,p_PV[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="p_PV[t=T,y=Y,h=H,s=S]:")
    @variable(M,p_PV_load[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="p_PV_load[t=T,y=Y,h=H,s=S]:")
    @variable(M,p_PV_bat[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="p_PV_bat[t=T,y=Y,h=H,s=S]:")
    @variable(M,p_PV_ev[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="p_PV_ev[t=T,y=Y,h=H,s=S]:")
    @variable(M,p_PV_ex[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="p_PV_ex[t=T,y=Y,h=H,s=S]:")

    # Grid related constraints
    @variable(M,g_ex[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="g_ex[t=T,y=Y,h=H,s=S]:")
    @variable(M,g_im[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="g_im[t=T,y=Y,h=H,s=S]:")
    @variable(M,g_im_load[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="g_im_load[t=T,y=Y,h=H,s=S]:")
    @variable(M,g_im_bat[t=T,y=Y,h=H,s=S],lower_bound=0,base_name="g_im_bat[t=T,y=Y,h=H,s=S]:")
    @variable(M,g_im_ev[t=T,y = Y,h=H,s=S],lower_bound=0,base_name="g_im_ev[t=T,y=Y,h=H,s=S]:")
    return(M)
end

# -------------------------------------------------------------------------------------------------------------------
#                                        FIXING THE VARIABLES FUNCTION
# -------------------------------------------------------------------------------------------------------------------

# Fixing the capacity variables
function FixingCap(M, ref_PV_cap, ref_BT_cap, ref_EV_cap)
    for h in H
        if Household_types[Household_types[!, "Type"] .== h, "PV"][1] == 0
            for s in S
                fix(M[:C_PV][h,s], 0; force=true)
            end
        else
            for s in S
                fix(M[:C_PV][h,s], ref_PV_cap; force=true)
            end
        end
        if Household_types[Household_types[!, "Type"] .== h, "BT"][1] == 0
            for s in S
                fix(M[:C_BT][h,s], 0; force=true)
            end
        else
            for s in S
                fix(M[:C_BT][h,s], ref_BT_cap; force=true)
            end
        end
        if Household_types[Household_types[!, "Type"] .== h, "EV"][1] == 0
            for s in S
                fix(M[:C_EV][h,s], 0; force=true)
            end
        else
            for s in S
                fix(M[:C_EV][h,s], ref_EV_cap; force=true)
            end
        end
    end
end

# -------------------------------------------------------------------------------------------------------------------
#                                   CALCULATING THE PARAMETERS TO USE IN THE MODEL
# -------------------------------------------------------------------------------------------------------------------

# The first input to the function is SOC_goal before each trip and second one is a one time electricity consumption of the trip
function CalculatingParameters(SOC_goal, EV_cons_one_trip)

    # Initializing empty 4-dimentional array based on sets T,Y and S
    # Demand = Array{Float64}(undef, length(T), length(Y), length(H), length(S))
    Demand = Dict{Tuple{Int64,Int64,String,Int64},Float64}()
    # Assigning the imported data frame with specific demand profile to demand dictionary
    for s in S
        for y in Y
            for h in H
                for t in T
                    Demand[(t,y,h,s)] = Demand_profiles[t,h]
                end
            end
        end
    end

    # Initializing empty 3-dimentional array based on sets T,Y and S
    EV_avail = Dict{Tuple{Int64,Int64,String,Int64},Float64}()
    # Assigning the availability data imported from csv file
    for s in S
        for y in Y
            for h in H
                for t in T
                    EV_avail[(t,y,h,s)] = EV_DF[t,h]
                end
            end
        end
    end

    # Initializing empty 3-dimentional array based on sets T,Y and S
    EV_demand = Dict{Tuple{Int64,Int64,String,Int64},Float64}()
    # Assigning data to the array based on the availability array as well as the second input to the function.
    for s in S
        for y in Y
            for h in H
                for i=1:(size(EV_DF,1)-1)
                    if Household_types[Household_types[!, "Type"] .== h, "EV"][1] != 0
                        if EV_DF[i,h]==0 && EV_DF[i+1,h]==1
                            EV_demand[(i,y,h,s)] = EV_cons_one_trip
                        else
                            EV_demand[(i,y,h,s)] = 0
                        end
                    else
                        EV_demand[(i,y,h,s)] = 0
                    end
                end
                EV_demand[(size(EV_DF,1),y,h,s)] = 0
            end
        end
    end

    # Initializing empty 3-dimentional array based on sets T,Y and S
    EV_SOC_goal = Dict{Tuple{Int64,Int64,String,Int64},Float64}()
    #EV_SOC_goal[:,:,:] .= 0
    # Assigning data to the array based on the availability array as well as the first input to the function.
    for s in S
        for y in Y
            for h in H
                for i=1:(size(EV_DF,1)-1)
                    if Household_types[Household_types[!, "Type"] .== h, "EV"][1] != 0
                        if EV_DF[i,h]==1 && EV_DF[i+1,h]==0
                            EV_SOC_goal[(i,y,h,s)] = SOC_goal
                        else
                            EV_SOC_goal[(i,y,h,s)] = 0
                        end
                    else
                        EV_SOC_goal[(i,y,h,s)] = 0
                    end
                end
                EV_SOC_goal[(size(EV_DF,1),y,h,s)] = 0
            end
        end
    end
    return Demand, EV_avail, EV_demand, EV_SOC_goal

end

# -------------------------------------------------------------------------------------------------------------------
#                                      DEFINING THE CONSTRAINTS FUNCTION
# -------------------------------------------------------------------------------------------------------------------
function DefineConstraints(M, scheme)
    if scheme == "new"
        @objective(M, Min, sum(sum((Scalars["CRF"]*PV_par["Capital_cost"]+PV_par["OM_cost"])*M[:C_PV][h,s]
            + (Scalars["CRF"]*Battery_par["Capital_cost"]+ Battery_par["OM_cost"])*M[:C_BT][h,s] for y in Y) +
            Battery_par["OP_cost"]*sum(M[:b_dh][t,y,h,s] + M[:b_ch][t,y,h,s] for t in T for y in Y) + sum(M[:g_im][t,y,h,s]*(El_price[t,"Tariff_import"]+Network_tariffs["Var_dist"]+Network_tariffs["PSO"]) - M[:g_ex][t,y,h,s]*(El_price[t,"Tariff_export"]+Network_tariffs["Var_dist"]) for t in T for y in Y)
            + sum(Network_tariffs["Fixed_dist"] for y in Y)
            + (Network_tariffs["Tax"] * sum(M[:g_im_load][t,y,h,s] + M[:p_PV_load][t,y,h,s] + M[:g_im_bat][t,y,h,s] + M[:p_PV_bat][t,y,h,s] - M[:b_dh_ex][t,y,h,s] for t in T for y in Y)) for h in H for s in S))

    elseif scheme == "base"
        @objective(M, Min, sum(sum((Scalars["CRF"]*PV_par["Capital_cost"]+PV_par["OM_cost"])*M[:C_PV][h,s]
            + (Scalars["CRF"]*Battery_par["Capital_cost"]+ Battery_par["OM_cost"])*M[:C_BT][h,s] for y in Y)
            + Battery_par["OP_cost"] * sum(M[:b_dh][t,y,h,s] + M[:b_ch][t,y,h,s] for t in T for y in Y)
            + sum(M[:g_im][t,y,h,s] * (El_price[t,"Tariff_import"] + Network_tariffs["Var_dist"] + Network_tariffs["PSO"] + Network_tariffs["Tax"])
            - M[:g_ex][t,y,h,s] * El_price[t,"Tariff_export"] for t in T for y in Y)
            + sum(Network_tariffs["Fixed_dist"] for y in Y) for h in H for s in S))
    end

    # Balancing constraint taking into account only load flows
    @constraint(M, Balance[t in T, y in Y, h in H, s in S], M[:g_im_load][t,y,h,s] + M[:b_dh_load][t,y,h,s] + M[:ev_dh_load][t,y,h,s] + M[:p_PV_load][t,y,h,s] - Demand[(t,y,h,s)] == 0)

    # SOC regular balance when the hours set is not 1
    @constraint(M, SOC[t in T, y in Y, h in H, s in S; t>1], M[:b_st][t,y,h,s] == M[:b_st][t-1,y,h,s] - M[:b_dh][t,y,h,s]/Battery_par["Discharging_eff"] + M[:b_ch][t,y,h,s]*Battery_par["Charging_eff"])

    # SOC balance for the first hour and NOT first year
    @constraint(M, SOC_LastT[t in T, y in Y, h in H, s in S; t == 1 && y!=1], M[:b_st][t,y,h,s] == M[:b_st][last(T),y-1,h,s] - M[:b_dh][t,y,h,s]/Battery_par["Discharging_eff"] + M[:b_ch][t,y,h,s]*Battery_par["Charging_eff"])

    # SOC balance for the first hour and first year
    @constraint(M, SOC_First[t in T, y in Y, h in H, s in S; t==1 && y==1], M[:b_st][t,y,h,s] == M[:C_BT][h,s] - M[:b_dh][t,y,h,s]/Battery_par["Discharging_eff"] + M[:b_ch][t,y,h,s]*Battery_par["Charging_eff"] )

    # Limit on the maximum charge state of charge of the battery
    @constraint(M, SOC_lim_up[t in T, y in Y, h in H, s in S], M[:b_st][t,y,h,s] <= Battery_par["Max_charge"]*M[:C_BT][h,s])

    # Limit on the maximum hourly charging
    @constraint(M, Charge_limit[t in T, y in Y, h in H, s in S], M[:b_ch][t,y,h,s] <= Battery_par["Charging_lim"]*M[:C_BT][h,s])

    # Limit on the maximum hourly discharging
    @constraint(M, Discharge_limit[t in T, y in Y, h in H, s in S], M[:b_ch][t,y,h,s] <= Battery_par["Discharging_lim"]*M[:C_BT][h,s])

    # Limit on the minimum battery state of charge
    @constraint(M, SOC_lim_down[t in T, y in Y, h in H, s in S], M[:b_st][t,y,h,s] >= Battery_par["Min_charge"]*M[:C_BT][h,s])

    # Limit on the amount of hourly exported electricity
    @constraint(M, grid_ex_lim[t in T, y in Y, h in H, s in S], M[:g_ex][t,y,h,s] <= Grid_par["Ex_lim"])

    # Limit on the amount of hourly imported electricity
    @constraint(M, grid_im_lim[t in T, y in Y, h in H, s in S], M[:g_im][t,y,h,s] <= Grid_par["Im_lim"])

    # Balance of the imported energy
    @constraint(M, grid_im_def[t in T, y in Y, h in H, s in S], M[:g_im][t,y,h,s] == M[:g_im_load][t,y,h,s] + M[:g_im_bat][t,y,h,s] + M[:g_im_ev][t,y,h,s])

    # Balance of the exported energy
    @constraint(M, grid_ex_def[t in T, y in Y, h in H, s in S], M[:g_ex][t,y,h,s] == M[:p_PV_ex][t,y,h,s] + M[:b_dh_ex][t,y,h,s] + M[:ev_dh_ex][t,y,h,s])

    # Balance of the charging energy
    @constraint(M, bat_ch_def[t in T, y in Y, h in H, s in S], M[:b_ch][t,y,h,s] == M[:p_PV_bat][t,y,h,s] + M[:g_im_bat][t,y,h,s])

    # Balance of the discharging energy
    @constraint(M, bat_dh_def[t in T, y in Y, h in H, s in S], M[:b_dh][t,y,h,s] == M[:b_dh_ex][t,y,h,s] + M[:b_dh_load][t,y,h,s] + M[:b_dh_ev][t,y,h,s])

    # Definition of the PV array production
    @constraint(M, PV_prod_def[t in T, y in Y, h in H, s in S], M[:C_PV][h,s]*PV_CF[t,y] == M[:p_PV][t,y,h,s])

    # Balance of the PV energy
    @constraint(M, PV_prod_bal[t in T, y in Y, h in H, s in S], M[:p_PV][t,y,h,s] == M[:p_PV_ev][t,y,h,s] + M[:p_PV_bat][t,y,h,s] + M[:p_PV_ex][t,y,h,s] + M[:p_PV_load][t,y,h,s])

    # Definition of the EV charging limit taking into accout availability
    @constraint(M, EV_charge_lim[t in T, y in Y, h in H, s in S], M[:ev_ch][t,y,h,s] <=  EV_avail[(t,y,h,s)] * EV_par["Charging_lim"] * M[:C_EV][h,s])

    # Definition of the EV discharging limit taking into accout availability
    @constraint(M, EV_discharge_lim[t in T, y in Y, h in H, s in S], M[:ev_dh][t,y,h,s] <=  EV_avail[(t,y,h,s)] * EV_par["Discharging_lim"] * M[:C_EV][h,s])

    # Definition of the EV discharging limit taking into accout availability
    @constraint(M, EV_SOC_goal_cons[t in T, y in Y, h in H, s in S], M[:ev_st][t,y,h,s] >=  EV_SOC_goal[(t,y,h,s)])

    # SOC regular balance when the hours set is not 1
    @constraint(M, SOC_EV[t in T, y in Y, h in H, s in S; t>1], M[:ev_st][t,y,h,s] == M[:ev_st][t-1,y,h,s] - M[:ev_dh][t,y,h,s]/EV_par["Discharging_eff"] + M[:ev_ch][t,y,h,s]*EV_par["Charging_eff"] - EV_demand[(t,y,h,s)])

    # SOC balance for the first hour and NOT first year
    @constraint(M, SOC_LastT_EV[t in T, y in Y, h in H, s in S; t == 1 && y!=1], M[:ev_st][t,y,h,s] == M[:ev_st][last(T),y-1,h,s] - M[:ev_dh][t,y,h,s]/EV_par["Discharging_eff"] + M[:ev_ch][t,y,h,s]*EV_par["Charging_eff"] - EV_demand[(t,y,h,s)])

    # SOC balance for the first hour and first year
    @constraint(M, SOC_First_EV[t in T, y in Y, h in H, s in S; t==1 && y==1], M[:ev_st][t,y,h,s] == M[:C_EV][h,s] - M[:ev_dh][t,y,h,s]/EV_par["Discharging_eff"] + M[:ev_ch][t,y,h,s]*EV_par["Charging_eff"]  - EV_demand[(t,y,h,s)])

    # Limit on the maximum charge state of charge of the battery
    @constraint(M, SOC_lim_up_EV[t in T, y in Y, h in H, s in S], M[:ev_st][t,y,h,s] <= EV_par["Max_charge"]*M[:C_EV][h,s])

    # Limit on the minimum battery state of charge
    @constraint(M, SOC_lim_down_EV[t in T, y in Y, h in H, s in S], M[:ev_st][t,y,h,s] >= EV_par["Min_charge"]*M[:C_EV][h,s])

    # Balance of the charging energy in EV
    @constraint(M, ev_ch_def[t in T, y in Y, h in H, s in S], M[:ev_ch][t,y,h,s] == M[:p_PV_ev][t,y,h,s] + M[:g_im_ev][t,y,h,s] + M[:b_dh_ev][t,y,h,s])

    # Balance of the discharging energy in EV
    @constraint(M, ev_dh_def[t in T, y in Y, h in H, s in S], M[:ev_dh][t,y,h,s] == M[:ev_dh_ex][t,y,h,s] + M[:ev_dh_load][t,y,h,s])

    return M
end


# -------------------------------------------------------------------------------------------------------------------
#                                       EXPORTING THE RESULTS FUNCTION
# -------------------------------------------------------------------------------------------------------------------

function create_var_dict(M)
    str(x) = string(x) # Getting string function
    spl(x) = split(x, ",") # Spliting with comma function
    var_str = str.(all_variables(M)) #Getting the string of all variables in a model
    sets_str = (s -> SubString(s, nextind(s, findfirst(":[", s)[1]+1), prevind(s, findlast(']', s)))).(var_str) # Obtaining the sets string
    var_name_str = (s -> SubString(s, 1, prevind(s, findfirst('[', s)))).(var_str) # Obtaining the name of variables
    uniq_var_names = unique(var_name_str) # Obtaining unique names of variables
    Variable_dict = Dict{Symbol,DataFrame}()
    for un in uniq_var_names # Looping over variables
        Bool = var_name_str .== un # Boolean value to filter total vectors
        Names = unique([split(el, ",") for el in (s -> SubString(s, nextind(s, findfirst('[', s)), prevind(s, findfirst(']', s)))).(var_str[Bool])])[1] # Getting the names of the sets for particular variable
        Sets_str_spl = [split(el, ",") for el in sets_str[Bool]] # Split sets of filtered vector with comma
        df = DataFrame([Any for i in 1:length(Names)],[Symbol(s) for s in Names], sum(Bool)) # Create empty dataframe
        df[:,:] = permutedims(reshape(vcat(Sets_str_spl...), length(Names), sum(Bool))) # Pass sets values
        df[!,:Value] = value.(all_variables(M))[Bool] # Pass values
        Variable_dict[Symbol(un)] = df # Pass dataframe to dictionary
    end
    return Variable_dict
end

# -------------------------------------------------------------------------------------------------------------------
#                                       RUNNING THE MODEL
# -------------------------------------------------------------------------------------------------------------------
# Importing data
ModelDataImport()
# Initializng the model and variables
M = InitializeModel()
# Calculating the parameters
Demand, EV_avail, EV_demand, EV_SOC_goal =CalculatingParameters(30, 30*0.7)
# Fixing the capacities of PV, Battery and EV
FixingCap(M, 10, 10, 30)
# Fixing the capacities
M = DefineConstraints(M, "base")
# Optimizing!
optimize!(M)
# Exporting the results
# ExportResults(M, "Results.xlsx")

Results_Dict = create_var_dict(M)
