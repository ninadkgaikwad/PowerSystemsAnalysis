# Ybus_Builder.jl

"""
    Create_Ybus_WithoutTaps(CDF_DF_List)

Creates Ybus without taps for a power system network.

'''
# Arguments
- 'CDF_DF_List_pu': IEEE CDF file in List of Dataframe format according to
Data Card types in IEEE CDF file : [TitleCard_DF, BusDataCard_DF,
BranchDataCard_DF, LossZonesCard_DF, InterchangeDataCard_DF,
TieLinesDataCard_DF].
'''
'''
# Output
- 'Ybus_WithoutTaps': A complex array of Ybus elements ordered according to bus
type: Slack->PQ->PV.
'''
"""
function Create_Ybus_WithoutTaps(CDF_DF_List_pu)

    # Getting required data from CDF_DF_List
    BusDataCard_DF = CDF_DF_List_pu[2]
    BranchDataCard_DF = CDF_DF_List_pu[3]

    # Getting Size of Ybus
    Size_Ybus = length(BusDataCard_DF.Bus_Num)

    # Initializing Ybus Complex Array
    Ybus_WithoutTaps = Array{Complex{Float64}}(undef, Size_Ybus,Size_Ybus)

    # Computing Ybus Off-Diagonal elements
    for ii in 1:Size_Ybus # Through Rows


        for jj in 1:1:Size_Ybus # Through Columns

            if (ii == jj) # Diagonal Element

                continue

            elseif (ii < jj) # Off-Diagonal elements upper triangle

                # Getting currentBus Numbers from BusDataCard_DF
                Bus1_Num = BusDataCard_DF.Bus_Num[ii]

                Bus2_Num = BusDataCard_DF.Bus_Num[jj]

                # Finding Row in BranchDataCard_DF based on current Bus Numbers
                BranchDataCard_FilterRow = filter(row -> ((row.Tap_Bus_Num == Bus1_Num) && (row.Z_Bus_Num == Bus2_Num)) || ((row.Tap_Bus_Num == Bus2_Num) && (row.Z_Bus_Num == Bus1_Num)), BranchDataCard_DF)

                BranchDataCard_FilterRow_Num = nrow(BranchDataCard_FilterRow)

                if (BranchDataCard_FilterRow_Num == 0) # There is no connection between buses

                    # Filling up Branch Admittance in Ybus_WithoutTaps
                    Ybus_WithoutTaps[ii,jj] = complex(0,0)

                    # Ybus is Symmetrical
                    Ybus_WithoutTaps[jj,ii] = Ybus_WithoutTaps[ii,jj]

                elseif (BranchDataCard_FilterRow_Num > 0) # There is connection between buses

                    # Creating Line Series Admittance
                    Line_SeriesAdmittance = 1/complex(BranchDataCard_FilterRow.R_pu[1],BranchDataCard_FilterRow.X_pu[1])

                    # Filling up Branch Admittance in Ybus_WithoutTaps
                    Ybus_WithoutTaps[ii,jj] = -Line_SeriesAdmittance

                    # Ybus is Symmetrical
                    Ybus_WithoutTaps[jj,ii] = Ybus_WithoutTaps[ii,jj]

                end


            else # Off-Diagonal elements lower triangle

                continue

            end

        end

    end

    # Computing Ybus Diagonal elements
    for ii in 1:Size_Ybus # Through Diagonal Elements Row-wise

        # Getting effect of Off-Diagonal Terms
        OffDiagonal_Terms = 0

        for jj = 1:Size_Ybus # Thorough Columns

            if (ii == jj) # Diagonal Term

                continue

            else

                OffDiagonal_Terms = OffDiagonal_Terms + (-Ybus_WithoutTaps[ii,jj])

            end

        end

        # Getting Effect of Bus Shunt Admittance
        BusAdmittance_Shunt = complex(BusDataCard_DF.G_pu[ii],-BusDataCard_DF.B_pu[ii])

        # Getting Effect of Line Shunt Admittance connected to the Bus
        BusLineAdmittance_Shunt = 0

        Bus_Num = BusDataCard_DF.Bus_Num[ii]

        BranchDataCard_Filter = filter(row -> (row.Tap_Bus_Num == Bus_Num) || (row.Z_Bus_Num == Bus_Num), BranchDataCard_DF)

        BranchDataCard_Filter_Num = nrow(BranchDataCard_Filter)

        if (BranchDataCard_Filter_Num == 0) # Bus not connected to any other bus through a transmission line

            BusLineAdmittance_Shunt = 0

        elseif (BranchDataCard_Filter_Num > 0) # Bus connected to other buses through a transmission lines

            for kk in 1:length(BranchDataCard_Filter.Tap_Bus_Num)

                BusLineAdmittance_Shunt = BusLineAdmittance_Shunt + complex(0,-(BranchDataCard_Filter.B_pu[kk]/2))

            end

        end

        # Total effect oin Ybus Diagonal term
        Ybus_WithoutTaps[ii,ii] = OffDiagonal_Terms + BusAdmittance_Shunt + BusLineAdmittance_Shunt

    end

    # Rearranging Create_Ybus_WithoutTaps in the order Slack->PQ->PV
    Ybus_WithoutTaps_PQ_PV = Ybus_WithoutTaps[1:end-1,1:end-1]

    Ybus_WithoutTaps_Slack1 = Ybus_WithoutTaps[1:end-1,end]

    Ybus_WithoutTaps_Slack2 = Ybus_WithoutTaps[end,1:end-1]

    Ybus_WithoutTaps_Slack3 = Ybus_WithoutTaps[end,end]

    Ybus_WithoutTaps_1 = vcat(reshape(Ybus_WithoutTaps_Slack2,(1,length(Ybus_WithoutTaps_Slack2))),Ybus_WithoutTaps_PQ_PV)

    Ybus_WithoutTaps_2 = vcat(Ybus_WithoutTaps_Slack3,Ybus_WithoutTaps_Slack1)

    Ybus_WithoutTaps = hcat(Ybus_WithoutTaps_2,Ybus_WithoutTaps_1)

    # Addressing Machine Precision Problem
    for ii in 1:size(Ybus_WithoutTaps)[1]

        for jj in 1:size(Ybus_WithoutTaps)[2]

            if (abs(Ybus_WithoutTaps[ii,jj]) < 1e-12)

                Ybus_WithoutTaps[ii,jj] = 0

            end

        end

    end    

    return Ybus_WithoutTaps


