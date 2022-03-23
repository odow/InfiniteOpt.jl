################################################################################
#                      GENERATIVE SUPPORT INFORMATION TYPES
################################################################################
"""
    AbstractGenerativeInfo

An abstract type for storing information about generating supports that are made 
based on existing supports as required by certain measures and/or derivatives 
that depend on a certain independent infinite parameter. Such as the case with 
internal collocation supports.
"""
abstract type AbstractGenerativeInfo end 

"""
    NoGenerativeSupports <: AbstractGenerativeInfo

A `DataType` to signify that no generative supports will be generated for the 
measures and/or the derivatives. Has no fields.
"""
struct NoGenerativeSupports <: AbstractGenerativeInfo end

"""
    UniformGenerativeInfo <: AbstractGenerativeInfo

A `DataType` for generative supports that will be generated in a uniform manner 
over finite elements (i.e., in between the existing supports). These generative 
supports are described by the `support_basis` which lie in a nominal domain [0, 1]. 
The constructor is of the form:
```
    UniformGenerativeInfo(support_basis::Vector{<:Real}, label::DataType, 
                          [lb::Real = 0, ub::Real = 1])
```
where the `support_basis` is defined over [`lb`, `ub`].

**Fields**
- `support_basis::Vector{Float64}`: The basis of generative supports defined in 
   [0, 1] that will be transformed for each finite element.
- `label::DataType`: The unique label to be given to each generative support.
"""
struct UniformGenerativeInfo <: AbstractGenerativeInfo
    support_basis::Vector{Float64}
    label::DataType
    function UniformGenerativeInfo(basis::Vector{<:Real}, label::DataType, 
                                   lb::Real = 0, ub::Real = 1)
        if minimum(basis) < lb || maximum(basis) > ub
            error("Support basis violate the given lower and upper bounds. " * 
                  "Please specify the appropriate lower bound and upper bounds.")
        end
        return new((basis .- lb) ./ (ub - lb),  label)
    end
end

# Extend Base.:(==)
function Base.:(==)(info1::UniformGenerativeInfo, info2::UniformGenerativeInfo)
    return info1.support_basis == info2.support_basis && info1.label == info2.label
end

################################################################################
#                        SUPPORT AND LABEL GENERATION
################################################################################
"""
    AbstractSupportLabel

An abstract type for support label types. These are used to distinguish different 
kinds of supports that are added to infinite parameters.
"""
abstract type AbstractSupportLabel end 

"""
    All <: AbstractSupportLabel

This support label is unique in that it isn't associated with a particular set of 
supports, but rather is used used to indicate that all supports should be used.
"""
struct All <: AbstractSupportLabel end

# Filler label for NoGenerativeSupports
struct _NoLabel <: AbstractSupportLabel end

"""
    PublicLabel <: AbstractSupportLabel

An abstract type used to denote that labels that should be given to the user by 
default.
"""
abstract type PublicLabel <: AbstractSupportLabel end 

"""
    UserDefined <: PublicLabel

A support label for supports that are supplied by the user directly to an infinite 
parameter. 
"""
struct UserDefined <: PublicLabel end 

"""
    UniformGrid <: PublicLabel

A support label for supports that are generated uniformly accross a given interval.
"""
struct UniformGrid <: PublicLabel end

"""
    SampleLabel <: PublicLabel

An abstract type for labels of supports that are generated via some sampling technique.
"""
abstract type SampleLabel <: PublicLabel end

"""
    MCSample <: SampleLabel

A support label for supports that are generated via Monte Carlo Sampling.
"""
struct MCSample <: SampleLabel end 

"""
    WeightedSample <: SampleLabel

A support label for supports that are generated by sampling from a statistical 
distribution.
"""
struct WeightedSample <: SampleLabel end 

"""
    Mixture <: PublicLabel

A support label for multi-dimensional supports that are generated from a variety 
of methods.
"""
struct Mixture <: PublicLabel end

"""
    UniqueMeasure{S::Symbol} <: PublicLabel

A support label for supports that are provided from the `DiscreteMeasureData` 
associated with a measure where a unique label is generated to distinguish those 
supports. This is done by invoking [`generate_unique_label`](@ref).
"""
struct UniqueMeasure{S} <: PublicLabel end

