#include <Rcpp.h>
#include <algorithm>
#include <map>
#include <vector>
#include <string>
#include <set>
#include <unordered_map>
#include <unordered_set>
using namespace Rcpp;

// Cache for string conversions
thread_local std::unordered_map<SEXP, std::string> string_cache;

inline std::string cached_string(SEXP x) {
  auto it = string_cache.find(x);
  if (it != string_cache.end()) return it->second;
  std::string result = as<std::string>(x);
  string_cache[x] = result;
  return result;
}

// [[Rcpp::export]]
NumericVector sim_pwc_recruitment_cpp(NumericVector rates, NumericVector periods, int n) {
  if (rates.size() == 0 || periods.size() == 0) stop("rates and periods cannot be empty");
  if (n <= 0) stop("n must be positive");
  if (rates.size() != periods.size() - 1) stop("rates must have one fewer element than periods");
  
  std::vector<double> rec_times;
  rec_times.reserve(n);
  int n_count = 0;
  
  for (int i = 0; i < rates.size() && n_count < n; i++) {
    double time_current = periods[i];  // Start each period at its boundary
    const double period_end = (i < rates.size() - 1) ? periods[i + 1] : R_PosInf;
    const double rate = rates[i];
    
    if (rate <= 0) continue;
    
    while (n_count < n) {
      const int n_remaining = n - n_count;
      
      if (R_finite(period_end) && time_current >= period_end) break;
      
      int batch_size = R_finite(period_end) ? 
      std::max(1, std::min(n_remaining, static_cast<int>(std::round((period_end - time_current) * rate + 2 * std::sqrt((period_end - time_current) * rate))))) :
        n_remaining;
      
      const NumericVector inter_times = rexp(batch_size, rate);
      double cumsum = 0.0;
      int n_valid = 0;
      
      for (int j = 0; j < batch_size && n_count + n_valid < n; j++) {
        cumsum += inter_times[j];
        const double arrival_time = time_current + cumsum;
        
        if (!R_finite(period_end) || arrival_time <= period_end) {
          rec_times.push_back(arrival_time);
          n_valid++;
        } else break;
      }
      
      if (n_valid == 0) break;
      n_count += n_valid;
      time_current = rec_times[n_count - 1];
      if (n_valid < batch_size) break;
    }
  }
  
  std::sort(rec_times.begin(), rec_times.end());
  return wrap(rec_times);
}


// [[Rcpp::export]]
DataFrame sim_pwc_stratified_recruitment_cpp(DataFrame enroll_rate, int n, 
                                             Nullable<IntegerVector> n_min_per_stratum = R_NilValue,
                                             Nullable<IntegerVector> n_max_per_stratum = R_NilValue) {
  if (n <= 0) stop("n must be positive");
  
  const CharacterVector strata = enroll_rate["stratum"];
  const NumericVector rates = enroll_rate["rate"];
  const NumericVector durations = enroll_rate["duration"];
  const CharacterVector unique_strata = unique(strata);
  
  if (unique_strata.size() == 1) {
    NumericVector periods(rates.size() + 1);
    periods[0] = 0;
    for (int i = 0; i < rates.size(); i++) periods[i + 1] = periods[i] + durations[i];
    
    const NumericVector rec_times = sim_pwc_recruitment_cpp(rates, periods, n);
    return DataFrame::create(_["Si"] = CharacterVector(rec_times.size(), unique_strata[0]), _["Ri"] = rec_times);
  }
  
  std::vector<std::string> strata_strings(strata.size());
  std::vector<std::string> unique_strata_strings(unique_strata.size());
  for (int i = 0; i < strata.size(); i++) strata_strings[i] = cached_string(strata[i]);
  for (int i = 0; i < unique_strata.size(); i++) unique_strata_strings[i] = cached_string(unique_strata[i]);
  
  std::unordered_map<std::string, int> min_constraints, max_constraints;
  for (const auto& stratum : unique_strata_strings) {
    min_constraints[stratum] = 0;
    max_constraints[stratum] = n;
  }
  
  if (n_min_per_stratum.isNotNull()) {
    const IntegerVector min_vec = n_min_per_stratum.get();
    const CharacterVector min_names = min_vec.names();
    for (int i = 0; i < min_vec.size(); i++) {
      min_constraints[cached_string(min_names[i])] = min_vec[i];
    }
  }
  
  if (n_max_per_stratum.isNotNull()) {
    const IntegerVector max_vec = n_max_per_stratum.get();
    const CharacterVector max_names = max_vec.names();
    for (int i = 0; i < max_vec.size(); i++) {
      max_constraints[cached_string(max_names[i])] = max_vec[i];
    }
  }
  
  int total_min = 0, total_max = 0;
  for (const auto& pair : min_constraints) {
    total_min += pair.second;
    total_max += max_constraints[pair.first];
  }
  if (n < total_min) stop("Total n is less than sum of minimum stratum sizes");
  if (n > total_max) stop("Total n exceeds sum of maximum stratum sizes");
  
  std::vector<std::pair<double, std::string>> all_patients;
  all_patients.reserve(n * 1.2);
  
  for (const auto& stratum_name : unique_strata_strings) {
    std::vector<double> stratum_rates, stratum_durations;
    for (int i = 0; i < strata.size(); i++) {
      if (strata_strings[i] == stratum_name) {
        stratum_rates.push_back(rates[i]);
        stratum_durations.push_back(durations[i]);
      }
    }
    
    NumericVector s_periods(stratum_rates.size() + 1);
    s_periods[0] = 0;
    for (size_t i = 0; i < stratum_rates.size(); i++) {
      s_periods[i + 1] = s_periods[i] + stratum_durations[i];
    }
    
    const int n_simulate = std::min(static_cast<int>(1.2 * max_constraints[stratum_name]), n);
    const NumericVector rec_times = sim_pwc_recruitment_cpp(wrap(stratum_rates), s_periods, n_simulate);
    
    for (int i = 0; i < rec_times.size(); i++) {
      all_patients.emplace_back(rec_times[i], stratum_name);
    }
  }
  
  std::sort(all_patients.begin(), all_patients.end());
  
  std::unordered_map<std::string, int> stratum_counts;
  for (const auto& stratum : unique_strata_strings) stratum_counts[stratum] = 0;
  
  std::vector<double> selected_times;
  std::vector<std::string> selected_strata;
  selected_times.reserve(n);
  selected_strata.reserve(n);
  
  for (const auto& patient : all_patients) {
    if (static_cast<int>(selected_times.size()) >= n) break;
    
    const std::string& stratum = patient.second;
    if (stratum_counts[stratum] < max_constraints[stratum]) {
      selected_times.push_back(patient.first);
      selected_strata.push_back(stratum);
      stratum_counts[stratum]++;
    }
  }
  
  return DataFrame::create(_["Si"] = wrap(selected_strata), _["Ri"] = wrap(selected_times));
}

