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


/*

Once the table was created, I merged the past 12 months into a single table.

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

/*

### Step 3: Cleaning and Transforming the Data

The first thing I wanted to check for was duplicates.

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

/*

While going combing through the data, I noticed two things.
1. There are NULL in the dataset.
2. A few of the start_station and end_station indicated that these were maintenance or test rides.

These data points were removed from the dataset to ensure the accuracy of our analysis.

Next, I deleted for NULLS as it is incomplete data

Delete from the table where data is NULL. (1369973 rows affected)

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

/*

My first calculation was to determine how long each ride lasted and I wanted to add this to the table

*/

ALTER TABLE
	cyclistic_trip_last_12m
ADD ride_length_minutes INT;

UPDATE cyclistic_trip_last_12m
SET ride_length_minutes = DATEDIFF(MINUTE, started_at, ended_at);

/*

When I skimmed through the results of the ride lengths, I noticed that some ```ride_length_minutes``` were 0, negative or exceeded 24 hours. 

I wanted to further investigate so I dug deeper into the ```ride_length_minutes``` by looking at the max in minutes and the minimum in seconds.

*/

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


/*

I decided to remove ride lengths that exceeded 24 hours because those bikes were deemed lost/stolen. [source](https://help.divvybikes.com/hc/en-us/articles/360033484791-What-if-I-keep-a-bike-out-too-long-)
I also removed the rides with negative values and 0 seconds.

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


/*

## Step 4: Analyze the data

I began my analysis by looking for simple insights such as ***total rides*** and ***average ride lengths per rider type***

I started with the ***total number of rides*** from July 2022 to June 2023

*/

-- Average ride length for each group in minutes & all riders

SELECT 
    CASE WHEN GROUPING(member_casual) = 1 THEN 'all_rider' ELSE member_casual END AS member_casual,
    AVG(ride_length_minutes) AS average_ride_length_minutes
FROM
    cyclistic_trip_last_12m
GROUP BY 
    ROLLUP (member_casual);


/*

Next was to determine the ***busiest day*** for rides per rider type

*/

-- Counts total rides per weekday for each rider type, ranks them in order, then assigns the name of the week.

WITH Common_Ride_Day AS (
    SELECT
        COUNT(*) AS ride_count,
        member_casual,
        DATEPART(WEEKDAY, started_at) AS start_weekday
    FROM
        cyclistic_trip_last_12m
    GROUP BY
        member_casual,
        DATEPART(WEEKDAY, started_at)
),
RankedRides AS (
    SELECT
        ride_count,
        member_casual,
        start_weekday,
        ROW_NUMBER() OVER (PARTITION BY member_casual ORDER BY ride_count DESC) AS rn
    FROM
        Common_Ride_Day
)
SELECT
    ride_count,
    member_casual,
    start_weekday,
    CASE WHEN start_weekday = 1 THEN 'Sunday'
         WHEN start_weekday = 2 THEN 'Monday'
         WHEN start_weekday = 3 THEN 'Tuesday'
         WHEN start_weekday = 4 THEN 'Wednesday'
         WHEN start_weekday = 5 THEN 'Thursday'
         WHEN start_weekday = 6 THEN 'Friday'
         WHEN start_weekday = 7 THEN 'Saturday'
    END AS start_ride_day_name
FROM
    RankedRides
WHERE
    rn = 1;



-- Calculates total ride per day for rider types

SELECT
    member_casual,
    ride_day_name,
    total_rides_per_day
FROM (
    SELECT
        member_casual,
        CASE WHEN start_weekday = 1 THEN 'Sunday'
             WHEN start_weekday = 2 THEN 'Monday'
             WHEN start_weekday = 3 THEN 'Tuesday'
             WHEN start_weekday = 4 THEN 'Wednesday'
             WHEN start_weekday = 5 THEN 'Thursday'
             WHEN start_weekday = 6 THEN 'Friday'
             WHEN start_weekday = 7 THEN 'Saturday'
        END AS ride_day_name,
        COUNT(*) AS total_rides_per_day
    FROM (
        SELECT
            member_casual,
            DATEPART(WEEKDAY, started_at) AS start_weekday,
            DATEDIFF(MINUTE, started_at, ended_at) AS ride_length_minutes
        FROM
            cyclistic_trip_last_12m
    ) AS Rides
    GROUP BY
        member_casual,
        start_weekday
) AS AvgRidePerWeekday
ORDER BY
    member_casual,
    total_rides_per_day DESC;