end

"""
    Create_Ybus_WithTaps(CDF_DF_List)

Creates Ybus with taps for a power system network.

'''
# Arguments
- 'Ybus_WithoutTaps': A complex array of Ybus elements ordered according to bus
type: Slack->PQ->PV.
- 'CDF_DF_List_pu': IEEE CDF file in List of Dataframe format according to
Data Card types in IEEE CDF file : [BusDataCard_DF, BranchDataCard_DF,
LossZonesCard_DF, InterchangeDataCard_DF, TieLinesDataCard_DF].
'''
'''
# Output
- 'Ybus_WithTaps': A complex array of Ybus elements ordered according to bus
type: Slack->PV->PQ.
'''
"""
function Create_Ybus_WithTaps(Ybus_WithoutTaps,CDF_DF_List_pu)

    # Getting required data from CDF_DF_List
    BusDataCard_DF = CDF_DF_List_pu[2]

    BranchDataCard_DF = CDF_DF_List_pu[3]

    # Getting Last Row number of BusDataCard_DF to locate Slack Bus Row number
    SlackBus_RowNumber = length(BusDataCard_DF.Bus_Num)

    # Initializing Ybus_WithTaps
    Ybus_WithTaps = copy(Ybus_WithoutTaps)

    # Getting Subset of BranchDataCard_DFfor lines with Tap Changing Transformers
    BranchDataCard_Filter = filter(row -> ((row.Transformer_t != 0) || (row.Transformer_ps != 0)), BranchDataCard_DF)

    BranchDataCard_Filter_Num = nrow(BranchDataCard_Filter)

    if (BranchDataCard_Filter_Num == 0) # No Tap Changing Transformers present

        Ybus_WithTaps = Ybus_WithoutTaps

    elseif (BranchDataCard_Filter_Num > 0) # Tap Changing Transformers present

        for ii in 1:BranchDataCard_Filter_Num

            # Creating Tap value 'a'
            a = BranchDataCard_Filter.Transformer_t[ii] * cis(deg2rad(BranchDataCard_Filter.Transformer_ps[ii]))

            # Getting Bus Numbers 'i': Z_Bus_Num (Impedance Side) , 'j': Tap_Bus_Num (non-unity tap Side)
            Bus_Num_i = BranchDataCard_Filter.Z_Bus_Num[ii]

            Bus_Num_j = BranchDataCard_Filter.Tap_Bus_Num[ii]

            # Getting associated 'Bus_i_Index' and 'Bus_j_Index' from BusDataCard_DF to access correct location within Ybus_WithoutTaps
            for jj in 1:SlackBus_RowNumber

                if (Bus_Num_i == BusDataCard_DF.Bus_Num[jj])

                    if (jj == SlackBus_RowNumber)

                        Bus_i_Index = 1

                    else

                        Bus_i_Index = jj+1

                    end

                elseif (Bus_Num_j == BusDataCard_DF.Bus_Num[jj])

                    if (jj == SlackBus_RowNumber)

                        Bus_j_Index = 1

                    else

                        Bus_j_Index = jj+1

                    end

                else

                    continue

                end

            end

            # For a weird undeferror
            Bus_i_Index = Bus_i_Index
            Bus_j_Index = Bus_j_Index

            # Changing the [Bus_i_Index, Bus_j_Index] in Ybus_WithTaps based on 'a'

            # Changing [Bus_i_Index, Bus_i_Index]
            Ybus_WithTaps[Bus_i_Index, Bus_i_Index] = Ybus_WithoutTaps[Bus_i_Index, Bus_i_Index]

            # Changing [Bus_i_Index, Bus_j_Index]
            Ybus_WithTaps[Bus_i_Index, Bus_j_Index] = Ybus_WithoutTaps[Bus_i_Index, Bus_j_Index]/a

            # Changing [Bus_j_Index, Bus_i_Index]
            Ybus_WithTaps[Bus_j_Index, Bus_i_Index] = Ybus_WithoutTaps[Bus_j_Index, Bus_i_Index]/conj(a)

            # Changing [Bus_j_Index, Bus_j_Index]
            Ybus_WithTaps[Bus_j_Index, Bus_j_Index] = (Ybus_WithoutTaps[Bus_j_Index, Bus_j_Index]) - (-Ybus_WithoutTaps[Bus_j_Index, Bus_i_Index]) + (-Ybus_WithoutTaps[Bus_j_Index, Bus_i_Index]/abs2(a))

        end

    end

    # Addressing Machine Precision Problem
    for ii in 1:size(Ybus_WithTaps)[1]

        for jj in 1:size(Ybus_WithTaps)[2]

            if (abs(Ybus_WithTaps[ii,jj]) < 1e-12)

                Ybus_WithTaps[ii,jj] = 0

            end

        end

    end 

    return Ybus_WithTaps

