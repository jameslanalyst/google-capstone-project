# Google Capstone Project - Cyclistic

Capstone Case Study from Google Data Analytics Certification

## About Cyclistic
Cyclistic is a bike-share program in Chicago with 5,824 bikes and 692 geotracked stations. The marketing strategy initially focused on raising general awareness and targeting broad consumer segments. Their pricing plans offered single-ride passes, full-day passes, and annual memberships, categorizing customers into casual riders and Cyclistic members based on their purchase choices. 

Financial analysis revealed annual members as more profitable than casual riders, prompting a shift in focus. Director Moreno aims to convert casual riders, who already know Cyclistic, into members. The plan involves leveraging historical bike trip data to identify trends and inform marketing strategies for successful conversion.

## My Role

I am a junior data analyst working in the marketing analyst team at Cyclistic, a bike-share company in Chicago. The director of marketing  believes the company’s future success depends on maximizing the number of annual memberships. Therefore, your team wants to understand how casual riders and annual members use Cyclistic bikes differently. From these insights, your team will design a new marketing strategy to convert casual riders into annual members.

Business Statement: By identifying how casual riders and annual members use Cyclistic differently, we can create a marketing campaign that targets casual riders and converts them into annual members. 

*Below I will describe the process I used step-by-step in this project.*

## Process

Overview: I downloaded and reviewed all of the data separately (12 months of data) in Google Sheets, then used Microsoft SQL to analyze the data as a whole year. Lastly, I created a dashboard in Tableau to present my analysis.

### Step 1: Download the Data

I downloaded the most recent data from the Data source and imported them into Google Sheets. 

The data was organized monthly and contained the following columns.


| Column  | Explanation |
| --- | --- |
| ride_id  | The ID for each ride  |
| rideable_type  | The type of bike used  |
| started_at  | The date and time when the ride started  |
| ended_at  | The date and time when the ride ended  |
| start_station_name  | Name of the station where the ride started  |
| start_station_id  | ID of the station where the ride started  |
| end_station_name  | Name of the station where the ride ended  |
| end_station_id  | ID of the station where the ride ended  |
| start_lat  | The latitude of the station where the ride started  |
| start_lng  | The longitude of the station where the ride started  |
| end_lat  | The latitude of the station where the ride ended  |
| end_lng  | The longitude of the station where the ride ended  |
| member_casual  | The membership type of the rider  |



The timeframe for the data that was downloaded was from July 2022 to June 2023, which is a 12-month period.

I wanted to review the data in google sheets to see which tool I preferred to use. After seeing that each spreadsheet had over a hundred thousand rows, I knew it would be more efficient to work with this data using SQL.


### Step 2: Import into SQL Server Management Studio and join the tables.

I Imported the CSV files into SQL Server Management Studio and created a table where I could join all the tables into one.

```sql
--- Created a Table that will hold all the tables together.

CREATE TABLE cyclistic_trip_last_12m
	(ride_id nvarchar(50),
	rideable_type nvarchar(50),
	started_at datetime2,
	ended_at datetime2,
	start_station_name nvarchar(100),
	start_station_id nvarchar(50),
	end_station_name nvarchar(100),
	end_station_id nvarchar(50),
	start_lat float,
	start_lng float,
	end_lat float,
	end_lng float,
	member_casual nvarchar(50)
	);

```

Once the table was created, I merged the past 12 months into a single table.

```sql

/*

Inserted all the tables using a Union All statement into the newly created table with 5,779,444 rows

*/

INSERT INTO cyclistic_trip_last_12m
SELECT * 
FROM divvy_trip_2022_07
UNION ALL
SELECT * 
FROM divvy_trip_2022_08
UNION ALL
SELECT * 
FROM divvy_trip_2022_09
UNION ALL
SELECT * 
FROM divvy_trip_2022_10
UNION ALL
SELECT * 
FROM divvy_trip_2022_11
UNION ALL
SELECT * 
FROM divvy_trip_2022_12
UNION ALL
SELECT * 
FROM divvy_trip_2023_01
UNION ALL
SELECT * 
FROM divvy_trip_2023_02
UNION ALL
SELECT * 
FROM divvy_trip_2023_03
UNION ALL
SELECT * 
FROM divvy_trip_2023_04
UNION ALL
SELECT * 
FROM divvy_trip_2023_05
UNION ALL
SELECT * 
FROM divvy_trip_2023_06;


```

