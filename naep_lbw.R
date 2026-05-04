# Install once if needed:
# install.packages(c("readxl", "readr", "dplyr", "tidyr", "stringr", "janitor", "fixest"))

library(readxl)
library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(janitor)
library(fixest)

# ---------------------------------------------------------
# 0. Helper function to standardize state names
# ---------------------------------------------------------
clean_state <- function(x) {
  x <- str_squish(x)
  x <- str_to_title(x)
  x <- str_replace_all(x, "District Of Columbia", "District of Columbia")
  x
}

# ---------------------------------------------------------
# 1. MAIN FILE: already merged NAEP + low-birthweight counts
# ---------------------------------------------------------
main <- read_excel("C:/Users/HP/Desktop/ULTIMO SEMESTRE CARAJO/Seminar Econ/project2/merged_naep_lbw.xlsx") %>%
  clean_names() %>%
  rename(
    naep_score = naep_score,
    lbw_count = lbw_count
  ) %>%
  mutate(
    state = clean_state(state),
    year = as.integer(year),
    naep_score = as.numeric(naep_score),
    lbw_count = as.numeric(lbw_count)
  ) %>%
  filter(!is.na(state), !is.na(year), !is.na(naep_score), !is.na(lbw_count))

# quick check
names(main)
head(main)

# ---------------------------------------------------------
# 2. TOTAL BIRTHS FILE: to convert LBW count -> LBW rate
# ---------------------------------------------------------
births_raw <- read_csv(
  "C:/Users/HP/Desktop/ULTIMO SEMESTRE CARAJO/Seminar Econ/project2/Natality, 2007-2024.csv",
  show_col_types = FALSE
)

births_clean <- births_raw %>%
  clean_names() %>%
  transmute(
    state = clean_state(state),
    year = as.integer(year),
    births = as.numeric(births)
  ) %>%
  filter(!is.na(state), !is.na(year), !is.na(births))

# quick check
head(births_clean)

# ---------------------------------------------------------
# 3. INCOME FILE: BEA SAINC1
#    Keep LineCode = 3 = per capita personal income
# ---------------------------------------------------------
income_raw <- read_csv(
  "C:/Users/HP/Desktop/ULTIMO SEMESTRE CARAJO/Seminar Econ/project2/SAINC1__ALL_AREAS_1929_2024.csv",
  col_types = cols(.default = col_character())
)

income_clean <- income_raw %>%
  filter(LineCode == "3") %>%
  select(GeoName, matches("^\\d{4}$")) %>%
  pivot_longer(
    cols = matches("^\\d{4}$"),
    names_to = "year",
    values_to = "pc_income"
  ) %>%
  mutate(
    state = str_remove(GeoName, " \\*$"),
    state = clean_state(state),
    year = as.integer(year),
    pc_income = str_replace_all(pc_income, "[^0-9.,-]", ""),
    pc_income = na_if(pc_income, ""),
    pc_income = as.numeric(gsub(",", "", pc_income))
  ) %>%
  select(state, year, pc_income) %>%
  filter(
    !state %in% c(
      "United States",
      "Far West",
      "Great Lakes",
      "Mideast",
      "New England",
      "Plains",
      "Rocky Mountain",
      "Southeast",
      "Southwest"
    )
  )

# quick check
head(income_clean)
summary(income_clean$pc_income)

# ---------------------------------------------------------
# 4. SPENDING FILE: NCES ELSi
#    School year 2006-07 is aligned to calendar year 2007
# ---------------------------------------------------------
spending_raw <- read_csv(
  "C:/Users/HP/Desktop/ULTIMO SEMESTRE CARAJO/Seminar Econ/project2/ELSI_csv_export_6391131616929783805927.csv",
  skip = 6,
  show_col_types = FALSE
)

spending_clean <- spending_raw %>%
  clean_names() %>%
  rename(state = state_name) %>%
  pivot_longer(
    cols = -state,
    names_to = "school_year",
    values_to = "pp_spending"
  ) %>%
  mutate(
    state = clean_state(state),
    start_year = as.integer(str_extract(school_year, "20\\d{2}(?=_\\d{2}$)")),
    year = start_year + 1,
    pp_spending = as.numeric(pp_spending)
  ) %>%
  select(state, year, pp_spending) %>%
  filter(!is.na(state), !is.na(year))

# quick check
head(spending_clean)
summary(spending_clean$pp_spending)

# ---------------------------------------------------------
# 5. MERGE EVERYTHING
# ---------------------------------------------------------
df_full <- main %>%
  left_join(births_clean, by = c("state", "year")) %>%
  mutate(
    lbw_rate = (lbw_count / births) * 100
  ) %>%
  left_join(income_clean, by = c("state", "year")) %>%
  left_join(spending_clean, by = c("state", "year"))

