library(mvtnorm)

#function that supports probeventbeforecensoring

integrand.censoring=function(c, hazard.c, hazard.e)
{
  
  return(pexp(c, hazard.e)*dexp(c, hazard.c))
  
}

#calls integrand.censoring,  uses numerical integration to determine the probability of an event occuring before a censoring 
#by time t when the hazards of each are respectively hazard.c and hazard.e

probeventbeforecensoring=function(t, hazard.c, hazard.e)
{
  
  prob=integrate(integrand.censoring, lower=0, upper=t, hazard.c=hazard.c, hazard.e=hazard.e)$value
  
  return(prob+pexp(t, hazard.e)*(1-pexp(t, hazard.c)))
}
probeventbeforecensoring=Vectorize(probeventbeforecensoring, vectorize.args="t")


#correlation.logrank.new finds the correlation between the interim and final log-rank test taking into account
#follow-up time and recruitment rate
#Arguments:
#K - number of experimental arms
#n1.perarm: number of patients recruited in first stage per arm
#n2: number of patients recruited per arm in the second stage
#interimanalysisfollowup: minimum amount of time that first stage patients are followed up for before interim analysis
#recruitmentrate: number of patients per year recruited
#recruitment rate - number of patients recruited per year
#followuptime: minimum amount of time that patients are followed for
#hazard.null: event hazard parameter under the null hypothesis
#hazard.true: true event hazard parameter
#hazard.censoring: true censoring hazard parameter

#Returns covariance and correlation matrices as a list

correlation.logrank.new=function(K, n1.perarm=20, n2=20, interimanalysisfollowup=0, recruitmentrate=50, followuptime=2, hazard.null=1, hazard.true=1, hazard.censoring=1)
{
  #interimanalysis is done when all stage 1 patients have been recruited and followed up for interimanalysisfollowup time
  
  #find expected number of events per arm by first interim
  
  
  enrollmenttimes.stage1=seq(0, length=n1.perarm*K, by=1/recruitmentrate)
  
  interimanalysistime=enrollmenttimes.stage1[length(enrollmenttimes.stage1)]+interimanalysisfollowup
  
  #prob.event by interim
  
  prob.event.interim=probeventbeforecensoring(interimanalysistime-enrollmenttimes.stage1, hazard.true, hazard.censoring)
  #need to determine the probability of the event occuring before the censoring time
  
  #find number of expected events in one arm
  exp.event.interim=sum(prob.event.interim[seq(1, n1.perarm*K, by=K)])
  
  #second stage enrollment:
  enrollmenttimes.stage2=seq(interimanalysistime, length=n2, by=1/recruitmentrate)
  finalanalysistime=enrollmenttimes.stage2[length(enrollmenttimes.stage2)]+followuptime
  
  prob.event.final=probeventbeforecensoring(finalanalysistime-c(enrollmenttimes.stage1[seq(1, n1.perarm*K, by=K)], enrollmenttimes.stage2), hazard.true, hazard.censoring)
  exp.event.final=sum(prob.event.final)
  
  cov=matrix(c(exp.event.interim, exp.event.interim, exp.event.interim, exp.event.final), 2, 2)
 
  return(list(cov=cov, cor=cov2cor(cov)))
}



typeIerrorrate=function(criticalvalue, cov, K, requiredtypeIerrorrate)
{
 #find prob of rejecting hypothesis 1 similar in notation to Wason et al,  SMMR 2017:
  #A is a matrix used to transform the vector of normal test statistics
  
  #test statistic must be better than all others at interim,  and then better than critical value at end
  A=matrix(0, K, 2*K)
  for(i in 1:(K-1))
  A[1:(K-1), 1]=1
  A[1:(K-1), (2:K)]=diag(-1, (K-1))
  
  A[K, K+1]=1
  
  mean.transform=as.double(A%*%rep(0, 2*K))
  cov.transform=A%*%cov%*%t(A)
  
  return(K*as.double(pmvnorm(lower=c(rep(0, K-1), criticalvalue), upper=rep(Inf, K), mean=mean.transform, sigma = cov.transform))-requiredtypeIerrorrate)
  
}

