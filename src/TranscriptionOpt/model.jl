################################################################################
#                              BASIC MODEL DEFINITION
################################################################################
"""
    TranscriptionData

A DataType for storing the data mapping an [`InfiniteOpt.InfiniteModel`](@ref)
that has been transcribed to a regular [`JuMP.Model`](@ref) that contains the
transcribed variables. This is stored in the `ext` field of a `JuMP.Model` to
make what is called a `TranscriptionModel` via the [`TranscriptionModel`](@ref)
constructor.

**Fields**
- `infvar_lookup::Dict{InfiniteOpt.GeneralVariableRef, Dict{Vector{Float64}, Int}}`:
   A lookup table of infinite variable transcriptions via support value.
- `infvar_mappings::Dict{InfiniteOpt.GeneralVariableRef, Vector{JuMP.VariableRef}}`:
   Map infinite variables to their transcription variables.
- `infvar_supports::Dict{InfiniteOpt.GeneralVariableRef, Vector{Tuple}}`:
   Map infinite variables to their support values.
- `finvar_mappings::Dict{InfiniteOpt.GeneralVariableRef, JuMP.VariableRef}`:
   Map finite variables to their transcription variables.
- `reduced_vars::Vector{InfiniteOpt.ReducedVariable{InfiniteOpt.GeneralVariableRef}}`:
   Store the core reduced variable objects of reduced variables formed on transcription.
- `last_point_index::Int`: The last internal point variable index added.
- `measure_lookup::Dict{InfiniteOpt.GeneralVariableRef, Dict{Vector{Float64}, Int}}`:
   A lookup table of measure transcriptions via support value.
- `measure_mappings::Dict{InfiniteOpt.GeneralVariableRef, Vector{JuMP.AbstractJuMPScalar}}`:
   Map measures to transcription expressions.
- `measure_supports::Dict{InfiniteOpt.GeneralVariableRef, Vector{Tuple}}`:
   Map measures to their supports values (if the transcribed measure is still infinite).
- `constr_mappings::Dict{InfiniteOpt.InfOptConstraintRef, Vector{JuMP.ConstraintRef}}`:
   Map constraints to their transcriptions.
- `constr_supports::Dict{InfiniteOpt.InfOptConstraintRef, Vector{Tuple}}`:
   Map constraints to their support values.
- `verbose_naming::Bool`: Should we name transcription variables/constraints with
   support values?
- `supports::Union{Nothing, Tuple}`: Store the collected parameter supports here.
"""
mutable struct TranscriptionData
    # Variable information
    infvar_lookup::Dict{InfiniteOpt.GeneralVariableRef, Dict{Vector{Float64}, Int}}
    infvar_mappings::Dict{InfiniteOpt.GeneralVariableRef, Vector{JuMP.VariableRef}}
    infvar_supports::Dict{InfiniteOpt.GeneralVariableRef, Vector{Tuple}}
    finvar_mappings::Dict{InfiniteOpt.GeneralVariableRef, JuMP.VariableRef}

    # Internal variables (created via internal measure expansions)
    reduced_vars::Vector{InfiniteOpt.ReducedVariable{InfiniteOpt.GeneralVariableRef}}
    last_point_index::Int

    # Measure information
    measure_lookup::Dict{InfiniteOpt.GeneralVariableRef, Dict{Vector{Float64}, Int}}
    measure_mappings::Dict{InfiniteOpt.GeneralVariableRef, Vector{JuMP.AbstractJuMPScalar}}
    # NOTE not sure if these are needed
    measure_supports::Dict{InfiniteOpt.GeneralVariableRef, Vector{Tuple}}

    # Constraint information
    constr_mappings::Dict{InfiniteOpt.InfOptConstraintRef{JuMP.ScalarShape},
                          Vector{JuMP.ConstraintRef}}
    constr_supports::Dict{InfiniteOpt.InfOptConstraintRef{JuMP.ScalarShape},
                          Vector{Tuple}}

    # Settings
    verbose_naming::Bool

    # Collected Supports
    supports::Union{Nothing, Tuple}

    # Default constructor
    function TranscriptionData(; verbose_naming::Bool = false)
        return new( # variable info
                   Dict{InfiniteOpt.GeneralVariableRef, Dict{Vector{Float64}, Int}}(),
                   Dict{InfiniteOpt.GeneralVariableRef, Vector{JuMP.VariableRef}}(),
                   Dict{InfiniteOpt.GeneralVariableRef, Vector{Tuple}}(),
                   Dict{InfiniteOpt.GeneralVariableRef, JuMP.VariableRef}(),
                   # internal variables
                   Vector{InfiniteOpt.ReducedVariable{InfiniteOpt.GeneralVariableRef}}(),
                   0,
                   # measure info
                   Dict{InfiniteOpt.GeneralVariableRef, Dict{Vector{Float64}, Int}}(),
                   Dict{InfiniteOpt.GeneralVariableRef, Vector{JuMP.AbstractJuMPScalar}}(),
                   Dict{InfiniteOpt.GeneralVariableRef, Vector{Tuple}}(),
                   # constraint info
                   Dict{InfiniteOpt.InfOptConstraintRef{JuMP.ScalarShape},
                        Vector{JuMP.ConstraintRef}}(),
                   Dict{InfiniteOpt.InfOptConstraintRef{JuMP.ScalarShape},
                        Vector{Vector{Float64}}}(),
                   # settings
                   verbose_naming,
                   # support storage
                   nothing)
    end