end

"""
sortMatrixByBusTypes

This function sorts the given `ybus` matrix and row names based on bus types using the `initializeVectors_pu` function.

# Parameters
- `CDF_DF_List_pu`: A list containing the data for power system buses in the per unit (pu) system. It should be a two-dimensional array-like object where each row represents a bus and each column represents a specific attribute of the bus.
- `ybus`: The admittance matrix of the power system.

# Returns
- `ybusByTypes`: The sorted admittance matrix `ybus` based on bus types.
- `rowNamesByTypes`: The sorted row names corresponding to `ybusByTypes`.

# Description
The `sortMatrixByBusTypes` function uses the `initializeVectors_pu` function to obtain the lists of slack buses, PV buses, and PQ buses. It then combines these lists into a new order, which represents the desired sorting order of buses in the `ybus` matrix.

The function creates a new `ybusByTypes` matrix by reordering the rows and columns of `ybus` according to the new order of bus types. The `rowNamesByTypes` is also updated to match the new order of bus types.

Finally, the sorted `ybusByTypes` matrix and `rowNamesByTypes` are returned as the output of the function.

Please note that the `initializeVectors_pu` function is assumed to be defined and implemented separately.
"""
function sortMatrixByBusTypes(CDF_DF_List_pu, ybus)
    # Call initializeVectors_pu to obtain bus type information
    outputs  = initializeVectors_pu(CDF_DF_List_pu)
    listOfSlackBuses, listOfPVBuses, listOfPQBuses = outputs[5], outputs[6], outputs[7]
    # Create a new order based on bus types
    newOrder = vcat(listOfSlackBuses, listOfPVBuses, listOfPQBuses)
    # Reorder the ybus matrix and row names according to the new order
    ybusByTypes = ybus[newOrder, newOrder]

    rowNamesByTypes = [string(i) for i in newOrder]

    return ybusByTypes, rowNamesByTypes
end