"""
    MeasureBound <: PublicLabel
    
A support label for supports that are generated using the upper and lower bounds
for `FunctionalDiscreteMeasureData`.
"""
struct MeasureBound <: PublicLabel end

"""
    InternalLabel <: AbstractSupportLabel

An abstract type for support labels that are associated with supports that should 
not be reported to the user by default.
"""
abstract type InternalLabel <: AbstractSupportLabel end 

"""
    generate_unique_label()::Type{UniqueMeasure}

Generate and return a unique support label for measures.
"""
function generate_unique_label()::DataType
    return UniqueMeasure{gensym()}
end

# Define default values of num_supports keyword
const DefaultNumSupports = 10

# a user interface of generate_support_values
"""
    generate_supports(domain::AbstractInfiniteDomain
                      [method::Type{<:AbstractSupportLabel}];
                      [num_supports::Int = DefaultNumSupports,
                      sig_digits::Int = DefaultSigDigits]
                      )::Tuple{Array{<:Real}, DataType}

Generate `num_supports` support values with `sig_digits` significant digits in
accordance with `domain` and return them along with the correct generation label(s).
`IntervalDomain`s generate supports uniformly with label `UniformGrid` and
distribution domains generate them randomly accordingly to the
underlying distribution. Moreover, `method` indicates the generation method that
should be used. These `methods` correspond to parameter support labels. Current
labels that can be used as generation methods include (but may not be defined
for certain domain types):
- [`MCSample`](@ref): Uniformly distributed Monte Carlo samples.
- [`WeightedSample`](@ref): Monte Carlo samples that are weighted by an underlying PDF.
- [`UniformGrid`](@ref): Samples that are generated uniformly over the domain.

Extensions that employ user-defined infinite domain types and/or methods
should extend [`generate_support_values`](@ref) to enable this. Errors if the
`domain` type and /or methods are unrecognized. This is intended as an internal
method to be used by methods such as [`generate_and_add_supports!`](@ref).
"""
function generate_supports(domain::AbstractInfiniteDomain;
                           num_supports::Int = DefaultNumSupports,
                           sig_digits::Int = DefaultSigDigits
                           )::Tuple
    return generate_support_values(domain, num_supports = num_supports,
                                   sig_digits = sig_digits)
end

# 2 arguments
function generate_supports(domain::AbstractInfiniteDomain,
                           method::Type{<:AbstractSupportLabel};
                           num_supports::Int = DefaultNumSupports,
                           sig_digits::Int = DefaultSigDigits
                           )::Tuple
    return generate_support_values(domain, method,
                                   num_supports = num_supports,
                                   sig_digits = sig_digits)
end

"""
    generate_support_values(domain::AbstractInfiniteDomain,
                            [method::Type{MyMethod} = MyMethod];
                            [num_supports::Int = DefaultNumSupports,
                            sig_digits::Int = DefaultSigDigits]
                            )::Tuple{Array{<:Real}, Symbol}

A multiple dispatch method for [`generate_supports`](@ref). This will return
a tuple where the first element are the supports and the second is their
label. This can be extended for user-defined infinite domains and/or generation
methods. When defining a new domain type the default method dispatch should
make `method` an optional argument (making it the default). Otherwise, other
method dispatches for a given domain must ensure that `method` is positional
argument without a default value (contrary to the definition above). Note that the 
`method` must be a subtype of either [`PublicLabel`](@ref) or [`InternalLabel`](@ref).
"""
function generate_support_values(domain::AbstractInfiniteDomain,
                                 args...; kwargs...)
    if isempty(args)
        error("`generate_support_values` has not been extended for infinite domains " * 
              "of type `$(typeof(domain))`. This automatic support generation is not " * 
              "implemented.")
    else
        error("`generate_support_values` has not been extended for infinite domains " * 
              "of type `$(typeof(domain))` with the generation method `$(args[1])`. " * 
              "This automatic support generation is not implemented.")
    end
end

