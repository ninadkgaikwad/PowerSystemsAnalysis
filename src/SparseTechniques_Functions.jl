# SparseTechniquesInPowerSystems.jl

using SparseArrays
using DataFrames

include("Helper_Functions.jl")

"""
nnzRowConstructor(compElem::DataFrameRow)

The `nnzRowConstructor` function constructs a single row of the `nnz` DataFrame. It initializes the row with information extracted from the `compElem` DataFrameRow.

Arguments:
- `compElem::DataFrameRow`: A DataFrameRow containing the information to initialize the `nnz` DataFrame row.

Returns:
- A DataFrameRow representing a single row of the `nnz` DataFrame, initialized with the appropriate values extracted from `compElem`.

Example:
```julia
compElem = DataFrame(ID = 1, Val = 0.5, i = 2, j = 3)
nnzRow = nnzRowConstructor(compElem)
println(nnzRow.ID)    # -1
println(nnzRow.Val)   # 0.5
println(nnzRow.NROW)  # 2
println(nnzRow.NCOL)  # 3
println(nnzRow.NIR)   # -1
println(nnzRow.NIC)   # -1
"""
function nnzRowConstructor(compElem::DataFrameRow)
	nnzElem = DataFrame(ID = -1, Val = compElem.Val, NROW = compElem.i, NCOL = compElem.j, NIR = -1, NIC = -1)
	return first(nnzElem) # Otherwise, Julia will interpret it as a DataFrame and NOT a DataFrameRow
	# The reason we want a DataFrameRow is that when we invoke nnzElem.NROW, it extracts the inner element, instead of a 1-vector
end

"""
sparmat(compMatrix::DataFrame; verbose::Bool = false)

The `sparmat` function creates two DataFrames, `NVec` and `nnzVec`, which together represent a sparse matrix. It iterates over the `compMatrix` DataFrame, constructs `nnzVec` rows using the `nnzRowConstructor` function, and updates `NVec` and `nnzVec` accordingly.

Arguments:
- `compMatrix::DataFrame`: The DataFrame containing the compressed matrix information.
- `verbose::Bool`: (optional) A Boolean value indicating whether to display verbose output during the construction process. Default is `false`.

Returns:
- A tuple `(NVec, nnzVec)` representing the two DataFrames `NVec` and `nnzVec` that represent the sparse matrix.

Example:
```julia
compMatrix = DataFrame(ID = [1, 2, 3], Val = [0.5, 0.3, 0.8], i = [2, 1, 3], j = [3, 2, 1])
NVec, nnzVec = sparmat(compMatrix, verbose = true)
"""
function sparmat(compMatrix::DataFrame;
	verbose::Bool = false)

	N = maximum([compMatrix.i compMatrix.j])
	(firs, fics) = (repeat([-1], N), repeat([-1], N))

	NVec = DataFrame(FIR = firs, FIC = fics)
	nnzVec = DataFrame(ID = Int64[], Val = ComplexF64[], NROW = Int64[], NCOL = Int64[], NIR = Int64[], NIC = Int64[])

	numElems = size(compMatrix, 1)
	
	for elemNum in 1:numElems
		compElem = compMatrix[elemNum, :]

		nnzElem = nnzRowConstructor(compElem)

		NVec, nnzVec = updateSparse(NVec, nnzVec, nnzElem, type="replace", verbose=verbose)
	end

	return NVec, nnzVec
end

"""
    resolveTie(nnzVec::DataFrame, incumbentID::Int64, elVal::ComplexF64; type="replace", verbose=false)

Resolves a tie between an incumbent element and a new element by either replacing the incumbent's value or adding the new element's value to it.

## Arguments
- `nnzVec::DataFrame`: The DataFrame representing the sparse matrix.
- `incumbentID::Int64`: The ID of the incumbent element.
- `elVal::ComplexF64`: The value of the new element.
- `type::String`: (optional) The tie resolution strategy. Valid options are "replace" (default) and "add".
- `verbose::Bool`: (optional) Whether to print verbose output. Default is `false`.

## Returns
The updated `nnzVec` DataFrame after resolving the tie.

# Examples
```julia
nnzVec = DataFrame(ID = 1:5, NROW = [1, 1, 2, 2, 3], NCOL = [1, 2, 1, 2, 1], Val = [1.0, 2.0, 3.0, 4.0, 5.0], NIR = [2, -1, 4, -1, -1], NIC = [-1, -1, -1, -1, -1])
nnzVec = resolveTie(nnzVec, 3, 2.0 + 1.5im, type="add", verbose=true)
"""
function resolveTie(nnzVec::DataFrame, incumbentID::Int64, elVal::ComplexF64;
	type::String = "replace",
	verbose::Bool = false)
	
    if type == "replace"
        nnzVec.Val[incumbentID] = elVal
        myprintln(verbose, "Replacing/Updating the element's previous value with the new elem's value.")
    elseif type == "add"
        nnzVec.Val[incumbentID] += elVal
        myprintln(verbose, "Added the new elem's value to the incumbent's value.")
    else
        error("Not prepared for this scenario.")
    end
    
    return nnzVec
