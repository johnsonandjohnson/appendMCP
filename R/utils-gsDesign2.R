utils::globalVariables(c("hr", "event", "info", "info0", "stratum", "time"))

pw_info_dd <- function(
  enroll_rate    = gsDesign2::define_enroll_rate(duration   = c(2, 2, 10),
                                                 rate       = c(3, 6, 9)),
  fail_rate      = tibble::tibble(stratum = "All",
                                  duration       = c(3,  100),
                                  fail_rate      = log(2)/c(9, 18),
                                  hr             = c(0.9, 0.6),
                                  dropout_rate_c = 0.001,
                                  dropout_rate_e = 0.002),
  total_duration = 30,
  ratio          = 1
) {
  tbl_n                                    <- list()
  strata                                   <- unique(enroll_rate$stratum)
  for (s in strata) {
    enroll_rate_s                          <- subset(enroll_rate, stratum == s)
    fail_rate_s                            <- subset(fail_rate, stratum == s)
    fr_change_point                        <- fail_rate_s$duration
    i                                      <- is.finite(fr_change_point)
    fr_change_point                        <-
      c(if (all(i)) utils::head(fr_change_point, -1) else fr_change_point[i],
        max(total_duration) +  1e+06)
    fr_cumsum                              <- cumsum(fr_change_point)
    for (td in total_duration) {
      fr_trunc                             <- fr_cumsum[fr_cumsum < td]
      cum_n                                <- gsDesign2::expected_accrual(
        time        = c(fr_trunc, td),
        enroll_rate = enroll_rate_s
      )
      n                                    <- gsDesign2:::diff_one(cum_n)
      tbl_n[[length(tbl_n) + 1]]           <- data.frame(time    = td,
                                                         t       =
                                                           c(0, fr_trunc),
                                                         stratum = s,
                                                         n       = n)
    }
  }
  tbl_n                                    <- data.table::rbindlist(tbl_n)
  q_e                                      <- ratio/(1 + ratio)
  q_c                                      <- 1 - q_e
  event_list                               <- list()
  for (s in strata) {
    enroll                                 <- subset(enroll_rate, stratum == s)
    enroll_c                               <- within(enroll, rate <- rate * q_c)
    enroll_e                               <- within(enroll, rate <- rate * q_e)
    fail_c                                 <- subset(fail_rate, stratum == s)
    fail_e                                 <-
      within(fail_c, fail_rate <- fail_rate * hr)
    fail_c                                 <-
      within(fail_c,  dropout_rate <- dropout_rate_c)
    fail_e                                 <-
      within(fail_e,  dropout_rate <- dropout_rate_e)
    for (td in total_duration) {
      event_c                              <- gsDesign2::expected_event(
        enroll_rate    = enroll_c,
        fail_rate      = fail_c,
        total_duration = td,
        simple         = FALSE
      )
      event_e                              <- gsDesign2::expected_event(
        enroll_rate    = enroll_e,
        fail_rate      = fail_e,
        total_duration = td,
        simple         = FALSE
      )
      event_c$treatment                    <- "control"
      event_e$treatment                    <- "experimental"
      event                                <- cbind(rbind(event_c, event_e),
                                                    time    = td,
                                                    stratum = s)
      event_list[[length(event_list) + 1]] <- event
    }
  }
  tbl_event                                <- data.table::rbindlist(event_list)
  tbl_event                                <-
    tbl_event[, .(info  = 1/sum(1/event),
                  event = sum(event),
                  hr    = gsDesign2:::last_(fail_rate)/fail_rate[1]),
              by = .(time, stratum,  t)]
  tbl_event[, `:=`(info0, event * q_c * q_e), by = .(time)]
  tbl_event                                <-
    tbl_event[, .(event = sum(event),
                  info0 = sum(info0),
                  info  = sum(info)),
              by = .(time, stratum, t, hr)]
  ans                                      <-
    tbl_event[tbl_n, on = c("time", "stratum", "t")]
  ans                                      <-
    ans[!gsDesign2:::almost_equal(event, 0L),
        .(time, stratum, t, hr, n, event, info, info0)]
  data.table::setorderv(ans, cols = c("time", "stratum"))
  data.table::setDF(ans)
  ans
}

ahr_dd <- function(
  enroll_rate    = gsDesign2::define_enroll_rate(duration = c(2, 2, 10),
                                      rate     = c(3, 6, 9)),
  fail_rate      = tibble::tibble(stratum = "All",
                               duration       = c(3,  100),
                               fail_rate      = log(2)/c(9, 18),
                               hr             = c(0.9, 0.6),
                               dropout_rate_c = 0.001,
                               dropout_rate_e = 0.002),
  total_duration = 30,
  ratio          = 1
) {
  res <- pw_info_dd(enroll_rate    = enroll_rate,
                    fail_rate      = fail_rate,
                    total_duration = total_duration,
                    ratio          = ratio)
  data.table::setDT(res)
  ans <- res[, .(ahr   = exp(sum(log(hr)*event)/sum(event)),
                 event = sum(event),
                 info  = sum(info),
                 info0 = sum(info0)),
             by = "time"]
  data.table::setDF(ans)
  ans
}