# IntervalDomain and UniformGrid
function generate_support_values(domain::IntervalDomain,
                                 method::Type{UniformGrid} = UniformGrid;
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits,
                                 )::Tuple{Vector{<:Real}, DataType}
    lb = JuMP.lower_bound(domain)
    ub = JuMP.upper_bound(domain)
    new_supports = round.(range(lb, stop = ub, length = num_supports),
                          sigdigits = sig_digits)
    return new_supports, method
end

# IntervalDomain and MCSample
function generate_support_values(domain::IntervalDomain,
                                 method::Type{MCSample};
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits,
                                 )::Tuple{Vector{<:Real}, DataType}
    lb = JuMP.lower_bound(domain)
    ub = JuMP.upper_bound(domain)
    dist = Distributions.Uniform(lb, ub)
    new_supports = round.(Distributions.rand(dist, num_supports),
                          sigdigits = sig_digits)
    return new_supports, method
end

# UniDistributionDomain and MultiDistributionDomain (with multivariate only)
function generate_support_values(
    domain::Union{UniDistributionDomain, MultiDistributionDomain{<:Distributions.MultivariateDistribution}},
    method::Type{WeightedSample} = WeightedSample;
    num_supports::Int = DefaultNumSupports,
    sig_digits::Int = DefaultSigDigits
    )::Tuple{Array{<:Real}, DataType}
    dist = domain.distribution
    new_supports = round.(Distributions.rand(dist, num_supports),
                          sigdigits = sig_digits)
    return new_supports, method
end

# UniDistributionDomain and MCSample 
function generate_support_values(
    domain::UniDistributionDomain,
    method::Type{MCSample};
    num_supports::Int = DefaultNumSupports,
    sig_digits::Int = DefaultSigDigits
    )::Tuple{Vector{Float64}, DataType}
    return generate_support_values(domain, WeightedSample; num_supports = num_supports, 
                                   sig_digits = sig_digits)[1], method # TODO use an unwieghted sample...
end

# MultiDistributionDomain (matrix-variate distribution)
function generate_support_values(
    domain::MultiDistributionDomain{<:Distributions.MatrixDistribution},
    method::Type{WeightedSample} = WeightedSample;
    num_supports::Int = DefaultNumSupports,
    sig_digits::Int = DefaultSigDigits
    )::Tuple{Array{Float64, 2}, DataType}
    dist = domain.distribution
    raw_supports = Distributions.rand(dist, num_supports)
    new_supports = Array{Float64}(undef, length(dist), num_supports)
    for i in 1:size(new_supports, 2)
        new_supports[:, i] = round.(reduce(vcat, raw_supports[i]),
                                    sigdigits = sig_digits)
    end
    return new_supports, method
end

# Generate the supports for a collection domain
function _generate_collection_supports(domain::CollectionDomain, num_supports::Int,
                                       sig_digits::Int)::Array{Float64, 2}
    domains = collection_domains(domain)
    # build the support array transpose to fill in column order (leverage locality)
    trans_supports = Array{Float64, 2}(undef, num_supports, length(domains))
    for i in eachindex(domains)
        @inbounds trans_supports[:, i] = generate_support_values(domains[i],
                                                   num_supports = num_supports,
                                                   sig_digits = sig_digits)[1]
    end
    return permutedims(trans_supports)
end

function _generate_collection_supports(domain::CollectionDomain,
                                       method::Type{<:AbstractSupportLabel},
                                       num_supports::Int,
                                       sig_digits::Int)::Array{Float64, 2}
    domains = collection_domains(domain)
    # build the support array transpose to fill in column order (leverage locality)
    trans_supports = Array{Float64, 2}(undef, num_supports, length(domains))
    for i in eachindex(domains)
        @inbounds trans_supports[:, i] = generate_support_values(domains[i],
                                                   method,
                                                   num_supports = num_supports,
                                                   sig_digits = sig_digits)[1]
    end
    return permutedims(trans_supports)
end

