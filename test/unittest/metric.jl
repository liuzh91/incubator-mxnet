module TestMetric

using MXNet
using Base.Test

################################################################################
# Supporting functions
################################################################################

"""
Returns a random n x m array in which each column defines a discrete probability distribution.
Each column contains numbers between 0 and 1, and each column sums to 1.
"""
function generate_probs(n, m)
    # Init
    result = rand(n, m)

    # Normalize: ensure each column sums to 1
    for j = 1:m
        colsum = sum(result[:, j])
        for i = 1:n
            result[i, j] /= colsum
        end
    end
    result
end


function loglikelihood{T <: AbstractFloat}(labels::Vector{T}, probs::Array{T, 2})
    LL = 0.0
    eps = convert(T, 1.0e-8)
    for i = 1:size(labels, 1)
        LL += log(probs[Int(labels[i]) + 1, i] + eps)    # labels are zero-based
    end
    LL / size(labels, 1)
end


################################################################################
# Test Implementations
################################################################################

function test_ace()
    info("EvalMetric::ACE")
    n_categories   = 4
    n_observations = 100
    labels         = convert(Vector{Float32}, rand(0:(n_categories - 1), n_observations))    # MXNet uses Float32
    probs          = convert(Array{Float32}, generate_probs(n_categories, n_observations))
    LL             = loglikelihood(labels, probs)
    metric         = mx.ACE()    # For categorical variables, ACE == -LL
    mx._update_single_output(metric, labels, probs)
    LL_v2 = metric.ace_sum / metric.n_sample
    @static if VERSION >= v"0.6.0-dev.2075"
      @test LL ≈ LL_v2 atol=1e-12
    else
      @test_approx_eq_eps LL LL_v2 1e-12
    end
end


function test_nmse()
    info("EvalMetric::NMSE")

    @testset "EvalMetric::NMSE::update!" begin
        metric = mx.NMSE()
        labels = Array{mx.NDArray}(
            [mx.NDArray([100.0, 0.0]), mx.NDArray([10.0, 0.0])])
        preds = Array{mx.NDArray}(
            [mx.NDArray([20.0, 0.0]), mx.NDArray([2.0, 0.0])])

        mx.update!(metric, labels, preds)
        @test metric.nmse_sum ≈ 0.64 * 2
    end

    @testset "EvalMetric::NMSE::reset!" begin
        metric = mx.NMSE()
        metric.nmse_sum = sum(rand(10))
        metric.n_sample = 42

        mx.reset!(metric)

        @test metric.nmse_sum == 0.0
        @test metric.n_sample == 0
    end

    @testset "EvalMetric::NMSE::get" begin
        metric = mx.NMSE()
        metric.nmse_sum = 100.0
        metric.n_sample = 20

        @test mx.get(metric) == [(:NMSE, 5.0)]
    end
end


################################################################################
# Run tests
################################################################################
test_ace()
test_nmse()


end