end

"""
    checkElementIntoRow(NVec::DataFrame, nnzVec::DataFrame, nnzElem::DataFrameRow;
                        type::String = "replace", verbose::Bool = false)

Check and insert an element into a row of a sparse matrix.

This function checks if the given `nnzElem` can be inserted into the row specified by `nnzElem.NROW`
in the `nnzVec` DataFrame. If the row is empty, the element is inserted as the first element. If there
is already an element present, the function determines the correct position for the element based on
the `nnzElem.NCOL` value. The position can be before the incumbent element, after it, or it may result
in a tie, which can be resolved using the `resolveTie` function.

## Arguments
- `NVec::DataFrame`: DataFrame containing additional information about the sparse matrix.
- `nnzVec::DataFrame`: DataFrame representing the non-zero elements of the sparse matrix.
- `nnzElem::DataFrameRow`: DataFrameRow representing the new element to be inserted.
- `type::String`: Optional. The type of tie resolution. Default is "replace". Possible values are "replace" and "add".
- `verbose::Bool`: Optional. If set to `true`, print verbose output. Default is `false`.

## Returns
- `NVec::DataFrame`: Updated DataFrame `NVec` with the modified first-in-row information.
- `nnzVec::DataFrame`: Updated DataFrame `nnzVec` with the newly inserted element or resolved tie.
- `nnzElem::DataFrameRow`: Updated DataFrameRow `nnzElem` with the updated element information.
- `updateFlag::Bool`: A flag indicating if the sparse matrix was updated.

## Example
```julia
nnzVec = DataFrame(ID = 1:5, NROW = [1, 1, 2, 2, 3], NCOL = [1, 2, 1, 2, 1], Val = [1.0, 2.0, 3.0, 4.0, 5.0], NIR = [2, -1, 4, -1, -1], NIC = [-1, -1, -1, -1, -1])
nnzElem = DataFrameRow([0, 3, 2, 3, 1], ["ID", "NROW", "NCOL", "Val", "NIR", "NIC"])
NVec, nnzVec, nnzElem, updateFlag = checkElementIntoRow(NVec, nnzVec, nnzElem, type="replace", verbose=true)
"""
function checkElementIntoRow(NVec::DataFrame, nnzVec::DataFrame, nnzElem::DataFrameRow;
	type::String="replace", verbose::Bool=false)
	
	numExistingElems = size(nnzVec, 1)
	myprintln(verbose, "Currently the Sparse Matrix has $numExistingElems elements.")
	nnzElem.ID = numExistingElems + 1
	elID = nnzElem.ID
	FIR = NVec.FIR
	row = nnzElem.NROW
	col = nnzElem.NCOL
	elVal = nnzElem.Val

	updateFlag = false
    stillFindingAPlaceInRow = true

    # Check if our elem is the very first element to be inserted for that row
    if FIR[row] == -1 # First element to be inserted into that row
        myprintln(verbose, "This elem is the first in row $row !")
        FIR[row] = elID
        stillFindingAPlaceInRow = false
    else
        incumbentID = FIR[row]
        myprintln(verbose, "Row $row already has an element, with ID: $incumbentID")
        incumbent = nnzVec[incumbentID, :]
    end

    # If there exists at least one element (the incumbent) already present in the row,
    # check if our elem can come before it.
    if stillFindingAPlaceInRow
        if col < incumbent.NCOL # New elem comes before incumbent in that row => replace it in FIR and shift incumbent in the nnzVec
            myprintln(verbose, "Our elem comes before element $incumbentID, can topple it!")
            FIR[row] = elID
            nnzElem.NIR = incumbentID
            stillFindingAPlaceInRow = false
        elseif col == incumbent.NCOL
            myprintln(verbose, "Stand down. It's a draw between our elem and element $incumbentID.")
            nnzVec = resolveTie(nnzVec, incumbentID, elVal, type=type, verbose=verbose)
            updateFlag = true
            stillFindingAPlaceInRow = false
        else
            myprintln(verbose, "Our elem will come after the incumbent element $incumbentID. Continue Searching.")
            prevIncumbentID = incumbentID
            incumbentID = incumbent.NIR # going to the next element in the row
        end
    end

    # If there is no change to the FIR,
    # Keep checking until our elem finds its place in that row.
    while stillFindingAPlaceInRow
        if incumbentID == -1 # elem is the last in the row
            myprintln(verbose, "Our elem will sit right after the FIR element $prevIncumbentID !")
            nnzVec.NIR[prevIncumbentID] = elID
            stillFindingAPlaceInRow = false
        else # more elements to check in the row
            incumbent = nnzVec[incumbentID, :]
            myprintln(verbose, "Not the second element to be added to this row either. Keep searching.")
        end

        if stillFindingAPlaceInRow
            if col < incumbent.NCOL
                myprintln(verbose, "Our element can topple the incumbent element $incumbentID.")
                nnzElem.NIR = incumbentID
                nnzVec.NIR[prevIncumbentID] = elID
                stillFindingAPlaceInRow = false
            elseif col == incumbent.NCOL # Same-same? Either replace or add
                myprintln(verbose, "Stand down. It's a draw between our elem and element $incumbentID.")
                nnzVec = resolveTie(nnzVec, incumbentID, elVal, type=type, verbose=verbose)
                updateFlag = true
                stillFindingAPlaceInRow = false
            else # col > incumbent.NCOL
                myprintln(verbose, "Not coming before incumbent element $incumbentID. Keep searching.")
                prevIncumbentID = incumbentID
                incumbentID = incumbent.NIR
            end
        end
    end

	NVec.FIR = FIR
	return NVec, nnzVec, nnzElem, updateFlag