# CollectionDomain (IntervalDomains)
function generate_support_values(domain::CollectionDomain{IntervalDomain},
                                 method::Type{UniformGrid} = UniformGrid;
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits
                                 )::Tuple{Array{<:Real}, DataType}
    new_supports = _generate_collection_supports(domain, num_supports, sig_digits)
    return new_supports, method
end

function generate_support_values(domain::CollectionDomain{IntervalDomain},
                                 method::Type{MCSample};
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits
                                 )::Tuple{Array{<:Real}, DataType}
    new_supports = _generate_collection_supports(domain, method, num_supports, sig_digits)
    return new_supports, method
end

# CollectionDomain (UniDistributionDomains)
function generate_support_values(domain::CollectionDomain{<:UniDistributionDomain},
                                 method::Type{WeightedSample} = WeightedSample;
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits
                                 )::Tuple{Array{<:Real}, DataType}
    new_supports = _generate_collection_supports(domain, num_supports, sig_digits)
    return new_supports, method
end

# CollectionDomain (InfiniteScalarDomains)
function generate_support_values(domain::CollectionDomain,
                                 method::Type{Mixture} = Mixture;
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits
                                 )::Tuple{Array{<:Real}, DataType}
    new_supports = _generate_collection_supports(domain, num_supports, sig_digits)
    return new_supports, method
end

# CollectionDomain (InfiniteScalarDomains) using purely MC sampling
# this is useful for measure support generation
function generate_support_values(domain::CollectionDomain,
                                 method::Type{MCSample};
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits
                                 )::Tuple{Array{<:Real}, DataType}
    new_supports = _generate_collection_supports(domain, method, num_supports, sig_digits)
    return new_supports, method
end

# For label All: dispatch to default methods
function generate_support_values(domain::AbstractInfiniteDomain, ::Type{All};
                                 num_supports::Int = DefaultNumSupports,
                                 sig_digits::Int = DefaultSigDigits)
    return generate_support_values(domain, num_supports = num_supports,
                                   sig_digits = sig_digits)
end

################################################################################
#                       GENERATIVE SUPPORT FUNCTIONS
################################################################################
# Extend copy for NoGenerativeSupports
function Base.copy(d::NoGenerativeSupports)::NoGenerativeSupports
    return NoGenerativeSupports()
end

# Extend copy for UniformGenerativeInfo
function Base.copy(d::UniformGenerativeInfo)::UniformGenerativeInfo
    return UniformGenerativeInfo(copy(d.support_basis), d.label)
end

"""
    support_label(info::AbstractGenerativeInfo)::DataType 

Return the support label to be associated with generative supports produced in 
accordance with `info`. This is intended an internal method that should be 
extended for user defined types of [`AbstractGenerativeInfo`](@ref).
"""
function support_label(info::AbstractGenerativeInfo)
    error("`support_label` not defined for generative support info type " *
          "$(typeof(info)).")
end

# UniformGenerativeInfo
function support_label(info::UniformGenerativeInfo)::DataType
    return info.label
end

# NoGenerativeSupports
function support_label(info::NoGenerativeSupports)::DataType
    return _NoLabel
end

"""
    generative_support_info(pref::IndependentParameterRef)::AbstractGenerativeInfo

Return the generative support information associated with `pref`.
"""
function generative_support_info(pref::IndependentParameterRef)::AbstractGenerativeInfo
    return _core_variable_object(pref).generative_supp_info
end

"""
    has_generative_supports(pref::IndependentParameterRef)::Bool

Return whether generative supports have been added to `pref` in accordance 
with its generative support info.
"""
function has_generative_supports(pref::IndependentParameterRef)::Bool
    return _data_object(pref).has_generative_supports
end

# Specify if a parameter has generative supports
function _set_has_generative_supports(pref::IndependentParameterRef, 
                                      status::Bool)::Nothing
    _data_object(pref).has_generative_supports = status 
    return
end

# Reset (remove) the generative supports if needed 
function _reset_generative_supports(pref::IndependentParameterRef)::Nothing
    if has_generative_supports(pref)
        label = support_label(generative_support_info(pref))
        delete_supports(pref, label = label) # this also calls _set_has_generative_supports
    end
    return
end