// [[Rcpp::export]]
DataFrame sim_pb_randomization_cpp(DataFrame enroll_data, DataFrame enroll_rate) {
  const CharacterVector si = enroll_data["Si"];
  const NumericVector ri = enroll_data["Ri"];
  const int n_patients = si.size();
  
  if (n_patients == 0) stop("enroll_data cannot be empty");
  
  CharacterVector treatments(n_patients);
  const CharacterVector unique_strata = unique(si);
  
  const CharacterVector enroll_strata = enroll_rate["stratum"];
  std::unordered_map<std::string, int> stratum_to_rate_idx;
  for (int i = 0; i < enroll_strata.size(); i++) {
    stratum_to_rate_idx[cached_string(enroll_strata[i])] = i;
  }
  
  const List treatments_list = enroll_rate["treatments"];
  const IntegerVector block_sizes = enroll_rate["block_size"];
  const List allocation_ratios = enroll_rate["allocation_ratio"];
  
  for (int s = 0; s < unique_strata.size(); s++) {
    const std::string stratum_name = cached_string(unique_strata[s]);
    
    std::vector<int> stratum_indices;
    stratum_indices.reserve(n_patients / unique_strata.size() + 10);
    for (int i = 0; i < n_patients; i++) {
      if (cached_string(si[i]) == stratum_name) {
        stratum_indices.push_back(i);
      }
    }
    
    auto it = stratum_to_rate_idx.find(stratum_name);
    if (it == stratum_to_rate_idx.end()) continue;
    const int rate_idx = it->second;
    
    const CharacterVector stratum_treatments = treatments_list[rate_idx];
    const int block_size = block_sizes[rate_idx];
    const NumericVector allocation_ratio = allocation_ratios[rate_idx];
    
    double ratio_sum = std::accumulate(allocation_ratio.begin(), allocation_ratio.end(), 0.0);
    if (ratio_sum <= 0) stop("Allocation ratios must sum to positive value");
    
    const int n_stratum = stratum_indices.size();
    const int n_complete_blocks = n_stratum / block_size;
    const int remainder = n_stratum % block_size;
    
    std::vector<std::string> block_treatments;
    block_treatments.reserve(n_stratum);
    
    std::vector<std::string> treatment_strings(stratum_treatments.size());
    for (int i = 0; i < stratum_treatments.size(); i++) {
      treatment_strings[i] = cached_string(stratum_treatments[i]);
    }
    
    for (int b = 0; b < n_complete_blocks; b++) {
      std::vector<std::string> block;
      block.reserve(block_size);
      
      for (int t = 0; t < static_cast<int>(treatment_strings.size()); t++) {
        const int n_this_treatment = static_cast<int>(allocation_ratio[t] * block_size / ratio_sum);
        for (int i = 0; i < n_this_treatment; i++) {
          block.push_back(treatment_strings[t]);
        }
      }
      
      while (static_cast<int>(block.size()) < block_size) block.push_back(treatment_strings[0]);
      block.resize(block_size);
      
      for (int i = block.size() - 1; i > 0; i--) {
        const int j = static_cast<int>(R::runif(0, 1) * (i + 1));
        std::swap(block[i], block[j]);
      }
      
      block_treatments.insert(block_treatments.end(), block.begin(), block.end());
    }
    
    if (remainder > 0) {
      std::vector<std::string> partial_block;
      partial_block.reserve(remainder);
      
      for (int t = 0; t < static_cast<int>(treatment_strings.size()) && static_cast<int>(partial_block.size()) < remainder; t++) {
        const int n_this_treatment = std::min(remainder - static_cast<int>(partial_block.size()), 
                                              std::max(1, static_cast<int>(allocation_ratio[t] * remainder / ratio_sum)));
        for (int i = 0; i < n_this_treatment && static_cast<int>(partial_block.size()) < remainder; i++) {
          partial_block.push_back(treatment_strings[t]);
        }
      }
      
      while (static_cast<int>(partial_block.size()) < remainder) partial_block.push_back(treatment_strings[0]);
      
      for (int i = partial_block.size() - 1; i > 0; i--) {
        const int j = static_cast<int>(R::runif(0, 1) * (i + 1));
        std::swap(partial_block[i], partial_block[j]);
      }
      
      block_treatments.insert(block_treatments.end(), partial_block.begin(), partial_block.end());
    }
    
    for (size_t i = 0; i < stratum_indices.size(); i++) {
      treatments[stratum_indices[i]] = block_treatments[i];
    }
  }
  
  return DataFrame::create(_["Si"] = si, _["Ri"] = ri, _["Ti"] = treatments);
}

