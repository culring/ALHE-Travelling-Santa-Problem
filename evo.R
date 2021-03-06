source("load_cities.R")
source("NN.R")

generate_population <- function(clusters, dt, mi) {
  n_clusters <- max(clusters)
  P <- list()
  to_sample <- setdiff(1:n_clusters, clusters[1])
  for(i in 1:mi) {
    c.order <- c(clusters[1], sample(to_sample))
    length <- pathLength(NN(clusters, c.order, dt))$length
    P[[i]] <- list(c.order = c.order, length = length)
  }
  
  return (P)
}

basic_reproduce <- function(P, lambda) {
  scores <- sapply(P, function(x){x$length})
  scores <- scores/max(scores)
  scores <- exp(scores)
  scores <- scores / sum(scores)
  
  total <- length(P) + lambda
  R <- sample(P, total, replace = T, prob = scores)
  
  return (R)
}

threshold_reproduce <- function(P, lambda, fi) {
  P_best <- select_n_best(P, fi*length(P))
  total <- length(P) + lambda
  R <- sample(P_best, total, replace = T)
  
  return (R)
}

tourney_reproduce <- function(P, lambda, s) {
  mi <- length(P)
  P_sorted <- select_n_best(P, mi)
  R <- list()
  for(i in 1:(mi+lambda)) {
    tourney <- sample(P_sorted, s, replace = T)
    best <- select_n_best(tourney, 1)[[1]]
    R[[i]] <- best
  } 
  
  return (R)
}

cross <- function(R, X, clusters, dt) {
  C <- list()
  counter <- 1
  organism <- 1
  while(counter <= length(R)) {
    # cross
    if(counter%%2==1 && X[(counter+1)/2]) {
      corder_1 <- R[[counter]]$c.order
      corder_2 <- R[[counter+1]]$c.order
      new_corder <- c(corder_1[1])
      idxs_to_fill <- c()
      used <- c(clusters[1])
      for(i in 2:length(corder_1)) {
        x1 <- corder_1[i]
        x2 <- corder_2[i]
        xs <- c()
        if(!(x1 %in% used)) xs <- c(xs, x1)
        if(!(x2 %in% used)) xs <- c(xs, x2)
        if(length(xs) == 0){
          new_corder <- c(new_corder, NaN)
          idxs_to_fill <- c(idxs_to_fill, i)
        }
        else if(length(xs) == 1) {
          new_corder <- c(new_corder, xs)
          used <- c(used, xs)
        }
        else if(length(xs) == 2) {
          to_choose <- sample(1:2, 1)
          new_corder <- c(new_corder, xs[to_choose])
          used <- c(used, xs[to_choose])
        }
      }
      to_fill <- setdiff(1:max(clusters), used)
      if(length(idxs_to_fill) > 1) new_corder[idxs_to_fill] <- sample(to_fill)
      else new_corder[idxs_to_fill] <- to_fill
      C[[organism]] <- list(c.order = new_corder, length = calculate_length(clusters[1], new_corder, dt)) 
      
      counter <- counter + 2
    }
    else {
      C[[organism]] <- R[[counter]]
      counter <- counter + 1
    }
    organism <- organism + 1
  }
  
  return (C)
}

mutate <- function(C) {
  return (C)
}

succession <- function(P, O) {
  n_elites <- length(P) - length(O)
  if(n_elites > 0){
    new_P <- O
    elite <- select_n_best(P, n_elites)
    counter <- 1
    while(counter <= n_elites) {
      new_P[[length(O) + counter]] <- elite[[counter]]
      counter <- counter + 1
    }
  }
  else {
    P_best <- select_n_best(P, 1)[[1]]
    O_best <- select_n_best(O, length(P)-1)
    new_P <- list(P_best)
    for(i in 2:length(P)) {
      new_P[[i]] <- O_best[[i-1]]
    }
  }
  
  return (new_P)
}

select_n_best <- function(P, n, indices = F) {
  P_scores <- sapply(P, function(x){x$length})
  
  if(!indices) return (P[order(P_scores)[1:n]])
  return (order(P_scores)[1:n])
}

evo <- function(clusters, dt, mi, lambda, pc, reproduce_method = "basic") {
  if(reproduce_method == "basic") reproduce <- basic_reproduce
  else if(reproduce_method == "threshold") reproduce <- function(P, lambda) threshold_reproduce(P, lambda, 0.5)
  else if(reproduce_method == "tourney") reproduce <- function(P, lambda) tourney_reproduce(P, lambda, 3)
  else stop("Invalid reproduce method.")
  
  P <- generate_population(clusters, dt, mi)
  t <- 1
  best <<- P[[1]]
  n_steady_iterations <- 0
  while(T) {
    R <- reproduce(P, lambda)
    X <- sample(c(F,T), (mi+lambda)/2, replace = T, prob = c(1-pc, pc))
    C <- cross(R, X, clusters, dt)
    O <- mutate(C)
    P <- succession(P, O)
    
    current_best <- select_n_best(P, 1)[[1]]
    if(current_best$length < best$length){
      best <<- current_best
      n_steady_iterations <- 0
    }
    else n_steady_iterations <- n_steady_iterations + 1
    print.info(c(t, n_steady_iterations, current_best$length, best$length), logger = "logs/evo.log")
    
    t <- t+1
  }
  
  return (best)
}