# Specify the generative_support_info
function _set_generative_support_info(pref::IndependentParameterRef, 
    info::AbstractGenerativeInfo)::Nothing
    sig_digits = significant_digits(pref)
    method = derivative_method(pref)
    domain = _parameter_domain(pref)
    supps = _parameter_supports(pref)
    new_param = IndependentParameter(domain, supps, sig_digits, method, info)
    _reset_generative_supports(pref)
    _set_core_variable_object(pref, new_param)
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

"""
    make_generative_supports(info::AbstractGenerativeInfo,
                             pref::IndependentParameterRef,
                             existing_supps::Vector{Float64}
                             )::Vector{Float64}

Generate the generative supports for `pref` in accordance with `info` and the 
`existing_supps` that `pref` has. The returned supports should not include 
`existing_supps`. This is intended as internal method to enable 
[`add_generative_supports`](@ref) and should be extended for any user defined 
`info` types that are created to enable new measure and/or derivative evaluation 
techniques that require the creation of generative supports.
"""
function make_generative_supports(info::AbstractGenerativeInfo, pref, supps)
    error("`make_generative_supports` is not defined for generative support " * 
          "info of type $(typeof(info)).")
end

# UniformGenerativeInfo
function make_generative_supports(info::UniformGenerativeInfo, 
    pref, supps)::Vector{Float64}
    # collect the preliminaries
    basis = info.support_basis
    num_internal = length(basis)
    num_existing = length(supps)
    num_existing <= 1 && error("$(pref) does not have enough supports for " *
                                "creating generative supports.")
    internal_nodes = Vector{Float64}(undef, num_internal * (num_existing - 1))
    # generate the internal node supports
    for i in Iterators.take(eachindex(supps), num_existing - 1)
        lb = supps[i]
        ub = supps[i+1]
        internal_nodes[(i-1)*num_internal+1:i*num_internal] = basis * (ub - lb) .+ lb
    end
    return internal_nodes
end

## Define internal dispatch methods for adding generative supports
# AbstractGenerativeInfo
function _add_generative_supports(pref, info::AbstractGenerativeInfo)::Nothing 
    if !has_generative_supports(pref)
        existing_supps = supports(pref, label = All)
        supps = make_generative_supports(info, pref, existing_supps)
        add_supports(pref, supps, label = support_label(info))
        _set_has_generative_supports(pref, true)
    end
    return
end

# NoGenerativeSupports
function _add_generative_supports(pref, info::NoGenerativeSupports)::Nothing 
    return
end

"""
    add_generative_supports(pref::IndependentParameterRef)::Nothing

Create generative supports for `pref` if needed in accordance with its 
generative support info using [`make_generative_supports`](@ref) and add them to 
`pref`. This is intended as an internal function, but can be useful user defined 
optimizer model extensions that utlize our support system.
"""
function add_generative_supports(pref::IndependentParameterRef)::Nothing
    info = generative_support_info(pref)
    _add_generative_supports(pref, info)
    return
end

################################################################################
#                               SUPPORT FUNCTIONS
################################################################################
# Internal functions
function _parameter_supports(pref::IndependentParameterRef)
    return _core_variable_object(pref).supports
end
function _parameter_support_values(pref::IndependentParameterRef)::Vector{Float64}
    return collect(keys(_parameter_supports(pref)))
end
function _update_parameter_supports(pref::IndependentParameterRef,
    supports::DataStructures.SortedDict{Float64, Set{DataType}})::Nothing
    domain = _parameter_domain(pref)
    method = derivative_method(pref)
    sig_figs = significant_digits(pref)
    info = generative_support_info(pref)
    new_param = IndependentParameter(domain, supports, sig_figs, method, info)
    _set_core_variable_object(pref, new_param)
    _reset_derivative_constraints(pref)
    _set_has_generative_supports(pref, false)
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

"""
    has_internal_supports(pref::Union{IndependentParameterRef, DependentParameterRef})::Bool

Indicate if `pref` has internal supports that will be hidden from the user by 
default. 
"""
function has_internal_supports(
    pref::Union{IndependentParameterRef, DependentParameterRef}
    )::Bool 
    return _data_object(pref).has_internal_supports