inline bool is_stratum_included(const std::string& stratum, const Nullable<CharacterVector>& strata) {
  if (strata.isNull()) return true;
  const CharacterVector strata_vec = strata.get();
  return std::find(strata_vec.begin(), strata_vec.end(), stratum) != strata_vec.end();
}

// [[Rcpp::export]]
int events_at_time_cpp(DataFrame df, double time, std::string ep, Nullable<CharacterVector> strata = R_NilValue) {
  const CharacterVector si = df["Si"];
  const IntegerVector di = df[ep + ": Di"];
  const NumericVector ai = df[ep + ": Ai"];
  
  int count = 0;
  for (int i = 0; i < si.size(); i++) {
    if (is_stratum_included(cached_string(si[i]), strata) && di[i] == 1 && ai[i] <= time) {
      count++;
    }
  }
  return count;
}

// [[Rcpp::export]]
double time_at_events_cpp(DataFrame df, int events, std::string ep, Nullable<CharacterVector> strata = R_NilValue) {
  const CharacterVector si = df["Si"];
  const IntegerVector di = df[ep + ": Di"];
  const NumericVector ai = df[ep + ": Ai"];
  
  std::vector<double> event_times;
  event_times.reserve(si.size());
  
  for (int i = 0; i < si.size(); i++) {
    if (is_stratum_included(cached_string(si[i]), strata) && di[i] == 1) {
      event_times.push_back(ai[i]);
    }
  }
  
  if (event_times.empty() || events <= 0) return NA_REAL;
  
  std::sort(event_times.begin(), event_times.end());
  const int idx = std::min(events - 1, static_cast<int>(event_times.size()) - 1);
  return event_times[idx];
}

// [[Rcpp::export]]
int recruited_at_time_cpp(DataFrame df, double time, Nullable<CharacterVector> strata = R_NilValue) {
  const CharacterVector si = df["Si"];
  const NumericVector ri = df["Ri"];
  
  int count = 0;
  for (int i = 0; i < si.size(); i++) {
    if (is_stratum_included(cached_string(si[i]), strata) && ri[i] <= time) {
      count++;
    }
  }
  return count;
}

// [[Rcpp::export]]
double time_at_recruited_cpp(DataFrame df, int recruited, Nullable<CharacterVector> strata = R_NilValue) {
  const CharacterVector si = df["Si"];
  const NumericVector ri = df["Ri"];
  
  std::vector<double> recruitment_times;
  recruitment_times.reserve(si.size());
  
  for (int i = 0; i < si.size(); i++) {
    if (is_stratum_included(cached_string(si[i]), strata)) {
      recruitment_times.push_back(ri[i]);
    }
  }
  
  if (recruitment_times.empty() || recruited <= 0) return NA_REAL;
  
  std::sort(recruitment_times.begin(), recruitment_times.end());
  const int idx = std::min(recruited - 1, static_cast<int>(recruitment_times.size()) - 1);
  return recruitment_times[idx];
}

// [[Rcpp::export]]
int responses_at_time_cpp(DataFrame df, double time, std::string ep, Nullable<CharacterVector> strata = R_NilValue) {
  const CharacterVector si = df["Si"];
  const NumericVector yi = df[ep + ": Yi"];
  const NumericVector ai = df[ep + ": Ai"];
  
  int count = 0;
  for (int i = 0; i < si.size(); i++) {
    if (is_stratum_included(cached_string(si[i]), strata) && ai[i] <= time) {
      count += static_cast<int>(yi[i]);
    }
  }
  return count;
}

// [[Rcpp::export]]
double time_at_responses_cpp(DataFrame df, int responses, std::string ep, Nullable<CharacterVector> strata = R_NilValue) {
  const CharacterVector si = df["Si"];
  const NumericVector yi = df[ep + ": Yi"];
  const NumericVector ai = df[ep + ": Ai"];
  
  std::vector<double> response_times;
  response_times.reserve(si.size());
  
  for (int i = 0; i < si.size(); i++) {
    if (is_stratum_included(cached_string(si[i]), strata) && yi[i] == 1) {
      response_times.push_back(ai[i]);
    }
  }
  
  if (response_times.empty() || responses <= 0) return NA_REAL;
  
  std::sort(response_times.begin(), response_times.end());
  const int idx = std::min(responses - 1, static_cast<int>(response_times.size()) - 1);
  return response_times[idx];
}