end

"""
    checkElementIntoColumn(NVec::DataFrame, nnzVec::DataFrame, nnzElem::DataFrameRow;
    type::String = "replace", verbose::Bool = false)

Check and insert an element into a column of a sparse matrix.

This function is analogous to the `checkElementIntoRow` function and serves the same purpose,
but it operates on columns instead of rows. It checks if the given `nnzElem` can be inserted
into the column specified by `nnzElem.NCOL` in the `nnzVec` DataFrame. If the column is empty,
the element is inserted as the first element. If there is already an element present, the function
determines the correct position for the element based on the `nnzElem.NROW` value. The position
can be before the incumbent element, after it, or it may result in a tie, which can be resolved
using the `resolveTie` function.

## Arguments
- `NVec::DataFrame`: DataFrame containing additional information about the sparse matrix.
- `nnzVec::DataFrame`: DataFrame representing the non-zero elements of the sparse matrix.
- `nnzElem::DataFrameRow`: DataFrameRow representing the new element to be inserted.
- `type::String`: Optional. The type of tie resolution. Default is "replace". Possible values are "replace" and "add".
- `verbose::Bool`: Optional. If set to `true`, print verbose output. Default is `false`.

## Returns
- `NVec::DataFrame`: Updated DataFrame `NVec` with the modified first-in-column information.
- `nnzVec::DataFrame`: Updated DataFrame `nnzVec` with the newly inserted element or resolved tie.
- `nnzElem::DataFrameRow`: Updated DataFrameRow `nnzElem` with the updated element information.
- `updateFlag::Bool`: A flag indicating if the sparse matrix was updated.

## Example
```julia
nnzVec = DataFrame(ID = 1:5, NROW = [1, 1, 2, 2, 3], NCOL = [1, 2, 1, 2, 1], Val = [1.0, 2.0, 3.0, 4.0, 5.0], NIR = [2, -1, 4, -1, -1], NIC = [-1, -1, -1, -1, -1])
nnzElem = DataFrameRow([0, 3, 2, 3, 1], ["ID", "NROW", "NCOL", "Val", "NIR", "NIC"])
NVec, nnzVec, nnzElem, updateFlag = checkElementIntoColumn(NVec, nnzVec, nnzElem, type="replace", verbose=true)
"""
function checkElementIntoColumn(NVec::DataFrame, nnzVec::DataFrame, nnzElem::DataFrameRow;
	type::String="replace", verbose::Bool=false)
	
	numExistingElems = size(nnzVec, 1)
	myprintln(verbose, "Currently the Sparse Matrix has $numExistingElems elements.")
	nnzElem.ID = numExistingElems + 1
	elID = nnzElem.ID
	FIC = NVec.FIC
	row = nnzElem.NROW
	col = nnzElem.NCOL
	elVal = nnzElem.Val

	updateFlag = false
    stillFindingAPlaceInColumn = true

    # Check if our elem is the very first element to be inserted for that column
    if FIC[col] == -1 # First element to be inserted into that column
        myprintln(verbose, "This elem is the first in column $col !")
        FIC[col] = elID
        stillFindingAPlaceInColumn = false
    else
        incumbentID = FIC[col]
        myprintln(verbose, "Column $col already has an element, with ID: $incumbentID")
        incumbent = nnzVec[incumbentID, :]
    end

    # If there exists at least one element (the incumbent) already present in the column,
    # check if our elem can come before it.
    if stillFindingAPlaceInColumn
        if row < incumbent.NROW # New elem comes before incumbent in that column => replace it in FIC and shift incumbent in the nnzVec
            myprintln(verbose, "Our elem comes before element $incumbentID, can topple it!")
            FIC[col] = elID
            nnzElem.NIC = incumbentID
            stillFindingAPlaceInColumn = false
        elseif row == incumbent.NROW
            myprintln(verbose, "Stand down. It's a draw between our elem and element $incumbentID.")
            nnzVec = resolveTie(nnzVec, incumbentID, elVal, type=type, verbose=verbose)
            updateFlag = true
            stillFindingAPlaceInColumn = false
        else
            myprintln(verbose, "Our elem will come after the incumbent element $incumbentID. Continue Searching.")
            prevIncumbentID = incumbentID
            incumbentID = incumbent.NIC # going to the next element in the column
        end
    end

    # If there is no change to the FIC,
    # Keep checking until our elem finds its place in that column.
    while stillFindingAPlaceInColumn
        if incumbentID == -1 # elem is the last in the column
            myprintln(verbose, "Our elem will sit right after the FIC element $prevIncumbentID !")
            nnzVec.NIC[prevIncumbentID] = elID
            stillFindingAPlaceInColumn = false
        else # more elements to check in the column
            incumbent = nnzVec[incumbentID, :]
            myprintln(verbose, "Not the second element to be added to this column either. Keep searching.")
        end

        if stillFindingAPlaceInColumn
            if row < incumbent.NROW
                myprintln(verbose, "Our element can topple the incumbent element $incumbentID.")
                nnzElem.NIC = incumbentID
                nnzVec.NIC[prevIncumbentID] = elID
                stillFindingAPlaceInColumn = false
            elseif row == incumbent.NROW # Same-same? Either replace or add
                myprintln(verbose, "Stand down. It's a draw between our elem and element $incumbentID.")
                nnzVec = resolveTie(nnzVec, incumbentID, elVal, type=type, verbose=verbose)
                updateFlag = true
                stillFindingAPlaceInColumn = false
            else # row > incumbent.NROW
                myprintln(verbose, "Not coming before incumbent element $incumbentID. Keep searching.")
                prevIncumbentID = incumbentID
                incumbentID = incumbent.NIC
            end
        end
    end

	NVec.FIC = FIC
	return NVec, nnzVec, nnzElem, updateFlag