end

# update has internal supports 
function _set_has_internal_supports(
    pref::Union{IndependentParameterRef, DependentParameterRef}, 
    status::Bool
    )::Nothing
    _data_object(pref).has_internal_supports = status
    return
end

"""
    significant_digits(pref::IndependentParameterRef)::Int

Return the number of significant digits enforced on the supports of `pref`.

**Example**
```julia-repl
julia> significant_digits(t)
12
```
"""
function significant_digits(pref::IndependentParameterRef)::Int
    return _core_variable_object(pref).sig_digits
end

"""
    num_supports(pref::IndependentParameterRef; 
                 [label::Type{<:AbstractSupportLabel} = PublicLabel])::Int

Return the number of support points associated with `pref`. By default, only the 
number of public supports are counted. The full amount can be determined by setting 
`label = All`. Moreover, the amount of labels that satisfy `label` is obtained 
using an [`AbstractSupportLabel`](@ref).

**Example**
```julia-repl
julia> num_supports(t)
2
```
"""
function num_supports(pref::IndependentParameterRef; 
                      label::Type{<:AbstractSupportLabel} = PublicLabel)::Int
    supports_dict = _parameter_supports(pref)
    if label == All || (!has_internal_supports(pref) && label == PublicLabel)
        return length(supports_dict)
    else
        return count(p -> any(v -> v <: label, p[2]), supports_dict)
    end
end

"""
    has_supports(pref::IndependentParameterRef)::Bool

Return true if `pref` has supports or false otherwise.

**Example**
```julia-repl
julia> has_supports(t)
true
```
"""
has_supports(pref::IndependentParameterRef)::Bool = !isempty(_parameter_supports(pref))

"""
    supports(pref::IndependentParameterRef; 
             [label::Type{<:AbstractSupportLabel} = PublicLabel])::Vector{Float64}

Return the support points associated with `pref`. Errors if there are no
supports. Users can query just support points generated by a certain method
using the keyword argument `label`. By default, the function returns all public
support points regardless of the associated label. The full collection is given by setting 
`label = All`. Moreover, the amount of labels that satisfy `label` is obtained 
using an [`AbstractSupportLabel`](@ref).

**Example**
```julia-repl
julia> supports(t)
2-element Array{Float64,1}:
 0.0
 1.0
```
"""
function supports(pref::IndependentParameterRef; 
                  label::Type{<:AbstractSupportLabel} = PublicLabel)::Vector{Float64}
    if label == All || (!has_internal_supports(pref) && label == PublicLabel)
        return _parameter_support_values(pref)
    else
        return findall(x -> any(v -> v <: label, x), _parameter_supports(pref))
    end
end

# Return a matrix os supports when given a vector of IndependentParameterRefs (for measures)
function supports(prefs::Vector{IndependentParameterRef};
                  label::Type{<:AbstractSupportLabel} = PublicLabel,
                  use_combinatorics::Bool = true)::Matrix{Float64}
    # generate the support matrix considering all the unique combinations
    if use_combinatorics 
        supp_list = Tuple(supports(p, label = label) for p in prefs)
        inds = CartesianIndices(ntuple(i -> 1:length(supp_list[i]), length(prefs)))
        supps = Matrix{Float64}(undef, length(prefs), length(inds))
        for (k, idx) in enumerate(inds) 
            supps[:, k] = [supp_list[i][j] for (i, j) in enumerate(idx.I)]
        end
        return supps
    # generate the support matrix while negating the unique combinations
    else 
        num_supps = num_supports(first(prefs), label = label)
        trans_supps = Matrix{Float64}(undef, num_supps, length(prefs))
        for i in eachindex(prefs)
            supp = supports(prefs[i], label = label)
            if length(supp) != num_supps
                error("Cannot simultaneously query the supports of multiple " *
                      "independent parameters if the support dimensions do not match " *
                      "while ignoring the combinatorics. Try setting `use_combinatorics = true`.")
            else
                @inbounds trans_supps[:, i] = supp
            end
        end
        return permutedims(trans_supps)
    end
end