// [[Rcpp::export]]
NumericVector test_pooled_proportions_cpp(DataFrame df, std::string endpoint, CharacterVector strata, std::string control, std::string test) {
  const CharacterVector si = df["Si"];
  const CharacterVector ti = df["Ti"];
  const NumericVector yi = df[endpoint + ": Yi"];
  
  std::unordered_set<std::string> strata_set;
  for (int i = 0; i < strata.size(); i++) {
    strata_set.insert(cached_string(strata[i]));
  }
  
  int n_control = 0, n_test = 0, x_control = 0, x_test = 0;
  for (int i = 0; i < si.size(); i++) {
    const std::string stratum = cached_string(si[i]);
    const std::string treatment = cached_string(ti[i]);
    
    if (strata_set.count(stratum) && (treatment == control || treatment == test) && !NumericVector::is_na(yi[i])) {
      if (treatment == control) {
        n_control++;
        x_control += static_cast<int>(yi[i]);
      } else {
        n_test++;
        x_test += static_cast<int>(yi[i]);
      }
    }
  }
  
  if (n_control == 0 || n_test == 0) {
    return NumericVector::create(
      Named("sample_size") = n_control + n_test,
      Named("responses_control") = x_control,
      Named("responses_test") = x_test,
      Named("z_statistic") = NA_REAL,
      Named("effect_estimate") = NA_REAL,
      Named("effect_variance") = NA_REAL
    );
  }
  
  const double p_control = static_cast<double>(x_control) / n_control;
  const double p_test = static_cast<double>(x_test) / n_test;
  const double p_pooled = static_cast<double>(x_control + x_test) / (n_control + n_test);
  const double var_pooled = p_pooled * (1 - p_pooled) * (1.0/n_control + 1.0/n_test);
  const double z_stat = (var_pooled > 0) ? (p_test - p_control) / std::sqrt(var_pooled) : NA_REAL;
  
  return NumericVector::create(
    Named("sample_size") = n_control + n_test,
    Named("responses_control") = x_control,
    Named("responses_test") = x_test,
    Named("z_statistic") = z_stat,
    Named("effect_estimate") = p_test - p_control,
    Named("effect_variance") = var_pooled
  );
}

// [[Rcpp::export]]
NumericVector test_unpooled_proportions_cpp(DataFrame df, std::string endpoint, CharacterVector strata, std::string control, std::string test) {
  const CharacterVector si = df["Si"];
  const CharacterVector ti = df["Ti"];
  const NumericVector yi = df[endpoint + ": Yi"];
  
  std::unordered_set<std::string> strata_set;
  for (int i = 0; i < strata.size(); i++) {
    strata_set.insert(cached_string(strata[i]));
  }
  
  int n_control = 0, n_test = 0, x_control = 0, x_test = 0;
  for (int i = 0; i < si.size(); i++) {
    const std::string stratum = cached_string(si[i]);
    const std::string treatment = cached_string(ti[i]);
    
    if (strata_set.count(stratum) && (treatment == control || treatment == test) && !NumericVector::is_na(yi[i])) {
      if (treatment == control) {
        n_control++;
        x_control += static_cast<int>(yi[i]);
      } else {
        n_test++;
        x_test += static_cast<int>(yi[i]);
      }
    }
  }
  
  if (n_control == 0 || n_test == 0) {
    return NumericVector::create(
      Named("sample_size") = n_control + n_test,
      Named("responses_control") = x_control,
      Named("responses_test") = x_test,
      Named("z_statistic") = NA_REAL,
      Named("effect_estimate") = NA_REAL,
      Named("effect_variance") = NA_REAL
    );
  }
  
  const double p_control = static_cast<double>(x_control) / n_control;
  const double p_test = static_cast<double>(x_test) / n_test;
  const double var_unpooled = (p_control * (1 - p_control) / n_control) + (p_test * (1 - p_test) / n_test);
  const double z_stat = (var_unpooled > 0) ? (p_test - p_control) / std::sqrt(var_unpooled) : NA_REAL;
  
  return NumericVector::create(
    Named("sample_size") = n_control + n_test,
    Named("responses_control") = x_control,
    Named("responses_test") = x_test,
    Named("z_statistic") = z_stat,
    Named("effect_estimate") = p_test - p_control,
    Named("effect_variance") = var_unpooled
  );
}