end

"""
    updateSparse(NVec::DataFrame, nnzVec::DataFrame, nnzElem::DataFrameRow;
    type::String = "replace", verbose::Bool = false)

Update a sparse matrix by inserting a new element.

This function updates the sparse matrix represented by `nnzVec` and additional information
in `NVec` by inserting a new element specified by the `nnzElem` DataFrameRow. The element is
inserted by calling the `checkElementIntoRow` and `checkElementIntoColumn` functions, which
determine the correct position for the element based on its row and column indices.

If the specified position for the new element is already occupied by a previous "incumbent"
element, the `type` argument determines how the tie is resolved. If `type` is set to "replace",
the new element's value replaces the incumbent element's value. If `type` is set to "add",
the new element's value is added to the incumbent element's value.

## Arguments
- `NVec::DataFrame`: DataFrame containing additional information about the sparse matrix.
- `nnzVec::DataFrame`: DataFrame representing the non-zero elements of the sparse matrix.
- `nnzElem::DataFrameRow`: DataFrameRow representing the new element to be inserted.
- `type::String`: Optional. The type of tie resolution. Default is "replace". Possible values are "replace" and "add".
- `verbose::Bool`: Optional. If set to `true`, print verbose output. Default is `false`.

## Returns
- `NVec::DataFrame`: Updated DataFrame `NVec` with the modified first-in-row and first-in-column information.
- `nnzVec::DataFrame`: Updated DataFrame `nnzVec` with the newly inserted element or resolved tie.

## Example
```julia
NVec = DataFrame(FIR = [-1, -1, -1], FIC = [-1, -1, -1])
nnzVec = DataFrame(ID = 1:5, NROW = [1, 1, 2, 2, 3], NCOL = [1, 2, 1, 2, 1], Val = [1.0, 2.0, 3.0, 4.0, 5.0], NIR = [2, -1, 4, -1, -1], NIC = [-1, -1, -1, -1, -1])
nnzElem = DataFrameRow([0, 3, 2, 3, 1], ["ID", "NROW", "NCOL", "Val", "NIR", "NIC"])
NVec, nnzVec = updateSparse(NVec, nnzVec, nnzElem, type="replace", verbose=true)
"""
function updateSparse(NVec::DataFrame, nnzVec::DataFrame, nnzElem::DataFrameRow;
	type::String = "replace",
	verbose::Bool = false)

	NVec, nnzVec, nnzElem, updateFlag = checkElementIntoRow(NVec, nnzVec, nnzElem, type=type, verbose=verbose)
    NVec, nnzVec, nnzElem, updateFlag = checkElementIntoColumn(NVec, nnzVec, nnzElem, type=type, verbose=verbose)

	if updateFlag == false
		myprintln(verbose, "Another element to be added to the sparse matrix.")
		myprintln(verbose, "The element:")
		myprintln(verbose, nnzElem)
		myprintln(verbose, "nnzVec before:")
		myprintln(verbose, nnzVec)
		push!(nnzVec, nnzElem)
		myprintln(verbose, "nnzVec after:")
		myprintln(verbose, nnzVec)
	else
		myprintln(verbose, "An element was updated, but not added to the sparse matrix.")
	end

	return NVec, nnzVec
