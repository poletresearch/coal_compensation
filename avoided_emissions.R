# Calculation of avoided emissions due to coal phase-out
# (Emissions are avoided due to premature retirement of 
# power plants at the retirement date compared to
# the average national lifetime)

## Necessary packages
library(dplyr)
library(truncnorm)

## Efficiency for different technologies
eff <- c(SUBCR = 33.65, SUPERC = 39.75, ULTRSC = 43.15, UNKNOWN = 33.6)

## Emission factors for different types of coal (kg CO2 per million BTU)
em <- c(ANTH = 103.7, BIT = 93.3, SUB = 97.2, LIG = 97.7, OTHER = 95.3)

# Retirement range used for evaluating average national plant lifetime
# (plants with retirement years outside of the range are not included)
life_years <- 2001:2021

# Year range used for estimating average national load factor
LF_years <- 2015:2019

# Year from which plant retirement starts 
first_year <- 2022

filename_plants <- "coal_plants.csv" #Coal power plant data
filename_generation <- "coal_generation.csv" #Coal generation data
filename_po <- "PO_schedule.csv" #Phase-out schedule
filename_result <- "avoided_emissions.csv" #Caclulation results

# Constrained or unconstrained estimate
# Constrained: avoided emissions until a certain year, assign year, e.g.: constr <- 2050
# Unconstrained: avoided emissions with no time limit, assign NA: constr <- NA
constr <- NA 

# Dealing with overdue plants (age greater than average lifetime in the year
# in which plant retirement starts)
# 'truncnorm' - remaining lifetime is calculated based on truncated normal
# distribution, mean = average national lifetime, sd = standard deviation of lifetime
# (if 'truncnorm' is chosen, then truncated normal distribution is applied to all plants,
# not only those overdue)
# 'five' - overdue plants are retired randomly within five years starting with the
# first retirement year (uniform distribution )
# any other value - immediate retirement in the first year

overdue <- 'five'
#overdue <- 'truncnorm'
#overdue <- 'other'

## Phaseout data
cn0 <- read.csv(filename_po, stringsAsFactors = F) 

if (!is.na(constr)) {
  cn <- cn0 %>% filter(POYear < constr)
} else { 
  cn <- cn0
}

p00 <- read.csv(filename_plants, stringsAsFactors = F) 


p0 <- p00 %>%
  filter(STATUS %in% c("OPR", "RET", "CON")) %>% #Select only Operating, Retired, and in Construction
  mutate(STATUS = ifelse(STATUS == "CON", "OPR", STATUS), #Treat plants in Construction as operating 
                                                          #(with the commissioning year specified in the DB)
         STYPE = ifelse(STYPE == "", "UNKNOWN", STYPE))



## Calculatnig average national plant lifetime
#  Select only plants for with both commissioning and retirement
#  dates are available (for calculating average national lifetime) 

lt1 <- p0 %>% filter(!is.na(Year), !is.na(RETIRE)) %>%
  select(MW, Year, RETIRE, Country)

lt2 <- lt1 %>% mutate(Lifetime = RETIRE - Year) %>%
  filter(RETIRE %in% life_years) %>%
  group_by(Country) %>%
  summarize(NoRet = n(),
            MWRet = round(sum(MW)),
            MeanLife = round(mean(Lifetime)),
            SDLife = round(sd(Lifetime), 1)) %>%
  ungroup %>%
  filter(NoRet > 3) #At least 4 cases must be available

mns <- lt2 %>% select(Country, MeanLife, SDLife)

## Default values (to be used when the national average lifetime cannot
## be calculated)

# Global mean and SD
Mean.Def <- 41.7
SD.Def <- 16

# Mean and SD for Asia (used for Asian countries with not enough national
# retirement events)
#Mean.Def <- 30
#SD.Def <- 13

p1 <- p0 %>% merge(mns, all.x = T) %>%
  merge(cn, all.x = T) %>%
  mutate(MeanLife = ifelse(!is.na(MeanLife), MeanLife,
                           Mean.Def),
         SDLife = ifelse(!is.na(SDLife), SDLife,
                         SD.Def))

