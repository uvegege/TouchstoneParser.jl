using LinearAlgebra: I, Diagonal, diag, inv

# TODO: PSEUDO WAVE, POWER WAVE, TRAVELING WAVE

"""
    z2h(Z)

Converts impedance parameters **Z** to hybrid **H** parameters.

## Arguments
- `Z::Matrix{ComplexF64}`: 2×2 impedance parameter matrix

## Returns
- `Matrix{ComplexF64}`: 2×2 H parameter matrix
"""
function z2h(Z)
    Δ = Z[2,2]
    h11 = (Z[1,1]*Z[2,2] - Z[1,2]*Z[2,1]) / Δ
    h12 = -Z[1,2] / Δ
    h21 = Z[2,1] / Δ
    h22 = 1.0 / Δ
    return [h11 h12; h21 h22]
end

"""
    h2z(H)

Converts hybrid **H** parameters to impedance **Z** parameters.

## Arguments
- `H::Matrix{ComplexF64}`: 2×2 hybrid parameter matrix

## Returns
- `Matrix{ComplexF64}`: 2×2 impedance parameter matrix
"""
function h2z(H)
    Δ = H[2,2]
    z11 = (H[1,1]*H[2,2] - H[1,2]*H[2,1]) / Δ
    z12 = -H[1,2] / Δ
    z21 = H[2,1] / Δ
    z22 = 1.0 / Δ
    return [z11 z12; z21 z22]
end

"""
    s2h(H)

Converts hybrid **S** parameters to impedance **H** parameters.

## Arguments
- `H::Matrix{ComplexF64}`: 2×2 S parameter matrix
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Returns
- `Matrix{ComplexF64}`: 2×2 impedance parameter matrix
"""
function s2h(S, Z0)
    Z = s2z(S, Z0)
    return z2h(Z)
end

"""
    s2h(H)

Converts hybrid **H** parameters to impedance **S** parameters.

## Arguments
- `H::Matrix{ComplexF64}`: 2×2 hybrid parameter matrix
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Returns
- `Matrix{ComplexF64}`: 2×2  matrix
"""
function h2s(H, Z0)
    Z = h2z(H)
    return z2s(Z, Z0)
end

"""
    s2h(H)

Converts hybrid **G** parameters to impedance **S** parameters.

## Arguments
- `H::Matrix{ComplexF64}`: 2×2 hybrid parameter matrix
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Returns
- `Matrix{ComplexF64}`: 2×2 S parameter matrix
"""
function g2s(G, Z0)
    return h2s(inv(G), Z0)
end

"""
    s2g(H)

Converts **S** parameters to **G** parameters.

## Arguments
- `H::Matrix{Complex}`: 2×2 hybrid parameter matrix.
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Returns
- `Matrix{ComplexF64}`: 2×2 S parameter matrix

"""
function s2g(S, Z0)
    return z2h(s2y(S, Z0))
end


"""
    h2g(H)

Converts **H** parameters to **G** parameters.
"""
h2g(H) = inv(H)

"""
    h2g(H)

Converts **G** parameters to **H** parameters.
"""
g2h(H) = h2g(H)

"""
    s2y(S, Z0)

Converts scattering parameters **S** to admittance parameters **Y** in a numerically stable way.

## Arguments
- `S::Matrix{Complex}`: n×n scattering parameter matrix.
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Formula
``
\\[
Y = Z_0^{-1/2} ((I + S) \\ (I - S)) Z_0^{-1/2}
\\]``
"""
function s2y(S, Z0)
    n = size(S, 1)
    Z0d = Diagonal(Z0 isa Number ? fill(sqrt(Z0), n) : sqrt.(Z0))
    invsqrtZ0 = Diagonal(1 ./ diag(Z0d)) 
    X = (I + S) \ (I - S)
    return invsqrtZ0 * X * invsqrtZ0 
end


