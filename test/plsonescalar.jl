## ML fit to ds

lm1 = lmm(Yield ~ 1 | Batch,ds);

@test typeof(lm1) == LinearMixedModel{PLSOne}
@test size(lm1) == (30,1,6,1)

fit(lm1)

@test_approx_eq_eps MixedModels.θ(lm1) [0.752580] 1.e-5
@test_approx_eq_eps deviance(lm1) 327.32705988 1.e-6
@test_approx_eq fixef(lm1) [1527.5]
@test_approx_eq coef(lm1) [1527.5]
@test_approx_eq_eps ranef(lm1)[1] [-16.62821559262611 0.369515902058292 26.974660850260033 -21.801438221443075 53.57980579846178 -42.494328736711275] 1.e-4
@test_approx_eq_eps ranef(lm1,true)[1] [-22.094942525296847 0.49099872278428663 35.842906763259194 -28.968924644278022 71.1948148037341 -56.46485312020319] 1.e-4
@test_approx_eq_eps std(lm1)[1] [37.26032326416065] 1.e-7
@test_approx_eq_eps std(lm1)[2] [49.510105062667854] 1.e-7
@test_approx_eq_eps logdet(lm1) 2.057840647724494 1.e-8
@test_approx_eq_eps logdet(lm1,false) 8.060140403625967 1.e-8
@test_approx_eq_eps scale(lm1) 49.510105062667854 1.e-7
@test_approx_eq_eps scale(lm1,true) 2451.2505033164093 1.e-3
@test_approx_eq_eps pwrss(lm1) 73537.51509949227 1.e-2
@test_approx_eq_eps stderr(lm1) [17.69454619561742] 1.e-7

## REML fit to ds

#fit(reml!(lm1))

##@test_approx_eq_eps std(lm1)[1] [37.8972980078109] 1.e-9
##@test_approx_eq_eps std(lm1)[2] [50.356492955140524] 1.e-9
##@test_approx_eq fixef(lm1) [1527.5]     # unchanged because of balanced design
##@test_approx_eq coef(lm1) [1527.5]
##@test_approx_eq_eps stderr(lm1) [19.383424615110936] 1.e-10
## @test_approx_eq objective(lm1) 319.6542768422625

## ML fit to ds2

lm2 = fit(lmm(Yield ~ 1|Batch, ds2))

@test_approx_eq deviance(lm2) 162.87303665382575
@test_approx_eq std(lm2)[1] [0.]
@test_approx_eq std(lm2)[2] [3.653231351374652]
@test_approx_eq stderr(lm2) [0.6669857396443261]
@test_approx_eq coef(lm2) [5.6656]
@test_approx_eq logdet(lm2,false) 0.0
@test_approx_eq logdet(lm2) 3.4011973816621555