// [[Rcpp::export]]
NumericVector test_logrank_cpp(DataFrame df, std::string endpoint, CharacterVector strata, std::string control, std::string test) {
  const CharacterVector si = df["Si"];
  const CharacterVector ti = df["Ti"];
  const NumericVector yi = df[endpoint + ": Yi"];
  const IntegerVector di = df[endpoint + ": Di"];
  
  std::unordered_set<std::string> strata_set;
  for (int i = 0; i < strata.size(); i++) {
    strata_set.insert(cached_string(strata[i]));
  }
  
  std::vector<double> times;
  std::vector<int> events;
  std::vector<int> groups;
  
  times.reserve(si.size());
  events.reserve(si.size());
  groups.reserve(si.size());
  
  for (int i = 0; i < si.size(); i++) {
    const std::string stratum = cached_string(si[i]);
    const std::string treatment = cached_string(ti[i]);
    
    if (strata_set.count(stratum) && (treatment == control || treatment == test) && !NumericVector::is_na(yi[i])) {
      times.push_back(yi[i]);
      events.push_back(di[i]);
      groups.push_back(treatment == test ? 1 : 0);
    }
  }
  
  const int n = times.size();
  if (n == 0) {
    return NumericVector::create(
      Named("sample_size") = 0,
      Named("events_control") = 0,
      Named("events_test") = 0,
      Named("z_statistic") = NA_REAL,
      Named("effect_estimate") = NA_REAL,
      Named("effect_variance") = NA_REAL
    );
  }
  
  std::set<double> unique_event_times_set;
  for (int i = 0; i < n; i++) {
    if (events[i] == 1) {
      unique_event_times_set.insert(times[i]);
    }
  }
  const std::vector<double> unique_event_times(unique_event_times_set.begin(), unique_event_times_set.end());
  
  double O1 = 0, E1 = 0, V = 0;
  int total_events_control = 0, total_events_test = 0;
  
  for (const double t : unique_event_times) {
    int d1 = 0, d0 = 0;
    int n1 = 0, n0 = 0;
    
    for (int i = 0; i < n; i++) {
      if (times[i] >= t) {
        if (groups[i] == 1) n1++;
        else n0++;
      }
      if (times[i] == t && events[i] == 1) {
        if (groups[i] == 1) d1++;
        else d0++;
      }
    }
    
    const int d = d1 + d0;
    const int n_total = n1 + n0;
    
    if (d > 0 && n_total > 0) {
      const double e1 = static_cast<double>(n1) * d / n_total;
      const double v = (n_total > 1) ? 
      static_cast<double>(n1) * n0 * d * (n_total - d) / (static_cast<double>(n_total) * n_total * (n_total - 1)) : 0;
      
      O1 += d1;
      E1 += e1;
      V += v;
    }
    
    total_events_test += d1;
    total_events_control += d0;
  }
  
  const double z_stat = (V > 0) ? (E1 - O1) / std::sqrt(V) : 0;
  const double log_hr = (V > 0) ? (O1 - E1) / V : 0;
  const double var_log_hr = (V > 0) ? 1.0 / V : 0;
  
  return NumericVector::create(
    Named("sample_size") = n,
    Named("events_control") = total_events_control,
    Named("events_test") = total_events_test,
    Named("z_statistic") = z_stat,
    Named("effect_estimate") = log_hr,
    Named("effect_variance") = var_log_hr
  );
}

// [[Rcpp::export]]
NumericVector test_stratified_logrank_cpp(DataFrame df, std::string endpoint, CharacterVector strata, std::string control, std::string test) {
  const CharacterVector si = df["Si"];
  const CharacterVector ti = df["Ti"];
  const NumericVector yi = df[endpoint + ": Yi"];
  const IntegerVector di = df[endpoint + ": Di"];
  
  std::unordered_set<std::string> strata_set;
  for (int i = 0; i < strata.size(); i++) {
    strata_set.insert(cached_string(strata[i]));
  }
  
  std::unordered_map<std::string, std::vector<int>> stratum_indices;
  int total_events_control = 0, total_events_test = 0, total_sample = 0;
  
  for (int i = 0; i < si.size(); i++) {
    const std::string stratum = cached_string(si[i]);
    const std::string treatment = cached_string(ti[i]);
    
    if (strata_set.count(stratum) && (treatment == control || treatment == test) && !NumericVector::is_na(yi[i])) {
      stratum_indices[stratum].push_back(i);
      total_sample++;
      
      if (di[i] == 1) {
        if (treatment == control) total_events_control++;
        else total_events_test++;
      }
    }
  }
  
  double total_O1 = 0, total_E1 = 0, total_V = 0;
  
  for (auto& stratum_pair : stratum_indices) {
    const std::vector<int>& indices = stratum_pair.second;
    
    std::set<double> unique_event_times_set;
    for (const int idx : indices) {
      if (di[idx] == 1) {
        unique_event_times_set.insert(yi[idx]);
      }
    }
    const std::vector<double> unique_event_times(unique_event_times_set.begin(), unique_event_times_set.end());
    
    for (const double t : unique_event_times) {
      int d1 = 0, d0 = 0, n1 = 0, n0 = 0;
      
      for (const int idx : indices) {
        const std::string treatment = cached_string(ti[idx]);
        const bool is_test = (treatment == test);
        
        if (yi[idx] >= t) {
          if (is_test) n1++;
          else n0++;
        }
        if (yi[idx] == t && di[idx] == 1) {
          if (is_test) d1++;
          else d0++;
        }
      }
      
      const int d = d1 + d0;
      const int n_total = n1 + n0;
      
      if (n_total > 0 && d > 0) {
        const double e1 = static_cast<double>(n1) * d / n_total;
        const double v = (n_total > 1) ? 
        static_cast<double>(n1) * n0 * d * (n_total - d) / (static_cast<double>(n_total) * n_total * (n_total - 1)) : 0;
        
        total_O1 += d1;
        total_E1 += e1;
        total_V += v;
      }
    }
  }
  
  const double z_stat = (total_V > 0) ? (total_E1 - total_O1) / std::sqrt(total_V) : 0;
  const double log_hr = (total_E1 > 0) ? std::log(total_O1 / total_E1) : 0;
  const double var_log_hr = (total_V > 0) ? 1.0 / total_V : 0;
  
  return NumericVector::create(
    Named("sample_size") = total_sample,
    Named("events_control") = total_events_control,
    Named("events_test") = total_events_test,
    Named("z_statistic") = z_stat,
    Named("effect_estimate") = log_hr,
    Named("effect_variance") = var_log_hr
  );
}