end

# values1 = complex.(Float64.(vec([8])), 0)
# rows1 = vec([2]);
# cols1 = vec([2]);
# compMatrix1 = DataFrame(Val = values1, i = rows1, j = cols1);
# NVec1, nnzVec1 = sparmat(compMatrix1, verbose = true)
# vscodedisplay(NVec1)
# vscodedisplay(nnzVec1)

values1 = complex.(Float64.(vec([1 2 3 4 5 6 7 8])), 0);
rows1 = vec([1 2 2 3 2 2 3 1]);
cols1 = vec([2 1 3 2 2 2 1 1]);
compMatrix1 = DataFrame(Val = values1, i = rows1, j = cols1);
NVec1, nnzVec1 = sparmat(compMatrix1, verbose = false)
# vscodedisplay(NVec1)
# vscodedisplay(nnzVec1)

values = vec([-1, -2, 2, 8, 1, 3, -2, -3, 2, 1, 2, -4]);
rows = vec([1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5]);
cols = vec([1, 3, 1, 2, 4, 3, 5, 2, 3, 1, 2, 5]);
compMatrix = DataFrame(Val = values, i = rows, j = cols);

NVec, nnzVec = sparmat(compMatrix, verbose = false)

"""
    compressed2Full(compMatrix::DataFrame)

Converts a compressed matrix representation stored in a DataFrame into a full 
matrix.

## Arguments
- `compMatrix::DataFrame`: A DataFrame representing the compressed matrix. 
It should have three columns: `i`, `j`, and `val`. Column `i` contains the 
row indices, column `j` contains the column indices, and column `val` contains 
the corresponding values.

## Returns
- `fullMatrix::Matrix`: A full matrix representation of the input compressed 
matrix.

## Dependencies
This function requires the following packages to be imported:
- `SparseArrays`: Provides support for sparse matrix operations.
- `DataFrames`: Provides support for working with tabular data in a 
DataFrame format.

## Example
```julia
using SparseArrays
using DataFrames

# Define the compressed matrix
values = vec([-1, -2, 2, 8, 1, 3, -2, -3, 2, 1, 2, -4])
rows = vec([1, 1, 2, 2, 2, 3, 3, 4, 4, 5, 5, 5])
cols = vec([1, 3, 1, 2, 4, 3, 5, 2, 3, 1, 2, 5])
compMatrix = DataFrame(Val = values, i = rows, j = cols)

# Convert the compressed matrix to a full matrix
matFull = compressed2Full(compMatrix)
"""
function compressed2Full(compMatrix::DataFrame)
	# Use SparseArrays's sparse function to conveniently convert the compressed 
	# matrix (i, j, Val) into Compressed Storage Column CSC format
	# I don't care how it does it. 
	# This function is only to be called for testing purposes anyway.
    sparseMatrix = sparse(compMatrix.i, compMatrix.j, compMatrix.Val)
	# Convert the sparse matrix into the full matrix.
    fullMatrix = Matrix(sparseMatrix)
	return fullMatrix
end