end

"""
    TranscriptionModel([optimizer_constructor;
                       caching_mode::MOIU.CachingOptimizerMode = MOIU.AUTOMATIC,
                       bridge_constraints::Bool = true,
                       verbose_naming::Bool = false])::JuMP.Model

Return a [`JuMP.Model`](@ref) with [`TranscriptionData`](@ref) included in the
`ext` data field. Accepts the same arguments as a typical JuMP `Model`.
More detailed variable and constraint naming can be enabled via `verbose_naming`.

**Example**
```julia-repl
julia> TranscriptionModel()
A JuMP Model
Feasibility problem with:
Variables: 0
Model mode: AUTOMATIC
CachingOptimizer state: NO_OPTIMIZER
Solver name: No optimizer attached.
```
"""
function TranscriptionModel(; verbose_naming::Bool = false,
                            kwargs...)::JuMP.Model
    model = JuMP.Model(; kwargs...)
    model.ext[:TransData] = TranscriptionData(verbose_naming = verbose_naming)
    return model
end
# Accept optimizer_factorys
function TranscriptionModel(optimizer_constructor;
                            verbose_naming::Bool = false,
                            kwargs...)::JuMP.Model
    model = JuMP.Model(optimizer_constructor; kwargs...)
    model.ext[:TransData] = TranscriptionData(verbose_naming = verbose_naming)
    return model
end

################################################################################
#                                BASIC QUERIES
################################################################################
"""
    is_transcription_model(model::JuMP.Model)::Bool

Return true if `model` is a `TranscriptionModel` or false otherwise.

**Example**
```julia-repl
julia> is_transcription_model(model)
true
```
"""
function is_transcription_model(model::JuMP.Model)::Bool
    return haskey(model.ext, :TransData)
end

"""
    transcription_data(model::JuMP.Model)::TranscriptionData

Return the `TranscriptionData` from a `TranscriptionModel`. Errors if it is not
a `TranscriptionModel`.
"""
function transcription_data(model::JuMP.Model)::TranscriptionData
    !is_transcription_model(model) && error("Model is not a transcription model.")
    return model.ext[:TransData]
end

################################################################################
#                              VARIABLE QUERIES
################################################################################
"""
    transcription_variable(model::JuMP.Model,
                           vref::InfiniteOpt.GeneralVariableRef)

Return the transcribed variable reference(s) corresponding to `vref`. Errors
if no transcription variable is found. Also can query via the syntax:
```julia
transcription_variable(vref::InfiniteOpt.GeneralVariableRef)
```
If the infinite model contains a built transcription model.

**Example**
```julia-repl
julia> transcription_variable(trans_model, infvar)
2-element Array{VariableRef,1}:
 infvar(support: 1)
 infvar(support: 2)

julia> transcription_variable(trans_model, hdvar)
hdvar

julia> transcription_variable(infvar)
2-element Array{VariableRef,1}:
 infvar(support: 1)
 infvar(support: 2)

julia> transcription_variable(hdvar)
hdvar
```
"""
function transcription_variable(model::JuMP.Model,
                                vref::InfiniteOpt.GeneralVariableRef)
    return transcription_variable(model, vref, InfiniteOpt._index_type(vref))
end

## Define the variable mapping functions
# FiniteVariableIndex
function transcription_variable(model::JuMP.Model,
    vref::InfiniteOpt.GeneralVariableRef,
    index_type::Type{V}
    )::JuMP.VariableRef where {V <: InfiniteOpt.FiniteVariableIndex}
    var = get(transcription_data(model).finvar_mappings, vref, nothing)
    if isnothing(var)
        error("Variable reference $vref not used in transcription model.")
    end
    return var
end

# InfiniteIndex
function transcription_variable(model::JuMP.Model,
    vref::InfiniteOpt.GeneralVariableRef,
    index_type::Type{V}
    )::Vector{JuMP.VariableRef} where {V <: InfiniteOpt.InfiniteIndex}
    var = get(transcription_data(model).infvar_mappings, vref, nothing)
    if isnothing(var)
        error("Variable reference $vref not used in transcription model.")
    end
    return var