// [[Rcpp::export]]
NumericVector test_cmh_cpp(DataFrame df, std::string endpoint, CharacterVector strata, std::string control, std::string test) {
  const CharacterVector si = df["Si"];
  const CharacterVector ti = df["Ti"];
  const NumericVector yi = df[endpoint + ": Yi"];
  
  std::unordered_set<std::string> strata_set;
  for (int i = 0; i < strata.size(); i++) {
    strata_set.insert(cached_string(strata[i]));
  }
  
  std::unordered_map<std::string, std::vector<std::vector<int>>> stratum_tables;
  int total_responses_control = 0, total_responses_test = 0, total_sample = 0;
  
  for (int s = 0; s < strata.size(); s++) {
    const std::string stratum = cached_string(strata[s]);
    stratum_tables[stratum] = std::vector<std::vector<int>>(2, std::vector<int>(2, 0));
  }
  
  for (int i = 0; i < si.size(); i++) {
    const std::string patient_stratum = cached_string(si[i]);
    const std::string treatment = cached_string(ti[i]);
    
    if (strata_set.count(patient_stratum) && (treatment == control || treatment == test) && !NumericVector::is_na(yi[i])) {
      total_sample++;
      const int response = static_cast<int>(yi[i]);
      const int treatment_idx = (treatment == test) ? 1 : 0;
      
      stratum_tables[patient_stratum][response][treatment_idx]++;
      
      if (response == 1) {
        if (treatment_idx == 0) total_responses_control++;
        else total_responses_test++;
      }
    }
  }
  
  double cmh_num = 0, cmh_den = 0;
  
  for (auto& table_pair : stratum_tables) {
    const std::vector<std::vector<int>>& table = table_pair.second;
    
    const int a = table[1][1];
    const int b = table[1][0];
    const int c = table[0][1];
    const int d = table[0][0];
    
    const int n = a + b + c + d;
    const int r1 = a + b;
    const int c1 = a + c;
    
    if (n > 0 && r1 > 0 && c1 > 0 && (n - r1) > 0 && (n - c1) > 0) {
      const double expected_a = static_cast<double>(r1) * c1 / n;
      const double var_a = static_cast<double>(r1) * c1 * (n - r1) * (n - c1) / (static_cast<double>(n) * n * (n - 1));
      
      cmh_num += (a - expected_a);
      cmh_den += var_a;
    }
  }
  
  const double z_stat = (cmh_den > 0) ? cmh_num / std::sqrt(cmh_den) : 0;
  
  const double log_or = (total_responses_control > 0 && total_responses_test > 0) ? 
  std::log(static_cast<double>(total_responses_test) / total_responses_control) : 0;
  const double var_log_or = (cmh_den > 0) ? 1.0 / cmh_den : 0;
  
  return NumericVector::create(
    Named("sample_size") = total_sample,
    Named("responses_control") = total_responses_control,
    Named("responses_test") = total_responses_test,
    Named("z_statistic") = z_stat,
    Named("effect_estimate") = log_or,
    Named("effect_variance") = var_log_or
  );
}