# ---------------------------------------------------------
# 6. CHECK MERGE
# ---------------------------------------------------------
names(df_full)
summary(df_full$lbw_rate)
summary(df_full$pc_income)
summary(df_full$pp_spending)

sum(is.na(df_full$lbw_rate))
sum(is.na(df_full$pc_income))
sum(is.na(df_full$pp_spending))

# ---------------------------------------------------------
# 7. KEEP COMPLETE ROWS FOR THE MODEL
# ---------------------------------------------------------
df_model <- df_full %>%
  filter(
    !is.na(naep_score),
    !is.na(lbw_rate),
    !is.na(pc_income),
    !is.na(pp_spending)
  )

# how many rows are left?
nrow(df_model)
head(df_model)

# optional: save cleaned merged file
write.csv(df_model, "naep_lbw_rate_income_spending_model_data.csv", row.names = FALSE)

# ---------------------------------------------------------
# 8. FIXED-EFFECTS MODEL
# ---------------------------------------------------------
model_full <- feols(
  naep_score ~ lbw_rate + pc_income + pp_spending | state + year,
  data = df_model,
  cluster = ~state
)

summary(model_full)

etable(
  model_full,
  title = "Fixed Effects Model: LBW Rate, Income, and Spending",
  dict = c(
    lbw_rate = "Low-birthweight rate (%)",
    pc_income = "Per capita personal income",
    pp_spending = "Per-pupil spending"
  )
)
# Install once if needed:
# install.packages(c("readxl", "dplyr", "janitor", "fixest"))

library(readxl)
library(dplyr)
library(janitor)
library(fixest)

# 1. Read merged file
df <- read_excel("C:/Users/HP/Desktop/ULTIMO SEMESTRE CARAJO/Seminar Econ/project2/merged_naep_lbw.xlsx") %>%
  clean_names()

# 2. Clean variables
df <- df %>%
  mutate(
    state = as.factor(state),
    year = as.integer(year),
    naep_score = as.numeric(naep_score),
    lbw_count = as.numeric(lbw_count),
    lbw_thousands = lbw_count / 1000
  ) %>%
  filter(
    !is.na(state),
    !is.na(year),
    !is.na(naep_score),
    !is.na(lbw_thousands)
  ) %>%
  arrange(state, year)

# Check years in the merged file
sort(unique(df$year))

# ---------------------------------------------------
# MODEL 1: Same-year fixed effects model
# ---------------------------------------------------
model_same_year <- feols(
  naep_score ~ lbw_thousands | state + year,
  data = df,
  cluster = ~state
)

summary(model_same_year)

# ---------------------------------------------------
# MODEL 2: 2-year average LBW count
# For each NAEP year t, use average of LBW in t and t-1
# ---------------------------------------------------
df_avg2 <- df %>%
  group_by(state) %>%
  arrange(year, .by_group = TRUE) %>%
  mutate(
    lbw_avg2 = (lbw_count + lag(lbw_count)) / 2,
    lbw_avg2_thousands = lbw_avg2 / 1000
  ) %>%
  ungroup() %>%
  filter(!is.na(lbw_avg2_thousands))

model_avg2 <- feols(
  naep_score ~ lbw_avg2_thousands | state + year,
  data = df_avg2,
  cluster = ~state
)

summary(model_avg2)

# ---------------------------------------------------
# COMPARE BOTH
# ---------------------------------------------------
etable(
  model_same_year,
  model_avg2,
  title = "NAEP Math Scores and Low-Birthweight Births",
  dict = c(
    lbw_thousands = "LBW births (same-year, thousands)",
    lbw_avg2_thousands = "LBW births (2-year average, thousands)"
  )
)

# Install once if needed:
# install.packages(c("readxl", "readr", "dplyr", "janitor", "stringr", "fixest"))

library(readxl)
library(readr)
library(dplyr)
library(janitor)
library(stringr)
library(fixest)

# --------------------------------------------------
# 0. Helper function for state names
# --------------------------------------------------
clean_state <- function(x) {
  x <- str_squish(x)
  x <- str_to_title(x)
  x <- str_replace_all(x, "District Of Columbia", "District of Columbia")
  x
}

# --------------------------------------------------
# 1. Read merged NAEP + LBW file
# --------------------------------------------------
df <- read_excel("C:/Users/HP/Desktop/ULTIMO SEMESTRE CARAJO/Seminar Econ/project2/merged_naep_lbw.xlsx") %>%
  clean_names() %>%
  mutate(
    state = clean_state(state),
    year = as.integer(year),
    naep_score = as.numeric(naep_score),
    lbw_count = as.numeric(lbw_count),
    lbw_thousands = lbw_count / 1000
  ) %>%
  filter(
    !is.na(state),
    !is.na(year),
    !is.na(naep_score),
    !is.na(lbw_thousands)
  )

