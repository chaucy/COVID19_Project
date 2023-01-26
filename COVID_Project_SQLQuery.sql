--Exploring the dataset:
-- Select unique locations from the CovidDeaths table
SELECT 
	DISTINCT location 
FROM PortfolioProject..CovidDeaths;
-- Select unique locations from the CovidVaccinations table
SELECT 
	DISTINCT location 
FROM PortfolioProject..CovidVaccinations

--Creating a filter column for filtering the 'location' column into 3 sub-groups; 'Country','Continent', 'Income Level'
-- Add a new column called "filter_location" to the 'PortfolioProject..CovidDeaths' table
ALTER TABLE PortfolioProject..CovidDeaths ADD filter_location nvarchar(255);

-- Use a T-SQL case statement to determine the value for the "filter_location" column based on the value in the "location" column
UPDATE PortfolioProject..CovidDeaths
SET filter_location = 
  CASE
    -- if location is one of the 'Continent'
    WHEN location IN ('North America', 'South America', 'Europe', 'Africa', 'Asia', 'Oceania') THEN 'Continent'
    -- if location is one of the 'Income Level'
    WHEN location IN ('Low income', 'Lower middle income', 'Upper middle income', 'High income') THEN 'Income Level'
    ELSE 'Country'
  END;

--Make sure the location_filter was created
SELECT  
	DISTINCT location, 
	filter_location 
FROM PortfolioProject..CovidDeaths
Order by filter_location

--Total 4 Analysis Points
	

-- 1. Examining vaccine effectiveness by comparing vaccinated rate & fatality rate among Countries crossing time

WITH rolling_sum AS (
SELECT
	cd.location,
	cd.date,
	people_fully_vaccinated_per_hundred,
	people_vaccinated_per_hundred,
	total_boosters_per_hundred,
	reproduction_rate,
	gdp_per_capita,
	SUM(CAST(new_cases AS float)) OVER (PARTITION BY cd.location ORDER BY cd.date) AS total_cases,
	SUM(CAST(new_deaths AS float)) OVER (PARTITION BY cd.location ORDER BY cd.date) AS total_deaths
FROM PortfolioProject..CovidDeaths AS cd
JOIN PortfolioProject..CovidVaccinations AS cv
ON cd.location = cv.location
AND cd.date = cv.date
)
SELECT
	location,
	date,
	people_fully_vaccinated_per_hundred,
	people_vaccinated_per_hundred,
	total_boosters_per_hundred,
	reproduction_rate,
	gdp_per_capita,
	--CASE statement for avoiding 'dividing zero' track back occur
	(CASE
		WHEN total_cases > 0 THEN total_deaths/ total_cases
		ELSE 0
		END ) AS Fatality_rate
FROM
	rolling_sum
Order by
	date DESC,
	location;


--2.'Examing the latest death counts by Country and its wealth level (measured by 'GDP per capita')'

--- Combining stackoverflow ROW_NUMBER() method to obtain the row only has latest date
WITH CTE AS (
SELECT
	cd.location,
	cv.gdp_per_capita AS gdp_per_capita,
	CAST(cd.date AS date) AS date,
	cd.filter_location,
	SUM(CAST(cd.new_deaths_per_million AS float)) OVER (PARTITION BY cd.location ORDER BY cd.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
	AS rolling_sum_new_deaths_per_million
FROM PortfolioProject..CovidDeaths cd
JOIN PortfolioProject..CovidVaccinations cv
ON cv.location = cd.location
AND cv.date = cd.date
)
SELECT
	location,
	gdp_per_capita,
	date,
	rolling_sum_new_deaths_per_million
FROM CTE
WHERE
filter_location ='Country'
Order by
	date DESC,
	location;

--3. 'Relation between government restrictions and R0 (the spread of the virus over time)'

SELECT 
	cd.location, 
	cd.date, 
	CAST(stringency_index AS float) AS stringency_index, 
	CAST(reproduction_rate AS float) AS reproduction_rate, 
	CAST(hosp_patients as float) AS hosp_patients,
	CAST(hosp_patients_per_million as float) AS hosp_patients_per_million
FROM PortfolioProject..CovidVaccinations cv
JOIN PortfolioProject..CovidDeaths cd
ON cv.iso_code = cd.iso_code
AND cv.location = cd.location
AND cv.date = cd.date
WHERE
filter_location ='Country'
Order by
	date DESC,
	location;


-- 4.'Impact of underlying health conditions on COVID-19' 
-- Use the data on cardiovasc death rate, diabetes prevalence, 
--and smoking rates to analyze the impact of underlying health conditions on COVID-19.

--#Below code need about 23 sec to load
WITH CTE AS (
SELECT
	cd.location,
	CAST(cd.date AS date) AS date,
	cv.gdp_per_capita,
	cv.cardiovasc_death_rate AS cardiovasc_death_rate,
	cv.diabetes_prevalence AS diabetes_prevalence,
	cd.filter_location,
	SUM(CAST(cd.new_deaths AS float)) OVER (PARTITION BY cd.location ORDER BY cd.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS total_deaths,
	SUM(CAST(cd.hosp_patients_per_million AS float)) OVER (PARTITION BY cd.location ORDER BY cd.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Total_hosp_patients_per_million,
	SUM(CAST(cd.icu_patients_per_million AS float)) OVER (PARTITION BY cd.location ORDER BY cd.date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS Total_icu_patients_per_million
FROM PortfolioProject..CovidDeaths cd
JOIN PortfolioProject..CovidVaccinations cv
ON cv.location = cd.location
AND cv.date = cd.date
)
SELECT
	location,
	date,
	gdp_per_capita,
	cardiovasc_death_rate,
	diabetes_prevalence,
	total_deaths,
	Total_hosp_patients_per_million,
	Total_icu_patients_per_million
FROM CTE
WHERE
filter_location = 'Country'
ORDER BY 
	date DESC, 
	gdp_per_capita DESC;