### Step 3: Cleaning and Transforming the Data

The first thing I wanted to check for was duplicates.

```sql

/*

Wrote this query to ensure there were no duplicate ride_ids, start_station_id, end_station_id

*/
	
SELECT 
	 ride_id, 
	 start_station_id, 
	 end_station_id, 
	 COUNT(*) AS dup_count
FROM cyclistic_trip_last_12m
GROUP BY 
	ride_id, 
	 start_station_id, 
	 end_station_id
HAVING COUNT(*) > 1;

```
While going combing through the data, I noticed two things.
1. There are ```NULL``` in the dataset.
2. A few of the ```start_station``` and ```end_station``` indicated that these were maintenance or test rides.

These data points were removed from the dataset to ensure accuracy for our analysis.

Next, I deleted for NULLS as it is incomplete data

```sql
/*

Delete from table where data is NULL. (1369973 rows affected)

*/

DELETE FROM
	cyclistic_trip_last_12m
WHERE 
	ride_id IS NULL
	OR
	rideable_type IS NULL
	OR
	started_at IS NULL
	OR
	ended_at IS NULL
	OR
	start_station_id IS NULL
	OR
	start_station_name IS NULL
	OR
	end_station_id IS NULL
	OR
	end_station_name IS NULL
	OR
	start_lat IS NULL
	OR
	start_lng IS NULL
	OR
	end_lat IS NULL
	OR
	end_lng IS NULL
	OR
	member_casual IS NULL;

/*

Delete from the table where the start or end station is a maintenance site for Cyclistic. (1356 rows affected)

*/

DELETE FROM 
	cyclistic_trip_last_12m
WHERE
	(start_station_id LIKE '%TEST%')
	OR
	(end_station_id LIKE '%TEST%')
	OR
	(start_station_name LIKE '%TEST%')
	OR
	(end_station_name LIKE '%TEST%');

```

My first calculation was to determine how long each ride lasted and I wanted to add this to the table

```sql

ALTER TABLE
	cyclistic_trip_last_12m
ADD ride_length_minutes INT;

UPDATE cyclistic_trip_last_12m
SET ride_length_minutes = DATEDIFF(MINUTE, started_at, ended_at);

```

When I skimmed through the results of the ride lengths, I noticed that some ```ride_length_minutes``` were 0, negative or exceeded 24 hours. 

I wanted to further investigate so I dug deeper into the ```ride_length_minutes``` by looking at the max in minutes and the minimum in seconds.

```sql

-- Max ride length for each group in minutes

SELECT 
	member_casual,
	MAX(ride_length_minutes) as max_ride_length_minutes
FROM
	cyclistic_trip_last_12m
GROUP by member_casual;


--Min ride length for each group in seconds

SELECT 
	member_casual,
	MIN(DATEDIFF(SECOND, started_at, ended_at)) as min_ride_length_seconds
FROM
	cyclistic_trip_last_12m
GROUP BY
	member_casual;


```

I decided to remove ride lengths that exceeded 24 hours because those bikes were deemed lost/stolen. [source](https://help.divvybikes.com/hc/en-us/articles/360033484791-What-if-I-keep-a-bike-out-too-long-)
I also removed the rides with negative values and 0 seconds.

```sql

/*

Delete negative values of ride_length_minutes and ride_length_minutes that exceed 1440 minutes(24 hours). (443 rows affected)

*/

DELETE FROM
	cyclistic_trip_last_12m

WHERE 
	DATEDIFF(MINUTE, started_at, ended_at) >1440
	OR
	DATEDIFF(MINUTE, started_at, ended_at) < 0
	OR
	DATEDIFF(SECOND, started_at, ended_at) <= 0;


```

## Step 4: Analyze the data

I began my analysis by looking at the data from an overall view then getting more granular.

I started with the ***total number of rides*** from July 2022 to June 2023