"""
    ybusGenerator(CDF_DF_List_pu::Vector{DataFrame};
                disableTaps::Bool=false, sortBy::String="busNumbers",
                verbose::Bool=false, saveTables::Bool=false,
                saveLocation::String="processedData/")

Generates the Y-bus matrix, B-matrix, and other related matrices for a power system.

# Arguments:
- `CDF_DF_List_pu`: A vector of DataFrames where the second element contains the bus data and the third element contains the branch data in per unit.
- `disableTaps`: A boolean indicating whether transformer tap ratios should be ignored. Default is `false`.
- `sortBy`: A string which specifies how to sort the matrices. Can be "busNumbers" (default) or "busTypes".
- `verbose`: A boolean that indicates whether to print the results to the console. Default is `false`.
- `saveTables`: A boolean that indicates whether to save the results as CSV files. Default is `false`.
- `saveLocation`: A string that specifies the directory where CSV files will be saved. Default is "processedData/".

# Returns:
- A named tuple containing:
    - `ybus`: The Y-bus matrix
    - `BMatrix`: The B-matrix
    - `b`: A matrix related to branch impedances
    - `A`: The incidence matrix
    - `branchNames`: A vector of strings representing branch names
    - `E`: An adjacency list representation of the system topology

# Notes:
The function processes the given data, constructs the Y-bus matrix, and can optionally print the results and save them as CSV files.
It also provides sorting functionality to sort the matrices by either bus numbers or bus types.

# Example:
```julia
results = ybusGenerator(data, disableTaps=true, verbose=true)
"""
function ybusGenerator(CDF_DF_List_pu::Vector{DataFrame};
    disableTaps::Bool = false,
    sortBy::String = "busNumbers",
    verbose::Bool = false,
    saveTables::Bool = false,
    saveLocation::String = "processedData/")

    systemName = extractSystemName(CDF_DF_List_pu)
    busData_pu = CDF_DF_List_pu[2]
    branchData_pu = CDF_DF_List_pu[3]
    N = size(busData_pu, 1)
    numBranch = size(branchData_pu, 1)

    ybus = zeros(ComplexF64, N, N)
    BMatrix = zeros(ComplexF64, N, N)
    E = Array{Vector{Int64}}(undef, N)
    b = zeros(Float64, numBranch, numBranch)

    for i in 1:N
        E[i] = Vector{Int64}()
    end
    A = zeros(Float64, numBranch, N)
    branchNames = Vector{String}(undef, numBranch)

    for branch = 1:numBranch
        currentBranch = branchData_pu[branch, :]
        # vscodedisplay(currentBranch)
        i = currentBranch.Tap_Bus_Num
        k = currentBranch.Z_Bus_Num
        branchNames[branch] = "$(i) to $(k)"
        A[branch, i] = 1
        A[branch, k] = -1
        b[branch, branch] = 1/currentBranch.X_pu

        if disableTaps
            a = 1
        elseif currentBranch.Transformer_t != 0
            a = currentBranch.Transformer_t
        else
            a = 1
        end

        y_ik = 1/(currentBranch.R_pu + im*currentBranch.X_pu)
        ybus[i, i] += y_ik/(a^2) + im*currentBranch.B_pu / 2
        ybus[k, k] += y_ik + im*currentBranch.B_pu / 2
        ybus[i, k] += -y_ik/a
        ybus[k, i] += -y_ik/a

        push!(E[i], k)
        push!(E[k], i)
    end

    for bus = 1:N
        ybus[bus, bus] += busData_pu.G_pu[bus] + im*busData_pu.B_pu[bus]
        push!(E[bus], bus)
    end

    BMatrix = -imag(ybus)
    # Sort Y-bus matrix
    if sortBy == "busNumbers"
        rowNames = [string(i) for i in 1:N]
        #might wanna change the names to be Gen01, Gen02, ... , Gen14.
        tag = ""
    elseif sortBy == "busTypes"
        ybusByTypes, rowNamesByTypes = sortMatrixByBusTypes(CDF_DF_List_pu, ybus)
        ybus = ybusByTypes
        rowNames  = rowNamesByTypes
        BMatrixByTypes, rowNamesByTypes = sortMatrixByBusTypes(CDF_DF_List_pu, BMatrix)
        BMatrix = BMatrixByTypes
        tag = "_sortedByBusTypes"
    end

    ybusTable = DataFrame(ybus, Symbol.(rowNames))
    BMatrixTable = DataFrame(BMatrix, Symbol.(rowNames))

    if verbose
        println("Y-bus Matrix:")
        show(stdout, "text/plain", ybus)
        println("\nB-Matrix:")
        show(stdout, "text/plain", BMatrix)
        println("\nBranch Names:")
        show(stdout, "text/plain", branchNames)
        println("\nA-Matrix:")
        show(stdout, "text/plain", A)
        println("\nb-Matrix:")
        show(stdout, "text/plain", b)
        println("\nE (Adjacency list):")
        show(stdout, "text/plain", E)
    end

    if saveTables
        fileType = ".csv"
        filenameYBus = "$saveLocation$systemName/YBus$tag$fileType"
        filenameBMatrix = "$saveLocation$systemName/BMatrix$tag$fileType"
        CSV.write(filenameYBus, ybusTable)
        CSV.write(filenameBMatrix, BMatrixTable)
    end

    return (ybus=ybus, BMatrix=BMatrix, b=b, A=A, branchNames=branchNames, E=E)

end