"""
    set_supports(pref::IndependentParameterRef, supports::Vector{<:Real};
                 [force::Bool = false,
                 label::Type{<:AbstractSupportLabel} = UserDefined]
                 )::Nothing

Specify the support points for `pref`. Errors if the supports violate the bounds
associated with the infinite domain. Warns if the points are not unique. If `force`
this will overwrite exisiting supports otherwise it will error if there are
existing supports.

**Example**
```julia-repl
julia> set_supports(t, [0, 1])

julia> supports(t)
2-element Array{Int64,1}:
 0
 1
```
"""
function set_supports(pref::IndependentParameterRef, supports::Vector{<:Real};
                      force::Bool = false, 
                      label::Type{<:AbstractSupportLabel} = UserDefined
                      )::Nothing
    if has_supports(pref) && !force
        error("Unable set supports for $pref since it already has supports." *
              " Consider using `add_supports` or use `force = true` to " *
              "overwrite the existing supports.")
    end
    domain = _parameter_domain(pref)
    supports = round.(supports, sigdigits = significant_digits(pref))
    _check_supports_in_bounds(error, supports, domain)
    supports_dict = DataStructures.SortedDict{Float64, Set{DataType}}(
                                            i => Set([label]) for i in supports)
    if length(supports_dict) != length(supports)
        @warn("Support points are not unique, eliminating redundant points.")
    end
    _update_parameter_supports(pref, supports_dict)
    _set_has_internal_supports(pref, label <: InternalLabel)
    return
end

"""
    add_supports(pref::IndependentParameterRef,
                 supports::Union{Real, Vector{<:Real}};
                 [label::Type{<:AbstractSupportLabel} = UserDefined])::Nothing

Add additional support points for `pref` with identifying label `label`.

**Example**
```julia-repl
julia> add_supports(t, 0.5)

julia> supports(t)
3-element Array{Float64,1}:
 0.0
 0.5
 1.0

julia> add_supports(t, [0.25, 1])

julia> supports(t)
4-element Array{Float64,1}:
 0.0
 0.25
 0.5
 1.0
```
"""
function add_supports(pref::IndependentParameterRef,
                      supports::Union{Real, Vector{<:Real}};
                      label::Type{<:AbstractSupportLabel} = UserDefined, 
                      check::Bool = true)::Nothing
    domain = infinite_domain(pref)
    supports = round.(supports, sigdigits = significant_digits(pref))
    check && _check_supports_in_bounds(error, supports, domain)
    supports_dict = _parameter_supports(pref)
    added_new_support = false
    for s in supports
        if haskey(supports_dict, s)
            push!(supports_dict[s], label)
        else
            supports_dict[s] = Set([label])
            added_new_support = true
        end
    end
    if label <: InternalLabel
        _set_has_internal_supports(pref, true)
    end
    if added_new_support
        _reset_derivative_constraints(pref)
        _reset_generative_supports(pref)
        if is_used(pref)
            set_optimizer_model_ready(JuMP.owner_model(pref), false)
        end
    end
    return
end

"""
    delete_supports(pref::IndependentParameterRef; 
                    [label::Type{<:AbstractSupportLabel} = All])::Nothing

Delete the support points for `pref`. If `label != All` then delete `label` and 
any supports that solely depend on it.

**Example**
```julia-repl
julia> delete_supports(t)

julia> supports(t)
ERROR: Parameter t does not have supports.
```
"""
function delete_supports(pref::IndependentParameterRef; 
                         label::Type{<:AbstractSupportLabel} = All)::Nothing
    supp_dict = _parameter_supports(pref)
    if has_derivative_constraints(pref)
        @warn("Deleting supports invalidated derivative evaluations. Thus, these " * 
              "are being deleted as well.")
        for idx in _derivative_dependencies(pref)
            delete_derivative_constraints(DerivativeRef(JuMP.owner_model(pref), idx))
        end
        _set_has_derivative_constraints(pref, false)
    end
    if label == All
        if used_by_measure(pref)
            error("Cannot delete the supports of $pref since it is used by " *
                  "a measure.")
        end
        empty!(supp_dict)
        _set_has_generative_supports(pref, false)
        _set_has_internal_supports(pref, false)
    else
        if has_generative_supports(pref) && support_label(generative_support_info(pref)) != label
            label = Union{label, support_label(generative_support_info(pref))}
        end
        _set_has_generative_supports(pref, false)
        filter!(p -> !all(v -> v <: label, p[2]), supp_dict)
        for (k, v) in supp_dict 
            filter!(l -> !(l <: label), v)
        end
        if has_internal_supports(pref) && num_supports(pref, label = InternalLabel) == 0
            _set_has_internal_supports(pref, false)
        end
    end
    if is_used(pref)
        set_optimizer_model_ready(JuMP.owner_model(pref), false)
    end
    return