end

# Fallback
function transcription_variable(model::JuMP.Model,
    vref::InfiniteOpt.GeneralVariableRef,
    index_type)
    error("`transcription_variable` not defined for variables with indices of " *
          "type $(index_type).")
end

# Dispatch for internal models
function transcription_variable(vref::InfiniteOpt.GeneralVariableRef)
    trans_model = InfiniteOpt.optimizer_model(JuMP.owner_model(vref))
    return transcription_variable(trans_model, vref)
end

"""
    InfiniteOpt.optimizer_model_variable(vref::InfiniteOpt.GeneralVariableRef,
                                         ::Val{:TransData})

Proper extension of [`InfiniteOpt.optimizer_model_variable`](@ref) for
`TranscriptionModel`s. This simply dispatches to [`transcription_variable`](@ref).
"""
function InfiniteOpt.optimizer_model_variable(vref::InfiniteOpt.GeneralVariableRef,
                                              ::Val{:TransData})
    return transcription_variable(vref)
end

"""
    InfiniteOpt.variable_supports(model::JuMP.Model,
        vref::Union{InfiniteOpt.InfiniteVariableRef, InfiniteOpt.ReducedVariableRef},
        key::Val{:TransData} = Val(:TransData))::Vector

Return the support alias mapping associated with `vref` in the transcribed model.
Errors if `vref` does not have transcribed variables.
"""
function InfiniteOpt.variable_supports(model::JuMP.Model,
    vref::Union{InfiniteOpt.InfiniteVariableRef, InfiniteOpt.ReducedVariableRef},
    key::Val{:TransData} = Val(:TransData)
    )::Vector
    if !haskey(transcription_data(model).infvar_mappings, vref)
        error("Variable reference $vref not used in transcription model.")
    elseif !haskey(transcription_data(model).infvar_supports, vref)
        prefs = InfiniteOpt.raw_parameter_refs(vref)
        lookups = transcription_data(model).infvar_lookup[vref]
        supp = VectorTuple(first(keys(lookups)), prefs.ranges, prefs.indices)
        type = typeof(Tuple(supp))
        supps = Vector{type}(undef, length(lookups))
        for (s, i) in lookups
            supp.values[:] = s
            supps[i] = Tuple(supp)
        end
        transcription_data(model).infvar_supports[vref] = supps
    end
    return transcription_data(model).infvar_supports[vref]
end


"""
    lookup_by_support(model::JuMP.Model,
                      vref::InfiniteOpt.GeneralVariableRef,
                      support::Vector)

Return the transcription expression of `vref` defined at its `support`. This is
intended as a helper method for automated transcription and doesn't implement
any error checking.
"""
function lookup_by_support(model::JuMP.Model,
    vref::InfiniteOpt.GeneralVariableRef,
    support::Vector)
    return transcription_expression(model, vref, InfiniteOpt._index_type(vref),
                                    support)
end

# InfiniteIndex
function lookup_by_support(model::JuMP.Model,
    vref::InfiniteOpt.GeneralVariableRef,
    index_type::Type{V},
    support::Vector
    )::JuMP.VariableRef where {V <: InfiniteOpt.InfiniteIndex}
    idx = transcription_data(model).infvar_lookup[vref][support]
    return transcription_data(model).infvar_mappings[vref][idx]
end

# FiniteVariableIndex
function lookup_by_support(model::JuMP.Model,
    vref::InfiniteOpt.GeneralVariableRef,
    index_type::Type{V},
    support::Vector
    )::JuMP.VariableRef where {V <: InfiniteOpt.FiniteVariableIndex}
    return transcription_data(model).finvar_mappings[vref]
end

# Extend internal_reduced_variable
function InfiniteOpt.internal_reduced_variable(
    vref::InfiniteOpt.ReducedVariableRef,
    ::Val{:TransData}
    )::ReducedVariable{GeneralVariableRef}
    trans_model = InfiniteOpt.optimizer_model(JuMP.owner_model(vref))
    reduced_vars = transcription_data(trans_model).reduced_vars
    idx = -1 * JuMP.index(vref).value
    if idx in keys(reduced_vars)
        return reduced_vars[idx]
    else
        error("Invalid reduced variable reference, this likely is attributed " *
              "to its being deleted.")
    end
end

################################################################################
#                              MEASURE QUERIES
################################################################################
# Extend transcription_expression
function lookup_by_support(model::JuMP.Model,
    mref::InfiniteOpt.GeneralVariableRef,
    index_type::Type{InfiniteOpt.MeasureIndex},
    support::Vector
    )::JuMP.AbstractJuMPScalar
    idx = transcription_data(model).measure_lookup[mref][support]
    return transcription_data(model).measure_mappings[mref][idx]