/*

I also wanted to know the ***average length of rides*** per rider throughout the week.

*/

-- Calculates average ride length per day for rider type 

SELECT
    member_casual,
    ride_day_name,
    average_ride_length_minutes
FROM (
    SELECT
        member_casual,
        CASE WHEN start_weekday = 1 THEN 'Sunday'
             WHEN start_weekday = 2 THEN 'Monday'
             WHEN start_weekday = 3 THEN 'Tuesday'
             WHEN start_weekday = 4 THEN 'Wednesday'
             WHEN start_weekday = 5 THEN 'Thursday'
             WHEN start_weekday = 6 THEN 'Friday'
             WHEN start_weekday = 7 THEN 'Saturday'
        END AS ride_day_name,
        AVG(ride_length_minutes) AS average_ride_length_minutes
    FROM (
        SELECT
            member_casual,
            DATEPART(WEEKDAY, started_at) AS start_weekday,
            DATEDIFF(MINUTE, started_at, ended_at) AS ride_length_minutes
        FROM
            cyclistic_trip_last_12m
    ) AS CasualRides
    GROUP BY
        member_casual,
        start_weekday
) AS AvgRidePerWeekday
ORDER BY
    member_casual,
    average_ride_length_minutes DESC;

/*

Next, it was important to determine which ***parts of the day and seasons were the busiest***.

*/

-- How do time, day, and month affect the rider type

SELECT
    member_casual,
    ride_day_name,
    ride_month_name,
    ride_hour,
	--seasons
    CASE
        WHEN ride_month IN (12, 1, 2) THEN 'Winter'
        WHEN ride_month IN (3, 4, 5) THEN 'Spring'
        WHEN ride_month IN (6, 7, 8) THEN 'Summer'
        ELSE 'Fall'
    END AS season,
	-- daytime
    CASE
        WHEN ride_hour BETWEEN 0 AND 11 THEN 'Morning'
        WHEN ride_hour BETWEEN 12 AND 17 THEN 'Afternoon'
        ELSE 'Evening'
    END AS time_of_day,
    COUNT(*) AS ride_count
FROM (
    SELECT
        member_casual,
        DATEPART(MONTH, started_at) AS ride_month,
        DATEPART(HOUR, started_at) AS ride_hour,
        DATENAME(WEEKDAY, started_at) AS ride_day_name,
        DATENAME(MONTH, started_at) AS ride_month_name
    FROM
        cyclistic_trip_last_12m
) AS RideData
GROUP BY
    member_casual,
    ride_month,
    ride_hour,
    ride_day_name,
    ride_month_name
ORDER BY
    member_casual,
    season,
    time_of_day,
    ride_month,
    ride_day_name,
    ride_hour;

/*

Because I have geographic locations, it would be helpful to determine which ***stations are the busiest***. 

*/

SELECT
    COUNT(start_station_name) as most_frequent_start_location,
	start_station_name,
    member_casual
FROM
    cyclistic_trip_last_12m
GROUP BY
    start_station_name,
    member_casual
ORDER BY
    COUNT(start_station_name) DESC;

-- Common end location

SELECT
    COUNT(end_station_name) as most_frequent_end_location,
	end_station_name,
    member_casual
FROM
    cyclistic_trip_last_12m
GROUP BY
    end_station_name,
    member_casual
ORDER BY
    COUNT(end_station_name) DESC;

/*

And lastly, I wanted to determine if riders had a ***preference for bike type***.

*/

-- Do users have a preference for bike type?

SELECT
	rideable_type,
	COUNT(*) as total_rides_by_ride_type,
	member_casual
FROM
	cyclistic_trip_last_12m
GROUP BY
	rideable_type,
	member_casual
ORDER BY
	total_rides_by_ride_type;

```