// [[Rcpp::export]]
DataFrame cut_data_at_time_cpp(DataFrame df, double time) {
  const CharacterVector si = df["Si"];
  const NumericVector ri = df["Ri"];
  const CharacterVector ti = df["Ti"];
  
  std::vector<int> keep_indices;
  keep_indices.reserve(ri.size());
  for (int i = 0; i < ri.size(); i++) {
    if (ri[i] <= time) {
      keep_indices.push_back(i);
    }
  }
  
  const int n_keep = keep_indices.size();
  CharacterVector si_cut(n_keep);
  NumericVector ri_cut(n_keep);
  CharacterVector ti_cut(n_keep);
  
  for (int i = 0; i < n_keep; i++) {
    const int idx = keep_indices[i];
    si_cut[i] = si[idx];
    ri_cut[i] = ri[idx];
    ti_cut[i] = ti[idx];
  }
  
  DataFrame result = DataFrame::create(
    Named("Si") = si_cut,
    Named("Ri") = ri_cut,
    Named("Ti") = ti_cut
  );
  
  const CharacterVector col_names = df.names();
  for (int c = 0; c < col_names.size(); c++) {
    const std::string col_name = cached_string(col_names[c]);
    
    if (col_name == "Si" || col_name == "Ri" || col_name == "Ti") continue;
    
    if (col_name.find(": Di") != std::string::npos) {
      const std::string ep = col_name.substr(0, col_name.find(":"));
      const std::string ai_col = ep + ": Ai";
      const std::string yi_col = ep + ": Yi";
      
      if (std::find(col_names.begin(), col_names.end(), ai_col) != col_names.end()) {
        const IntegerVector di = df[col_name];
        const NumericVector ai = df[ai_col];
        const NumericVector yi = df[yi_col];
        
        IntegerVector di_cut(n_keep);
        NumericVector yi_cut(n_keep);
        LogicalVector aci_cut(n_keep);
        
        for (int i = 0; i < n_keep; i++) {
          const int idx = keep_indices[i];
          const bool admin_censored = ai[idx] > time;
          aci_cut[i] = admin_censored;
          di_cut[i] = admin_censored ? 0 : di[idx];
          yi_cut[i] = admin_censored ? (time - ri[idx]) : yi[idx];
        }
        
        result[col_name] = di_cut;
        result[yi_col] = yi_cut;
        result[ep + ": ACi"] = aci_cut;
      }
    }
    else if (col_name.find(": Yi") != std::string::npos && 
             col_name.find(": Di") == std::string::npos &&
             col_name.find(": Ei") == std::string::npos &&
             col_name.find(": Ci") == std::string::npos) {
      const std::string ep = col_name.substr(0, col_name.find(":"));
      const std::string ai_col = ep + ": Ai";
      
      if (std::find(col_names.begin(), col_names.end(), ai_col) != col_names.end()) {
        const NumericVector yi = df[col_name];
        const NumericVector ai = df[ai_col];
        
        NumericVector yi_cut(n_keep);
        for (int i = 0; i < n_keep; i++) {
          const int idx = keep_indices[i];
          yi_cut[i] = (ai[idx] > time) ? NA_REAL : yi[idx];
        }
        result[col_name] = yi_cut;
      }
    }
    else if (col_name.find(":") != std::string::npos) {
      if (TYPEOF(df[col_name]) == REALSXP) {
        const NumericVector orig = df[col_name];
        NumericVector cut(n_keep);
        for (int i = 0; i < n_keep; i++) {
          cut[i] = orig[keep_indices[i]];
        }
        result[col_name] = cut;
      } else if (TYPEOF(df[col_name]) == INTSXP) {
        const IntegerVector orig = df[col_name];
        IntegerVector cut(n_keep);
        for (int i = 0; i < n_keep; i++) {
          cut[i] = orig[keep_indices[i]];
        }
        result[col_name] = cut;
      }
    }
  }
  
  return result;
}

// [[Rcpp::export]]
List update_graph_cpp(NumericMatrix edges, NumericVector weights, int rejected) {
  const int n = edges.nrow();
  if (rejected < 1 || rejected > n) stop("Invalid rejected hypothesis index");
  
  const int rej_idx = rejected - 1; // Convert to 0-based indexing
  NumericMatrix new_edges = clone(edges);
  NumericVector new_weights = clone(weights);
  
  for (int i = 0; i < n; i++) {
    // Update weight for hypothesis i
    new_weights[i] += new_weights[rej_idx] * edges(rej_idx, i);
    
    // Update edges if condition is met
    if (edges(i, rej_idx) * edges(rej_idx, i) < 1.0) {
      for (int j = 0; j < n; j++) {
        new_edges(i, j) = (edges(i, j) + edges(i, rej_idx) * edges(rej_idx, j)) / 
                         (1.0 - edges(i, rej_idx) * edges(rej_idx, i));
      }
    }
    
    // Diagonal elements always 0
    new_edges(i, i) = 0.0;
  }
  
  // Zero out rejected hypothesis row/column/weight
  for (int i = 0; i < n; i++) {
    new_edges(rej_idx, i) = 0.0;
    new_edges(i, rej_idx) = 0.0;
  }
  new_weights[rej_idx] = 0.0;
  
  return List::create(Named("g") = new_edges, Named("w") = new_weights);
}

// [[Rcpp::export]]
NumericMatrix update_p_thresholds_cpp(DataFrame analyses, DataFrame hypotheses, NumericMatrix edges, NumericVector weights) {
  const int n_hyp = edges.nrow();
  const int n_analyses = analyses.nrow();
  
  NumericMatrix p_thr(n_hyp, n_analyses);
  std::fill(p_thr.begin(), p_thr.end(), -1.0);
  
  const IntegerVector hyp_index = hypotheses["index"];
  const NumericVector possible_weight = hypotheses["possible_weight"];
  const List p_thresholds = hypotheses["p_thresholds"];
  
  for (int j = 0; j < n_hyp; j++) {
    if (weights[j] > 0) {
      // Find matching hypothesis: prefer exact match, fall back to closest possible_weight.
      // The fallback handles hypotheses with zero initial weight that receive weight via
      // propagation — gMCPLite never generates scenarios for them, so no exact row exists.
      int best_h = -1;
      double best_diff = R_PosInf;
      for (int h = 0; h < hyp_index.size(); h++) {
        if (hyp_index[h] == (j + 1)) {
          double diff = std::abs(possible_weight[h] - weights[j]);
          if (diff < best_diff) {
            best_diff = diff;
            best_h = h;
          }
        }
      }
      if (best_h >= 0) {
        const NumericVector p_thr_j = p_thresholds[best_h];
        const int len = std::min(static_cast<int>(p_thr_j.size()), n_analyses);
        for (int a = 0; a < len; a++) {
          p_thr(j, a) = p_thr_j[a];
        }
        if (len > 0) {
          const double last_val = p_thr_j[len - 1];
          for (int a = len; a < n_analyses; a++) {
            p_thr(j, a) = last_val;
          }
        }
      }
    }
  }
  
  return p_thr;
}

