# Code for calculating avoided emissions due to coal phase-out pledges

Code for the article Nacke, L., Vinichenko, V., Cherp A., Jakhmola A., and Jewell J. 
Compensating affected parties necessary for rapid coal phase-out but expensive if extended to major emitters (2024). Nature Communications

## Files

avoided_emissions.R - R code for calculating avoided emission due to 
premature phase-out of coal power plants (compared to the average national
lifetime) 

coal_plants.csv - source data file (coal-fired power plants)^

coal_generation.csv - source data file (electricity generation from coal)^

po_schedule.csv - coal phase-out data for countries

file_format.txt – description of input and output file formats

## System requirements

A recent version of R (on any operating system for which R is available) with packages dplyr and truncnorm

Tested with:
macOS 14.3.0
R 4.3.2
dplyr 1.1.3
truncnorm 1.0-9

## Running instructions

Place the files into a folder (no special installation is required). Edit paths to source
data files in avoided_emissions.R and run the file. The output will be saved in the file
avoided_emissions.csv (see file_format.txt for the format).
 
When running the file with the provided demo data, working directory should be set to one containing
the respective data files.

To run the code on your data, provide your own source files (see file_format.txt for the format) and edit
the paths in avoided_emissions.R accordingly.

Typical running time: with demo data 1-2 seconds, with actual data < 1 min.

## Detailed description of the code logic

1. Loading and initial processing of the data. Various control variables are initialised. The file with 
power plant data is loaded; only retired plants (STATUS == ‘RET’), operating plants (STATUS == ‘OPR’),
and those in construction (STATUS == ‘CON’) are selected. The status of plants in construction is 
changed to ‘OPR’ (so that they are taken into account in calculating avoided emissions).

2. Calculation of the average national plant lifetimes. Retired plants with the retirement date within 
the specified range (variable life_years) and the starting date available (to make it possible to 
calculate plant lifetime) are selected. Mean plant lifetime and standard deviation are calculated for 
each country (provided it has > 3 retirement cases, otherwise it is assumed that there is not enough 
data and default values, e.g. global averages, are used for that country, defined as variables Mean.Def 
and the SD.Def).

3. Calculation of average national load factors.  Electricity generation data are loaded, and generation 
rom coal for each country and each year within the specified range (variable LF_years) is extracted. 
The available coal capacity is calculated for each country/year, using data about plant start and 
retirement years. Plants with retirement date before the beginning of the time range or starting date 
after the end of the time range are not included. If a plant is started or retired in a year within the
period,  1/2 of its capacity is recorded as available in that particular year (the assumption being 
that on average it is operating for half a year). A load factor for each country/year is calculated 
using calculated generation and installed capacity. Average national load factor is calculated as 
a mean across all years in the time range for a given country.

4. Calculation of baseline retirement dates. For each operating plant, a baseline retirement date is 
calculated by adding the average national lifetime to the starting year (for plants with < 4 retirement 
events in the specified range, default lifetime is used). For ‘overdue’ plants (already past the 
average national lifetime in the starting year of the calculation), three possible strategies can be 
used (which one is used is determined by the variable ‘overdue’)

* five years (overdue == ‘five’); overdue plants are retired within the first five years of the 
retirement modelling period (first_year:(first_year + 4)), random uniform distribution across those years

* truncated normal distribution (overdue == ‘truncnorm’); it is assumed that plant retirement dates 
follow a normal distribution with mean = average national lifetime and sd = standard deviation of 
national lifetimes. For a plant at the age N the remaining lifetime is determined by the expected 
value according to the remaining tail of the normal distribution (i.e. normal distribution 
truncated at x == N). 

* immediate retirement (overdue == ‘other’); all overdue plants are immediately retired in the 
first year of the retirement modelling.

5. Calculation of avoided MW * year of generation for each plant due to phase-out pledges. For each plant, 
a difference between the baseline retirement date and the pledged national phase-out date is calculated; 
if the former is greater than the latter, the plant’s installed capacity (MW) is multiplied by the 
difference in years to produce avoided MW * years. Otherwise, there are no avoided generation for this 
particular plant. If the estimation is time-constrained (only avoided emissions until a certain year 
are taken into account, e.g. const == 2050), and the constraining year is earlier than the baseline 
retirement year, it is used instead of the baseline retirement year.

6. Calculation of avoided emissions due to phase-out pledges. For each plant with non-zero MW*years, 
they are converted into avoided emissions through the following steps:
  - MW * years are converted into TWh of power generation using the national load factors
    (see (3) above);
  - power generation is converted into coal consumption (using efficiencies for specific technologies, 
    vector eff);
  - coal consumption is converted into emissions (using emission factors for specific types of coal, 
    vector em).

7. Calculations of avoided emissions for countries. Avoided emissions for each country (or each 
country/pledge case, if there are several pledges for the country) are summed up across all the 
plants in the country. The resulting values are reported in the output file.	

^Note: since the article used proprietary data for calculating avoided emissions,
demo data are provided with this code for testing purposes. 
