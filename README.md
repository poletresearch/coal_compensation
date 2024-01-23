# coal_compensation
Code for the article Nacke, L., Vinichenko, V., Cherp A., Jakhmola A., and Jewell J. 
Compensating affected parties necessary for rapid coal phase-out but expensive if extended to major emitters

Journal and DOI to be added

avoided_emissions.R - R code for calculating avoided emission due to 
premature phase-out of coal power plants (compared to the average national
lifetime) 

coal_plants.csv - source data file (coal-fired power plants)^

coal_generation.csv - source data file (electricity generation from coal)^

po_schedule.csv - coal phase-out data for countries

file_format.txt – description of input and output file formats

When running R files, working directory should be set to one containing the respective 
data files.

Packages necessary for running R code are listed within fitting.R.

^Note: since the article used proprietary data for calculating avoided emissions,
mock data are provided with this code for testing purposes. 