#Arguments as per correlation.logrank,  except:
#hazard.exp is now a vector with hazard for each experimental arm
#requiredfwer is the target family-wise error rate (probability of recommending a treatment when they are all ineffective)
droptheloser=function(K, 
                      hazard.null, shape, 
                      hazard.exp, 
                      hazard.censoring, 
                      followuptime, 
                      n1.perarm, 
                      n2, 
                      requiredfwer, 
                      interimanalysisfollowup, 
                      recruitmentrate)
{
  #get distribution of mean logrank test under global null:
  correlation=correlation.logrank.new(K, n1.perarm, n2, interimanalysisfollowup, recruitmentrate, followuptime, hazard.null, hazard.null, hazard.censoring)$cor[1, 2]
    
  #distribution of test statistics under global null:
  
  mean=rep(0, 2*K)
  
  cov=matrix(0, 2*K, 2*K)
  #divide matrix into blocks:
  cov[1:K, 1:K]=diag(1, K)
  cov[((K+1):(2*K)), ((K+1):(2*K))]=diag(1, K)
  cov[1:K, ((K+1):(2*K))]=diag(correlation, K)
  cov[((K+1):(2*K)), 1:K]=diag(correlation, K)
  
  #search for critical value that gives required family-wise error rate
  criticalvalue=uniroot(f = typeIerrorrate, lower = -2, upper=5, cov=cov, K=K, requiredtypeIerrorrate=requiredfwer)$root
#now use simulation to find power:
  sim=simulation.new(K=K, wei_shape=shape, hazard.null=hazard.null, hazard.exp=hazard.exp, hazard.censoring=hazard.censoring, followuptime=followuptime, n1.perarm=n1.perarm, n2=n2, criticalvalue=criticalvalue, interimanalysisfollowup=interimanalysisfollowup, recruitmentrate=recruitmentrate, niterations=nit)
  rejecth0=sim$r
return(list(rH0= rejecth0 , 
  efwer  = if( sum(hazard.exp == hazard.null) > 1 ) mean(ifelse(rowSums(rejecth0[, which (hazard.exp == hazard.null)]) > 0 ,  1, 0 ) ) else mean( rejecth0[, which (hazard.exp == hazard.null)] ), 
  conjunctive.power  = if (sum(hazard.exp != hazard.null) == 0 ) print(" - ") else {if( sum(hazard.exp != hazard.null) > 1 ) mean( ifelse(rowSums(rejecth0[, which (hazard.exp != hazard.null)]) == length( which (hazard.exp != hazard.null) ),  1, 0 ) ) else mean( rejecth0[, which (hazard.exp != hazard.null)]) }, 
  disjunctive.power = if (sum(hazard.exp != hazard.null) == 0 ) print(" - ") else {if( sum(hazard.exp != hazard.null) > 1 ) mean( ifelse(rowSums(rejecth0[, which (hazard.exp != hazard.null)]) > 0 ,  1, 0 ) ) else mean( rejecth0[, which (hazard.exp != hazard.null)] ) }, 
  selectedarm=sim$sel,  
  stage1.O=sim$stage1.O, stage1.E=sim$stage1.E, stage1.lr1=sim$stage1.lr1, stage1.lr2=sim$stage1.lr2, 
  stage2.O=sim$stage2.O, stage2.E=sim$stage2.E, stage2.lr1=sim$stage2.lr1, stage2.lr2=sim$stage2.lr2))   
  
}