"""
    y2s(Y, Z0)

Converts admittance parameters **Y** to scattering parameters **S** in a numerically stable way.

## Arguments
- `Y::Matrix{Complex}`: n×n admittance parameter matrix.
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Formula
``
\\[
S = \\left( I + \\sqrt{Z_0} Y \\sqrt{Z_0} \\right)^{-1}
    \\left( I - \\sqrt{Z_0} Y \\sqrt{Z_0} \\right)
\\]``
"""
function y2s(Y, Z0)
    n = size(Y,1)
    Z0d = Z0 isa Number ? Diagonal(fill(Z0,n,)) : Diagonal(Z0)
    sqrtZ0d = sqrt(Z0d)
    A = I - sqrtZ0d * Y * sqrtZ0d
    B = I + sqrtZ0d * Y * sqrtZ0d
    return B \ A 
end


"""
    y2s_alternative(Y, Z0)

Alternative version of `y_to_s` using diagonal scaling factors.

## Arguments
- `Y::Matrix{Complex}`: n×n admittance parameter matrix.
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Formula
``
\\[
S = \\left( Z_0^{-1/2} + Y Z_0^{1/2} \\right)^{-1}
    \\left( Z_0^{-1/2} - Y Z_0^{1/2} \\right)
\\]``
"""
function y2s_alternative(Y, Z0)
    n = size(Y,1)
    Z0d = Diagonal(Z0 isa Number ? fill(sqrt(Z0), n) : sqrt.(Z0))
    invsqrtZ0 = Diagonal(1 ./ diag(Z0d)) 
    return (invsqrtZ0 + Y*Z0d) \ (invsqrtZ0 - Y*Z0d)
end


"""
    s2z(S, Z0)

Converts scattering parameters **S** to impedance parameters **Z** in a numerically stable way.

## Arguments
- `S::Matrix{Complex}`: n×n scattering parameter matrix.
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Formula
``
\\[
Z = Z_0^{1/2} ((I - S) \\ (I + S)) Z_0^{1/2}
\\]``
"""
function s2z(S, Z0)
    n = size(S, 1)
    Z0d = Diagonal(Z0 isa Number ? fill(sqrt(Z0), n) : sqrt.(Z0))
    return Z0d * ((I - S) \ (I + S)) * Z0d 
end


"""
    s2z_alternative(S, Z0)

Conversion from **S** to **Z**.

## Arguments
- `S::Matrix{Complex}`: n×n scattering parameter matrix.
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Formula
``
\\[
Z = Z_0^{1/2} (I + S) / (I - S)  Z_0^{1/2}
\\]``

Better stability than the direct version:

``
\\[
Z = Z_0^{1/2} (I + S) * inv(I - S) Z_0^{1/2}
\\]``

"""
function s2z_alternative(S, Z0)
    n = size(S, 1)
    Z0d = Diagonal(Z0 isa Number ? fill(sqrt(Z0), n) : sqrt.(Z0))
    return Z0d * (I + S) / (I - S) * Z0d
end


"""
    z2s(Z, Z0)

Converts impedance parameters **Z** to scattering parameters **S**.

## Arguments
- `Z::Matrix{Complex}`: n×n impedance parameter matrix.
- `Z0::Number` or `Vector`: Reference characteristic impedance(s).

## Formula
``
\\[
S = \\left( Z Z_0^{-1/2} + Z_0^{1/2} \\right)^{-1}
    \\left( Z Z_0^{-1/2} - Z_0^{1/2} \\right)
\\]``
"""
function z2s(Z, Z0)
    n = size(Z, 1)
    Z0d = Diagonal(Z0 isa Number ? fill(sqrt(Z0), n) : sqrt.(Z0))
    invsqrtZ0 = Diagonal(1 ./ diag(Z0d)) 
    return (Z * invsqrtZ0 + Z0d) \ (Z * invsqrtZ0 - Z0d)
end


# Unstable versions:
function s_to_z_unstable(S, Z0)
    Z0d = Z0 .* I(size(S,1))
    sqrtZ0d = Diagonal(sqrt(Z0d))
    return sqrtZ0d * (I + S) * inv(I - S) * sqrtZ0d
end

function z_to_s_unstable(Z, Z0)
    Z0d = Z0 .* I(size(Z,1))
    return (Z - Z0d) * inv(Z + Z0d)
end

function s_to_y_unstable(S, Z0)
    return inv(s_to_z(S, Z0))
end

function y_to_s_unstable(Y, Z0)
    Z0d = Z0 .* I(size(Y,1))
    return z_to_s(inv(Y), Z0d)
end