// [[Rcpp::export]]
NumericMatrix get_maurer_bretz_z_raw_cpp(NumericVector pvec, DataFrame analyses, DataFrame hypotheses, NumericMatrix edges, NumericVector weights) {
  const IntegerVector hyp_index = hypotheses["index"];
  const List analyses_analysed = hypotheses["analyses_analysed"];
  
  const int J = *std::max_element(hyp_index.begin(), hyp_index.end());
  int K = 0;
  for (int i = 0; i < analyses_analysed.size(); i++) {
    const IntegerVector aa = analyses_analysed[i];
    if (aa.size() > 0) {
      K = std::max(K, *std::max_element(aa.begin(), aa.end()));
    }
  }
  
  // Initialize p_obs matrix
  NumericMatrix p_obs(J, K);
  std::fill(p_obs.begin(), p_obs.end(), NA_REAL);
  
  int count = 0;
  for (int j = 0; j < J; j++) {
    // Find first hypothesis with this index
    int hyp_idx = -1;
    for (int h = 0; h < hyp_index.size(); h++) {
      if (hyp_index[h] == (j + 1)) {
        hyp_idx = h;
        break;
      }
    }
    
    if (hyp_idx >= 0) {
      const IntegerVector aa = analyses_analysed[hyp_idx];
      for (int i = 0; i < aa.size(); i++) {
        if (count < pvec.size()) {
          p_obs(j, aa[i] - 1) = pvec[count++]; // Convert to 0-based indexing
        }
      }
    }
  }
  
  // Forward-fill missing p-values
  for (int j = 0; j < J; j++) {
    double last_val = NA_REAL;
    for (int k = 0; k < K; k++) {
      if (!NumericVector::is_na(p_obs(j, k))) {
        last_val = p_obs(j, k);
      } else if (!NumericVector::is_na(last_val)) {
        p_obs(j, k) = last_val;
      }
    }
  }
  
  // Initialize rejection matrix and graph state
  NumericMatrix reject_matrix(J, K);
  std::fill(reject_matrix.begin(), reject_matrix.end(), 0.0);
  
  NumericMatrix current_edges = clone(edges);
  NumericVector current_weights = clone(weights);
  std::vector<int> set_J;
  for (int j = 0; j < J; j++) {
    set_J.push_back(j);
  }
  
  // Sequential testing procedure
  for (int k = 0; k < K; k++) {
    bool no_rejections = false;
    
    while (!no_rejections && !set_J.empty()) {
      no_rejections = true;
      std::vector<int> revised_J;
      
      NumericMatrix p_thr = update_p_thresholds_cpp(analyses, hypotheses, current_edges, current_weights);
      
      for (int j : set_J) {
        if (!NumericVector::is_na(p_obs(j, k)) && p_obs(j, k) < p_thr(j, k)) {
          // Mark rejection for this and all subsequent analyses
          for (int kk = k; kk < K; kk++) {
            reject_matrix(j, kk) = 1.0;
          }
          
          // Update graph
          List updated = update_graph_cpp(current_edges, current_weights, j + 1);
          current_edges = as<NumericMatrix>(updated["g"]);
          current_weights = as<NumericVector>(updated["w"]);
          
          no_rejections = false;
        } else {
          revised_J.push_back(j);
        }
      }
      
      set_J = revised_J;
    }
  }
  
  return reject_matrix;
}

// [[Rcpp::export]]
DataFrame calculate_analysis_timing_cpp(DataFrame df, DataFrame analyses, DataFrame hypotheses) {
  const CharacterVector endpoints = analyses["endpoint"];
  const List strata_list = analyses["strata"];
  const NumericVector sample_sizes = analyses["sample_size"];
  const NumericVector events = analyses["events"];
  
  const CharacterVector hyp_endpoints = hypotheses["endpoint"];
  const NumericVector hyp_maturity = hypotheses["maturity_time"];
  
  const int n_analyses = endpoints.size();
  NumericVector analysis_times(n_analyses);
  List df_list(n_analyses);
  
  for (int a = 0; a < n_analyses; a++) {
    const std::string ep = cached_string(endpoints[a]);
    const CharacterVector strata = strata_list[a];
    
    double analysis_time = NA_REAL;
    
    if (!NumericVector::is_na(sample_sizes[a])) {
      const int ss = static_cast<int>(sample_sizes[a]);
      
      // Check if this endpoint has maturity_time (binary endpoint)
      double maturity_time = 0.0;
      bool has_maturity = false;
      for (int h = 0; h < hyp_endpoints.size(); h++) {
        if (cached_string(hyp_endpoints[h]) == ep && !NumericVector::is_na(hyp_maturity[h])) {
          maturity_time = hyp_maturity[h];
          has_maturity = true;
          break;
        }
      }
      
      const double recruit_time = time_at_recruited_cpp(df, ss, strata);
      analysis_time = has_maturity && R_finite(recruit_time) ? recruit_time + maturity_time : recruit_time;
      
    } else if (!NumericVector::is_na(events[a])) {
      const int ev = static_cast<int>(events[a]);
      analysis_time = time_at_events_cpp(df, ev, ep, strata);
    }
    
    analysis_times[a] = analysis_time;
    df_list[a] = cut_data_at_time_cpp(df, analysis_time);
  }
  
  DataFrame result = clone(analyses);
  result["analysis_time"] = analysis_times;
  result["df"] = df_list;
  
  return result;
}