end

# Make dispatch for an array of parameters 
function delete_supports(prefs::AbstractArray{<:IndependentParameterRef}; 
                         label::Type{<:AbstractSupportLabel} = All)::Nothing
    delete_supports.(prefs, label = label)
    return
end

"""
    fill_in_supports!(pref::IndependentParameterRef;
                      [num_supports::Int = DefaultNumSupports])::Nothing

Automatically generate support points for a particular independent parameter `pref`.
Generating `num_supports` for the parameter. The supports are generated uniformly
if the underlying infinite domain is an `IntervalDomain` or they are generating randomly
accordingly to the distribution if the domain is a `UniDistributionDomain`.
Will add nothing if there are supports
and `modify = false`. Extensions that use user defined domain types should extend
[`generate_and_add_supports!`](@ref) and/or [`generate_support_values`](@ref)
as needed. Errors if the infinite domain type is not recognized.

**Example**
```julia-repl
julia> fill_in_supports!(x, num_supports = 4)

julia> supports(x)
4-element Array{Number,1}:
 0.0
 0.333
 0.667
 1.0

```
"""
function fill_in_supports!(pref::IndependentParameterRef;
                           num_supports::Int = DefaultNumSupports,
                           modify::Bool = true)::Nothing
    domain = infinite_domain(pref)
    current_amount = length(_parameter_supports(pref))
    if (modify || current_amount == 0) && current_amount < num_supports
        generate_and_add_supports!(pref, domain,
                                   num_supports = num_supports - current_amount,
                                   adding_extra = (current_amount > 0))
    end
    return
end

"""
    generate_and_add_supports!(pref::IndependentParameterRef,
                               domain::AbstractInfiniteDomain,
                               [method::Type{<:AbstractSupportLabel}];
                               [num_supports::Int = DefaultNumSupports])::Nothing

Generate supports for independent parameter `pref` via [`generate_support_values`](@ref)
and add them to `pref`. This is intended as an extendable internal method for
[`fill_in_supports!`](@ref fill_in_supports!(::IndependentParameterRef)).
Most extensions that empoy user-defined infinite domains can typically enable this
by extending [`generate_support_values`](@ref). Errors if the infinite domain type
is not recognized.
"""
function generate_and_add_supports!(pref::IndependentParameterRef,
                                    domain::AbstractInfiniteDomain;
                                    num_supports::Int = DefaultNumSupports,
                                    adding_extra::Bool = false)::Nothing
    sig_digits = significant_digits(pref)
    if isa(domain, IntervalDomain) && adding_extra
        supports, label = generate_support_values(domain, MCSample,
                                                  num_supports = num_supports,
                                                  sig_digits = sig_digits)
    else
        supports, label = generate_supports(domain,
                                            num_supports = num_supports,
                                            sig_digits = sig_digits)
    end
    add_supports(pref, supports, label = label)
    return
end

# Dispatch with method 
function generate_and_add_supports!(pref::IndependentParameterRef,
                                    domain::AbstractInfiniteDomain,
                                    method::Type{<:AbstractSupportLabel};
                                    num_supports::Int = DefaultNumSupports,
                                    adding_extra::Bool = false)::Nothing
    sig_digits = significant_digits(pref)
    supports, label = generate_supports(domain, method,
                                        num_supports = num_supports,
                                        sig_digits = sig_digits)
    add_supports(pref, supports, label = label)
    return
end