# --------------------------------------------------
# 2. Read cigarette tax file
# --------------------------------------------------
tax_raw <- read_csv(
  "C:/Users/HP/Desktop/ULTIMO SEMESTRE CARAJO/Seminar Econ/project2/The_Tax_Burden_on_Tobacco,_1970-2019_20260430.csv",
  show_col_types = FALSE
)

tax_clean <- tax_raw %>%
  filter(
    MeasureDesc == "Cigarette Sales",
    SubMeasureDesc == "State Tax per pack"
  ) %>%
  transmute(
    state = clean_state(LocationDesc),
    year = as.integer(Year),
    cig_tax = as.numeric(str_replace(as.character(Data_Value), ",", "."))
  ) %>%
  filter(!is.na(state), !is.na(year), !is.na(cig_tax))

# --------------------------------------------------
# 3. Merge tax instrument into main file
# --------------------------------------------------
df_iv <- df %>%
  inner_join(tax_clean, by = c("state", "year")) %>%
  filter(!is.na(cig_tax))

# quick checks
head(df_iv)
summary(df_iv$cig_tax)
nrow(df_iv)

# --------------------------------------------------
# 4. First stage
# Does cigarette tax predict low birthweight births?
# --------------------------------------------------
first_stage <- feols(
  lbw_thousands ~ cig_tax | state + year,
  data = df_iv,
  cluster = ~state
)

summary(first_stage)

# --------------------------------------------------
# 5. Reduced form
# Does cigarette tax predict NAEP scores directly?
# --------------------------------------------------
reduced_form <- feols(
  naep_score ~ cig_tax | state + year,
  data = df_iv,
  cluster = ~state
)

summary(reduced_form)

# --------------------------------------------------
# 6. IV regression
# Instrument: cigarette tax per pack
# Endogenous regressor: lbw_thousands
# --------------------------------------------------
iv_model <- feols(
  naep_score ~ 1 | state + year | lbw_thousands ~ cig_tax,
  data = df_iv,
  cluster = ~state
)

summary(iv_model)

# --------------------------------------------------
# 7. Compare results
# --------------------------------------------------
etable(
  first_stage,
  reduced_form,
  iv_model,
  title = "Cigarette Tax as Instrument for Low-Birthweight Births",
  dict = c(
    cig_tax = "Cigarette tax per pack",
    lbw_thousands = "Low-birthweight births (thousands)"
  )
)

library(fixest)
library(gt)
library(dplyr)

coef_val <- coef(model_fe)["lbw_thousands"]
se_val   <- sqrt(diag(vcov(model_fe)))["lbw_thousands"]
p_val    <- summary(model_fe)$coeftable["lbw_thousands", "Pr(>|t|)"]

stars <- ifelse(p_val < 0.001, "***",
                ifelse(p_val < 0.01,  "**",
                       ifelse(p_val < 0.05,  "*",
                              ifelse(p_val < 0.1,   ".", ""))))

coef_text <- paste0(sprintf("%.3f", coef_val), stars)
se_text   <- paste0("(", sprintf("%.3f", se_val), ")")

n_obs   <- nobs(model_fe)
r2_val  <- fitstat(model_fe, "r2")[[1]]
wr2_val <- fitstat(model_fe, "wr2")[[1]]

tab2 <- tibble(
  VARIABLES = c(
    "Low-birthweight births (thousands)",
    "",
    "Num.Obs.",
    "R2",
    "Within R2",
    "State fixed effects",
    "Year fixed effects"
  ),
  ` (1) NAEP Math Score` = c(
    coef_text,
    se_text,
    as.character(n_obs),
    sprintf("%.3f", r2_val),
    sprintf("%.3f", wr2_val),
    "Yes",
    "Yes"
  )
)

gt_tab2 <- tab2 %>%
  gt() %>%
  cols_label(
    VARIABLES = "VARIABLES",
    ` (1) NAEP Math Score` = "(1) NAEP Math Score"
  ) %>%
  tab_options(
    table.font.size = px(22),
    data_row.padding = px(12)
  ) %>%
  cols_align(align = "left", columns = VARIABLES) %>%
  cols_align(align = "center", columns = ` (1) NAEP Math Score`) %>%
  tab_source_note(
    source_note = md("Standard errors clustered by state in parentheses. * p<0.05, ** p<0.01, *** p<0.001")
  )

gtsave(gt_tab2, "regression_table_clean.png")