end

# Extend variable_supports
function InfiniteOpt.variable_supports(model::JuMP.Model,
    mref::InfiniteOpt.MeasureRef,
    key::Val{:TransData} = Val(:TransData)
    )::Vector
    supps = get(transcription_data(model).measure_supports, mref, nothing)
    if isnothing(supps)
        error("Variable reference $mref not used in transcription model.")
    end
    return supps
end

################################################################################
#                             CONSTRAINT QUERIES
################################################################################
"""
    transcription_constraint(model::JuMP.Model,
                             cref::InfiniteOpt.InfOptConstraintRef
                             )::Vector{JuMP.ConstraintRef}

Return the transcribed constraint reference(s) corresponding to `cref`. Errors
if `cref` has not been transcribed. Also can query via the syntax:
```julia
transcription_constraint(cref::InfiniteOpt.InfOptConstraintRef)
```
If the infinite model contains a built transcription model.

**Example**
```julia-repl
julia> transcription_constraint(trans_model, fin_con)
fin_con : x(support: 1) - y <= 3.0

julia> transcription_constraint(fin_con)
fin_con : x(support: 1) - y <= 3.0
```
"""
function transcription_constraint(model::JuMP.Model,
                                  cref::InfiniteOpt.InfOptConstraintRef
                                  )::Vector{JuMP.ConstraintRef}
    constr = get(transcription_data(model).constr_mappings, cref, nothing)
    if isnothing(constr)
      error("Constraint reference $cref not used in transcription model.")
    end
    return constr
end

# Dispatch for internal models
function transcription_constraint(cref::InfiniteOpt.InfOptConstraintRef
    )::Vector{JuMP.ConstraintRef}
    trans_model = InfiniteOpt.optimizer_model(JuMP.owner_model(cref))
    return transcription_constraint(trans_model, cref)
end

"""
    InfiniteOpt.optimizer_model_constraint(cref::InfiniteOpt.InfOptConstraintRef,
                                           ::Val{:TransData})

Proper extension of [`InfiniteOpt.optimizer_model_constraint`](@ref) for
`TranscriptionModel`s. This simply dispatches to [`transcription_constraint`](@ref).
"""
function InfiniteOpt.optimizer_model_constraint(
    cref::InfiniteOpt.InfOptConstraintRef,
    ::Val{:TransData}
    )::Vector{JuMP.ConstraintRef}
    return transcription_constraint(cref)
end

"""
    InfiniteOpt.constraint_supports(model::JuMP.Model,
                                    cref::InfiniteOpt.InfOptConstraintRef,
                                    key::Val{:TransData} = Val(:TransData)
                                    )::Vector

Return the support alias mappings associated with `cref`. Errors if `cref` is
not transcribed.
"""
function InfiniteOpt.constraint_supports(model::JuMP.Model,
                                         cref::InfiniteOpt.InfOptConstraintRef,
                                         key::Val{:TransData} = Val(:TransData)
                                         )::Vector
    supps = get(transcription_data(model).constr_supports, cref, nothing)
    if isnothing(supps)
        error("Constraint reference $cref not used in transcription model.")
    end
    return supps
end

################################################################################
#                             OTHER QUERIES
################################################################################
# Access the collected supports
function parameter_supports(model::JuMP.Model)::Union{Nothing, Tuple}
    return transcription_data(model).supports
end

## Form a placeholder parameter reference given the object index
# IndependentParameterIndex
function _temp_parameter_ref(model::InfiniteOpt.InfiniteModel,
    index::InfiniteOpt.IndependentParameterIndex
    )::InfiniteOpt.IndependentParameterRef
    return InfiniteOpt.IndependentParameterRef(model, index)
end

# DependentParametersIndex
function _temp_parameter_ref(model::InfiniteOpt.InfiniteModel,
    index::InfiniteOpt.DependentParametersIndex
    )::InfiniteOpt.DependentParameterRef
    idx = InfiniteOpt.DependentParameterIndex(index, 1)
    return InfiniteOpt.DependentParameterRef(model, idx)
end

# Return the collected supports of an infinite parameter
function _collected_supports(model::InfiniteOpt.InfiniteModel,
    index::InfiniteOpt.InfiniteParameterIndex
    )::Vector
    pref = _temp_parameter_ref(model, index)
    supps = InfiniteOpt._parameter_supports(pref)
    return collect(keys(supps))
end

# Build the parameter supports
function set_parameter_supports(model::JuMP.Model,
                                inf_model::InfiniteOpt.InfiniteModel)::Nothing
    param_indices = InfiniteOpt._param_object_indices(inf_model)
    supps = Tuple(_collected_supports(inf_model, i) for i in param_indices)
    transcription_data(model).supports = supps
    return
end