## Calculating average national load factors

# Generation data
d <- read.csv(filename_generation, stringsAsFactors = F) %>%
  filter(Country %in% cn$Country) 

## National installed capacity for each year 
pc0 <- p0 %>% 
  mutate(Year = ifelse(is.na(Year), 1980, Year))

## Remove retired plants with no retirement year
pc <- pc0 %>% filter(!(STATUS == "RET" & is.na(RETIRE)))

pc1 <- pc %>% rename(Start.Year = Year) %>%
  merge(data.frame(Year = LF_years))

## Remove retired plants after their retirement year and 
## operating plants before their starting year
## In a plant's starting or retirement year,
## half of its installed capacity is counted
pc2 <- pc1 %>% filter(!(STATUS == "OPR" & Year < Start.Year),
                      !(STATUS == "RET" & Year > RETIRE)) %>%
  mutate(MW1 = ifelse(STATUS == "OPR" & Year == Start.Year, MW/2, MW),
         MW1 = ifelse(STATUS == "RET" & Year == RETIRE, MW/2, MW1)) 

d1 <- d %>% filter(Year %in% LF_years)

# Load factor for each year
d.cap.0 <- pc2 %>% group_by(Country, Year) %>%
  summarize(MW = sum(MW1)) %>%
  ungroup %>%
  merge(d1) %>%
  mutate(Ratio = Value/MW,
         LF = Ratio / 24 / 365 * 1000) 

# Averaging across years 
d.cap <- d.cap.0 %>%
  group_by(Country) %>%
  summarize(LF = mean(LF)) %>%
  ungroup 

yrs <- data.frame(Year1 = 2010:2100)
result <- data.frame()
result.full <- data.frame()
result.cnt <- data.frame()


  
p2a <- p1 %>% filter(STATUS == "OPR") %>%
  filter(!is.na(Year), !is.na(POYear)) %>%
  mutate(Exp.Ret = Year + MeanLife)
  
## Different ways of handling plants with 'overdue' retirement
  
if (overdue == 'truncnorm') {
  p2 <- p2a %>% mutate(Ret = etruncnorm(a = first_year, mean = Exp.Ret, sd = SDLife), 
                    RETIRE = round(Ret))
} else if (overdue == 'five') {
  p2 <- p2a %>% mutate(Ret = round(Exp.Ret), Rand = sample(0:4, nrow(p2a), replace = T), 
                       RETIRE = ifelse(Ret < first_year, first_year + Rand, Ret)) %>%
    select(- Rand)
} else {
  p2 <- p2a %>% mutate(Ret = Exp.Ret, 
                       RETIRE = round(Ret))
}
  
if (is.na(constr)) {
  p3 <- p2 %>% 
    mutate(Delta = RETIRE - POYear, MWYear = MW * Delta, d.ret = RETIRE - Exp.Ret) 
} else {
  p3 <- p2 %>% mutate(Exp.Ret = Year + MeanLife,
           RETIRE = ifelse(RETIRE > constr, constr + 0.5, RETIRE),
           Delta = RETIRE - POYear, MWYear = MW * Delta, d.ret = RETIRE - Exp.Ret) 
}
  
## Calculating avoided emissions
## 1 GWh = 3412 mln BTU 
p4 <- p3 %>%
 merge(d.cap) %>%
  mutate(FUELTYPE = ifelse(FUELTYPE %in% c("ANTH", "BIT", "SUB", "LIG"), FUELTYPE, "OTHER"), 
    Output = MWYear * LF * 24 * 365 / 1000, Eff = eff[STYPE], Em = em[FUELTYPE],
         Coal = Output/Eff * 100, Carbon = Em * 3.412 * Coal) 


p5 <- p4 %>% 
  filter(Delta  > 0) %>% 
  group_by(Code) %>%
  summarize(MWYear = sum(MWYear),
            Carbon = sum(Carbon)/10^6) %>%
  ungroup 

write.csv(p5, filename_result, row.names = F)
