test_that("get_description_sf handles basic spending functions without nominal", {
  expect_equal(get_description_sf("none", NULL, NULL), "N/A")
  expect_equal(get_description_sf("asOF", NULL, NULL), "LD-OF")
  expect_equal(get_description_sf("asP", NULL, NULL), "LD-Pocock")
})

test_that("get_description_sf handles HSD and KDM with parameters", {
  expect_equal(get_description_sf("asHSD", 2, NULL), "HSD(2)")
  expect_equal(get_description_sf("asKD", 1.5, NULL), "KDM(1.5)")
})

test_that("get_description_sf handles HSD and KDM with NULL parameters", {
  expect_equal(get_description_sf("asHSD", NULL, NULL), "missing parameter")
  expect_equal(get_description_sf("asKD", NULL, NULL), "missing parameter")
})

test_that("get_description_sf handles nominal spends", {
  result1 <- get_description_sf("asOF", NULL, 0.01)
  expect_match(result1, "nominal spend of 0.01 at IA1")
  result2 <- get_description_sf(sf = "asOF", sfpar = NULL, nominal = c(0.001, 0.001))
  expect_match(result2, "LD-OF, with nominal spends of 0.001, 0.001 at IA1-2")
})