simulation.new=function(K, 
                        hazard.null,  wei_shape , 
                        hazard.exp, 
                        hazard.censoring, 
                        followuptime, 
                        n1.perarm, 
                        n2, 
                        criticalvalue, 
                        interimanalysisfollowup, 
                        recruitmentrate, 
                        niterations)
{
  selected.arm=stage2.O=stage2.E=stage2.lr1=stage2.lr2=rep(0, niterations)
  rejecth0=stage1.O=stage1.E=stage1.lr1=stage1.lr2=matrix(0, niterations, K)
  
  for(iteration in 1:niterations)
  {
    enrollmenttimes.stage1=seq(0, length=n1.perarm*K, by=1/recruitmentrate)
    #interim analysis time is after last patient has been followed up for interimanalysisfollowup
    interimanalysistime=enrollmenttimes.stage1[length(enrollmenttimes.stage1)]+interimanalysisfollowup
   
    #for each arm,  extract event time and type:
    eventtimes.stage1.perarm=matrix(0, n1.perarm, K)
    censoringtimes.stage1.perarm=matrix(0, n1.perarm, K)   ### missing!
    censoringtimes.stage1.perarm.interim=matrix(0, n1.perarm, K)
    enrollmenttimes.stage1.perarm=matrix(0, n1.perarm, K)
    time.stage1.perarm=matrix(0, n1.perarm, K)
    event.stage1.perarm=matrix(0, n1.perarm, K)
    for(k in 1:K)
    { 
      eventtimes.stage1.perarm[, k]=rexp(n1.perarm, hazard.exp[k])
      censoringtimes.stage1.perarm[, k]=rexp(n1.perarm, hazard.censoring)
      enrollmenttimes.stage1.perarm[, k]=enrollmenttimes.stage1[seq(k, length(enrollmenttimes.stage1), by=K)]
      censoringtimes.stage1.perarm.interim[, k]=replace(censoringtimes.stage1.perarm[, k], which((censoringtimes.stage1.perarm[, k]+enrollmenttimes.stage1.perarm[, k])>interimanalysistime), (interimanalysistime-enrollmenttimes.stage1.perarm[, k])[which((censoringtimes.stage1.perarm[, k]+enrollmenttimes.stage1.perarm[, k])>interimanalysistime)])
    #change censoringtimes.stage1 so maximum is interimanalysistime:
    time.stage1.perarm[, k]=ifelse(eventtimes.stage1.perarm[, k]<censoringtimes.stage1.perarm.interim[, k], eventtimes.stage1.perarm[, k], censoringtimes.stage1.perarm.interim[, k])
    event.stage1.perarm[, k]=ifelse(eventtimes.stage1.perarm[, k]<censoringtimes.stage1.perarm.interim[, k], 1, 0)
    }
    
    # the observed and expected event case numbers
    stage1.O[iteration, ]= colSums(event.stage1.perarm )
    stage1.E[iteration, ]= colSums(hazard.null*time.stage1.perarm^wei_shape) # weibull
    
    # the "classical" one-sample log-rank test
    stage1.lr1[iteration, ]= - (stage1.O[iteration, ] - stage1.E[iteration, ]) / sqrt(stage1.E[iteration, ])
    # the "modified" one-sample log-rank test
    stage1.lr2[iteration, ]= -(stage1.O[iteration, ]-stage1.E[iteration, ])/sqrt((stage1.O[iteration, ]+stage1.E[iteration, ])/2)

    #select treatment with maximum test statistic:
    selectedarm=which.max(stage1.lr2[iteration, ])

    enrollmenttimes.stage2=seq(interimanalysistime, length=n2, by=1/recruitmentrate)
    finalanalysistime=enrollmenttimes.stage2[length(enrollmenttimes.stage2)]+followuptime
    eventtimes.stage2=rexp(n2, hazard.exp[selectedarm])
    censoringtimes.stage2=rexp(n2, hazard.censoring)
    censoringtimes.stage2=replace(censoringtimes.stage2, which((censoringtimes.stage2+enrollmenttimes.stage2)>finalanalysistime), (finalanalysistime-enrollmenttimes.stage2)[which((censoringtimes.stage2+enrollmenttimes.stage2)>finalanalysistime)])
    #get censoring times of first stage participants on selected arm:
    
    censoringtimes.stage1.final=replace(censoringtimes.stage1.perarm[, selectedarm], which((censoringtimes.stage1.perarm[, selectedarm]+enrollmenttimes.stage1.perarm[, selectedarm])>finalanalysistime), (finalanalysistime-enrollmenttimes.stage1.perarm[, selectedarm])[which((censoringtimes.stage1.perarm[, selectedarm]+enrollmenttimes.stage1.perarm[, selectedarm])>finalanalysistime)])
    
    time.stage1=ifelse(eventtimes.stage1.perarm[, selectedarm]<censoringtimes.stage1.final, eventtimes.stage1.perarm[, selectedarm], censoringtimes.stage1.final)
    event.stage1=ifelse(eventtimes.stage1.perarm[, selectedarm]<censoringtimes.stage1.final, 1, 0)
    time.stage2=ifelse(eventtimes.stage2<censoringtimes.stage2, eventtimes.stage2, censoringtimes.stage2)
    event.stage2=ifelse(eventtimes.stage2<censoringtimes.stage2, 1, 0)
    time=c(time.stage1, time.stage2)
    event=c(event.stage1, event.stage2)

    # the observed and expected event case numbers
    stage2.O[iteration]=sum(event )
    stage2.E[iteration]= sum(hazard.null*time^wei_shape) # weibull
    # the "classical" one-sample log-rank test
    stage2.lr1[iteration]= - (stage2.O[iteration] - stage2.E[iteration]) / sqrt(stage2.E[iteration])
    # the "modified" one-sample log-rank test
    stage2.lr2[iteration]= -(stage2.O[iteration]-stage2.E[iteration])/sqrt((stage2.O[iteration]+stage2.E[iteration])/2)

  selected.arm[iteration]=selectedarm
  rejecth0[iteration, selectedarm]=ifelse(stage2.lr2[iteration]>criticalvalue, 1, 0)  
  }
  return( list(r=rejecth0, sel=selected.arm,  
               stage1.O=stage1.O, stage1.E=stage1.E, stage1.lr1=stage1.lr1, stage1.lr2=stage1.lr2, 
               stage2.O=stage2.O, stage2.E=stage2.E, stage2.lr1=stage2.lr1, stage2.lr2=stage2.lr2))
}
