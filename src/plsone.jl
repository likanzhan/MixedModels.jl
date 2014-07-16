## Default methods, overridden for PLSOne

Base.cholfact(s::PLSSolver,RX::Bool=true) = RX ? s.RX : s.L
Base.logdet(s::PLSSolver,RX::Bool=true) = logdet(cholfact(s,RX))

type PLSOne <: PLSSolver   # Solver for models with a single random-effects term
    Ad::Array{Float64,3}                # diagonal blocks
    Ab::Array{Float64,3}                # base blocks
    At::Symmetric{Float64}              # lower right block
    Ld::Array{Float64,3}                # diagonal blocks
    Lb::Array{Float64,3}                # base blocks
    Lt::Base.LinAlg.Cholesky{Float64}   # lower right triangle
    Zt::SparseMatrixCSC
end

function PLSOne(Ad::Array{Float64,3}, Ab::Array{Float64,3}, At::Symmetric{Float64},Zt::SparseMatrixCSC)
    m,n,t = size(Ad)
    m == n || error("Faces of Ad must be square")
    p,q,r = size(Ab)
    p == size(At,1) && q == n && r == t || error("Size mismatch")
    PLSOne(Ad,Ab,At,zeros(Ad),zeros(Ab),cholfact(At.S,symbol(At.uplo)),Zt)
end

function PLSOne(Ad::Array{Float64,3}, Ab::Array{Float64,3}, At::Matrix{Float64}, Zt::SparseMatrixCSC)
    PLSOne(Ad,Ab,Symmetric(At,:L),Zt)
end

function PLSOne(ff::PooledDataVector, Xst::Matrix, Xt::Matrix)
    refs = ff.refs
    (L = length(refs)) == size(Xst,2) == size(Xt,2) || throw(DimensionMismatch("PLSOne"))
    m = size(Xt,1)
    n = size(Xst,1)
    nl = length(ff.pool)         # number of levels of grouping factor
    Ad = zeros(n,n,nl)
    Ab = zeros(m,n,nl)
    for j in 1:L
        jj = refs[j]
        BLAS.syr!('L',1.0,view(Xst,:,j),view(Ad,:,:,jj))
        BLAS.ger!(1.0,view(Xt,:,j),view(Xst,:,j),view(Ab,:,:,jj))
    end
    for j in 1:nl        # symmetrize the faces created with BLAS.syr!
        Base.LinAlg.copytri!(view(Ad,:,:,j),'L')
    end
    PLSOne(Ad,Ab,Symmetric(Xt*Xt',:L),ztblk(Xst,refs))
end

Base.cholfact(s::PLSOne,RX::Bool=true) = RX ? s.Lt : blkdiag({sparse(tril(view(s.Ld,:,:,j))) for j in 1:size(s.Ld,3)}...)

## Logarithm of the determinant of the matrix represented by RX or L
function Base.logdet(s::PLSOne,RX=true)
    RX && return logdet(s.Lt)
    Ld = s.Ld
    m,n,t = size(Ld)
    s = 0.
    @inbounds for j in 1:t, i in 1:m
        s += log(Ld[i,i,j])
    end
    2.s
end

Base.size(s::PLSOne) = size(s.Ab)
Base.size(s::PLSOne,k::Integer) = size(s.Ab,k)

##  update!(s,lambda)->s : update Ld, Lb and Lt

function update!(s::PLSOne,λ::AbstractMatrix)
    updateLdb!(s,λ)         # updateLdb! is common to PLSOne and PLSTwo
    m,n,l = size(s.Ab)
    BLAS.syrk!('L','N',-1.0,reshape(s.Lb,(m,n*l)),1.0,s.Lt.UL)
    _, info = LAPACK.potrf!('L',s.Lt.UL)
    info == 0 ||  error("downdated X'X is not positive definite")
    s
end

function update!(s::PLSOne,λ::Vector)
    length(λ) == 1 || error("update! on a PLSOne requires length(λ) == 1")
    update!(s,λ[1])
end

## arguments passed contain λ'Z'y and X'y
function plssolve!(s::PLSOne,u::Vector,β)
    length(u) == 1 || error("length(u) = $(length(u)), should be 1 for PLSOne")
    p,k,l = size(s)
    cu = u[1]
    (q = length(cu)) == k*l && k == size(cu,1) || throw(DimensionMismatch(""))
    if k == 1                           # short cut for scalar r.e.
        Linv = 1. ./ vec(s.Ld)
        scale!(cu,Linv)
        LXZ = reshape(s.Lb,(p,k*l))
        A_ldiv_B!(s.Lt,BLAS.gemv!('N',-1.,LXZ,vec(cu),1.,β)) # solve for β
        BLAS.gemv!('T',-1.,LXZ,β,1.0,vec(cu)) # cu -= LZX'β
        scale!(cu,Linv)
    else
        for j in 1:l                    # solve L cᵤ = λ'Z'y blockwise
            BLAS.trsv!('L','N','N',view(s.Ld,:,:,j),view(cu,:,j))
        end
                                        # solve (L_X L_X')̱β = X'y - L_XZ cᵤ
        A_ldiv_B!(s.Lt,BLAS.gemv!('N',-1.0,reshape(s.Lb,(p,q)),vec(cu),1.0,β))
                                        # cᵤ := cᵤ - L_XZ'β
        BLAS.gemv!('T',-1.0,reshape(s.Lb,(p,q)),β,1.0,vec(cu))
        for j in 1:l                    # solve L'u = cᵤ blockwise
            BLAS.trsv!('L','T','N',view(s.Ld,:,:,j),view(cu,:,j))
        end
    end
end

function grad(s::PLSOne,sc,resid,u,λ::Vector)
    λ = λ[1]
    u = u[1]
    res = zeros(size(λ))
    tmp = similar(res)                  # scratch array
    for i in 1:size(s.Ad,3)
        add!(res,LAPACK.potrs!('L',view(s.Ld,:,:,i),Ac_mul_B!(λ,copy!(tmp,view(s.Ad,:,:,i)))))
    end
    ltri(BLAS.syr2k!('L','N',-1./sc,reshape(s.Zt*resid,size(u)),u,1.,res+res'))
end