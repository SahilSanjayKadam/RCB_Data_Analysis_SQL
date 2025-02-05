
use ipl
-- 1.different dtypes of columns in table “ball_by_ball” (using information schema)
SELECT DISTINCT DATA_TYPE  FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME='Ball_by_Ball' AND TABLE_SCHEMA = 'ipl';


-- 2.What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table)

with cte as (
select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,
b.Team_Batting,t.Team_Name as Team_Batting_Name,
b.Team_Bowling,t1.Team_Name as Team_Bowling_Name,
m.Season_Id,(b.Runs_Scored+coalesce(e.Extra_Runs,0)) as Total_Runs_Scored
from Ball_by_Ball b join Team t 
on t.Team_Id=b.Team_Batting
join Team t1 on t1.Team_Id=b.Team_Bowling
join Matches m on m.Match_Id=b.Match_Id
left join Extra_Runs e on e.Match_Id=b.Match_Id and 
e.Over_Id=b.Over_Id and e.Ball_Id=b.Ball_Id and 
e.Innings_No=b.Innings_No
),
cte1 as(
select * from cte where Team_Batting_Name='Royal Challengers Bangalore' and Season_Id=(select min(Season_Id) from cte)
)
select Team_Batting_Name,sum(Total_Runs_Scored) as Total_Runs_Scored_Season_1 from cte1 
group by Team_Batting_Name

-- 3.	How many players were more than the age of 25 during season 2014?
with age_table as (
select Player_Id,Player_Name, timestampdiff(year,DOB,'2014-01-01') as age from Player
),
cte as (
select Match_Id,Player_Id from Player_Match where Match_Id in (
		select distinct Match_Id from Matches where Season_Id=(select Season_Id from Season where Season_Year=2014)
		 )
)
select count(distinct c.player_id) as players_above_25
from cte c
join age_table a on c.player_id = a.player_id
where a.age > 25

-- 4.	How many matches did RCB win in 2013? 
with cte as (
select m.Match_Id,m.Match_Winner,m.Season_Id,s.Season_Year from Matches m 
join Season s on m.Season_Id=s.Season_Id
where Season_Year=2013
),
cte1 as (select c.Match_Id,c.Season_Year,t.Team_Name from cte c 
join Team t on c.Match_Winner=t.Team_Id
where Team_Name='Royal Challengers Bangalore')
select count(distinct Match_Id) as RCB_WIN from cte1



-- 5.	List the top 10 players according to their strike rate in the last 4 seasons
with season_id_lastfouryears as (
 select distinct Season_Id from Season where Season_Year>=(select max(Season_Year)-3 from Season)
),
cte as (
select distinct Match_Id from Matches where Season_Id in ( select Season_Id from season_id_lastfouryears)
),
player_stats as 
(
select Striker,sum(Runs_Scored) as total_runs_scored,count(Ball_Id) as Total_balls_faced
from Ball_by_Ball 
where Match_Id in (select Match_Id from cte)
group by Striker
),
Strike_Rate as 
(select Striker,total_runs_scored,Total_balls_faced, round((total_runs_scored*100/Total_balls_faced),2) as Strike_Rate
from player_stats)

select p.Player_Name,s.total_runs_scored,s.Total_balls_faced,s.Strike_Rate 
from Strike_Rate s join Player p 
on s.Striker=p.Player_Id
order by s.Strike_Rate desc
limit 10


-- 6.	What are the average runs scored by each batsman considering all the seasons?
with cte as (
    select 
        p.player_id,
        p.player_name,
        b.runs_scored,
        b.match_id 
    from 
        player p 
    left join 
        ball_by_ball b 
    on 
        p.player_id = b.striker
)
select 
    player_id,
    player_name,
    coalesce(sum(runs_scored), 0) as total_runs,
    count(distinct match_id) as matches_played,
    coalesce(sum(runs_scored) / nullif(count(distinct match_id), 0), 0) as average_runs
from 
    cte
group by 
    player_id, player_name
order by 
    average_runs desc
limit 10


-- 7.	What are the average wickets taken by each bowler considering all the seasons?
with bowling_skills as (
select p.Player_Id,p.Player_Name,b.Bowling_skill 
from Player p join Bowling_Style b 
on p.Bowling_skill=b.Bowling_Id
),
cte as (
select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Bowler,
bs.Player_Name as Bowler_Name,bs.Bowling_skill 
from Ball_by_Ball b join Wicket_Taken w 
on b.Match_Id=w.Match_Id and b.Over_Id=w.Over_Id 
and b.Ball_Id=w.Ball_Id and b.Innings_No=w.Innings_No
join bowling_skills bs on bs.Player_Id=b.Bowler
),
cte2 as (
SELECT 
    Bowler_Name, 
    Bowling_skill,
    count(distinct Match_Id) as Total_Matches,
    COUNT(*)  AS Total_Wickets_Taken
FROM 
    cte
GROUP BY 
    Bowler_Name, 
    Bowling_skill
ORDER BY 
    Total_Wickets_Taken DESC
)
select Bowler_Name,Bowling_skill,Total_Wickets_Taken,Total_Matches,round((Total_Wickets_Taken)/(Total_Matches),2) as Average_Wickets
from cte2
order by (Total_Wickets_Taken)/(Total_Matches) desc


-- 8.	List all the players who have average runs scored greater than the overall average 
-- and who have taken wickets greater than the overall average
with cte as (
    select 
        p.player_id,
        p.player_name,
        b.runs_scored,
        b.match_id 
    from 
        player p 
    left join 
        ball_by_ball b 
    on 
        p.player_id = b.striker
),
cte1 as(
select 
    player_id,
    player_name,
    coalesce(sum(runs_scored), 0) as total_runs,
    count(distinct match_id) as matches_played,
    coalesce(sum(runs_scored) / nullif(count(distinct match_id), 0), 0) as average_runs
from 
    cte
group by 
    player_id, player_name
order by 
    average_runs desc
)
select * from cte1 where 
average_runs>(select avg(average_runs) from cte1)

with bowling_skills as (
select p.Player_Id,p.Player_Name,b.Bowling_skill 
from Player p join Bowling_Style b 
on p.Bowling_skill=b.Bowling_Id
),
cte as (
select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Bowler,
bs.Player_Name as Bowler_Name,bs.Bowling_skill 
from Ball_by_Ball b join Wicket_Taken w 
on b.Match_Id=w.Match_Id and b.Over_Id=w.Over_Id 
and b.Ball_Id=w.Ball_Id and b.Innings_No=w.Innings_No
join bowling_skills bs on bs.Player_Id=b.Bowler
),
cte2 as (
SELECT 
    Bowler_Name, 
    Bowling_skill,
    count(distinct Match_Id) as Total_Matches,
    COUNT(*)  AS Total_Wickets_Taken
FROM 
    cte
GROUP BY 
    Bowler_Name, 
    Bowling_skill
ORDER BY 
    Total_Wickets_Taken DESC
),
cte3 as (
select Bowler_Name,Bowling_skill,Total_Wickets_Taken,Total_Matches,round((Total_Wickets_Taken)/(Total_Matches),2) as Average_Wickets
from cte2
order by (Total_Wickets_Taken)/(Total_Matches) desc
)
select * from cte3 where Average_Wickets>(select avg(Average_Wickets) from cte3)





-- 9.	Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.
with cte as 
(select m.Match_Id,m.Team_1,t.Team_Name as team1,m.Team_2,t1.Team_Name as team2,m.Match_Winner,t2.Team_Name as winner,m.Venue_Id,v.Venue_Name
from Matches m join Team t on m.Team_1=t.Team_Id
join Team t1 on m.Team_2=t1.Team_Id 
join Team t2 on m.Match_Winner=t2.Team_Id
join Venue v on v.Venue_Id=m.Venue_Id
),
cte1 as 
(select Match_Id,team1,team2,winner,Venue_Name from cte 
where team1='Royal Challengers Bangalore' or team2='Royal Challengers Bangalore'
)

select Venue_Name, count(case when winner='Royal Challengers Bangalore' then 1 end) as win_count,
COUNT(CASE WHEN winner != 'Royal Challengers Bangalore' THEN 1 END) AS loss_count
from cte1
group by Venue_Name




-- 10.	What is the impact of bowling style on wickets taken?
with bowling_skills as (
select p.Player_Id,p.Player_Name,b.Bowling_skill 
from Player p join Bowling_Style b 
on p.Bowling_skill=b.Bowling_Id
),
cte as (
select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Bowler,
bs.Player_Name as Bowler_Name,bs.Bowling_skill 
from Ball_by_Ball b join Wicket_Taken w 
on b.Match_Id=w.Match_Id and b.Over_Id=w.Over_Id 
and b.Ball_Id=w.Ball_Id and b.Innings_No=w.Innings_No
join bowling_skills bs on bs.Player_Id=b.Bowler
)
select Bowling_skill,count(*) as Total_Wickets_Taken 
from cte 
group by Bowling_skill
order by count(*) desc



-- 11.	Write the SQL query to provide a status of whether the performance of the team is better than the previous
--  year's performance on the basis of the number of runs scored by the team in the season and the number of wickets taken 

-- Number of Runs Scored
with cte as 
(
select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Team_Batting,
(b.Runs_Scored + IFNULL(e.Extra_Runs, 0)) AS Total_Runs
from Ball_by_Ball b left join Extra_Runs e 
on b.Match_Id=e.Match_Id and 
b.Over_Id=e.Over_Id and b.Ball_Id=e.Ball_Id and 
b.Innings_No=e.Innings_No
),
cte1 as (
select c.Match_Id,year(m.Match_Date) as Year,c.Over_Id,c.Ball_Id,c.Innings_No,c.Team_Batting,c.Total_Runs,t.Team_Name 
from cte c join Matches m on c.Match_Id=m.Match_Id 
join Team t on t.Team_Id=c.Team_Batting)
select 
    team_name,
    sum(case when year = 2013 then total_runs else 0 end) as "2013",
    sum(case when year = 2014 then total_runs else 0 end) as "2014",
    sum(case when year = 2015 then total_runs else 0 end) as "2015",
    sum(case when year = 2016 then total_runs else 0 end) as "2016"
from 
    cte1
group by 
    team_name
order by 
    team_name;
    
-- Number of Wickets Taken Yearwise by each Team
with cte as 
(select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Bowler,b.Team_Bowling
from Ball_by_Ball b join Wicket_Taken w 
on b.Match_Id=w.Match_Id and b.Over_Id=w.Over_Id and 
b.Ball_Id=w.Ball_Id and b.Innings_No=w.Innings_No),
cte1 as 
(select c.Match_Id,year(m.Match_Date) as Year,c.Team_Bowling,
t.Team_Name
from cte c join Matches m on c.Match_Id=m.Match_Id 
join Team t on c.Team_Bowling=t.Team_Id
),
cte2 as 
(select Team_Name,Year,count(*) as Total_Wickets_Taken 
from cte1 
group by Team_Name,Year)
select Team_Name,
sum(case when Year=2013 then Total_Wickets_Taken else 0 end) as "2013",
sum(case when Year=2014 then Total_Wickets_Taken else 0 end) as "2014",
sum(case when Year=2015 then Total_Wickets_Taken else 0 end) as "2015",
sum(case when Year=2016 then Total_Wickets_Taken else 0 end) as "2016"
from cte2 
group by Team_Name
order by Team_Name

-- 12.	Can you derive more KPIs for the team strategy?
with cte as 
(
select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Team_Batting,
(b.Runs_Scored + IFNULL(e.Extra_Runs, 0)) AS Total_Runs
from Ball_by_Ball b left join Extra_Runs e 
on b.Match_Id=e.Match_Id and 
b.Over_Id=e.Over_Id and b.Ball_Id=e.Ball_Id and 
b.Innings_No=e.Innings_No
),
cte1 as (
select c.Match_Id,year(m.Match_Date) as Year,c.Over_Id,c.Ball_Id,c.Innings_No,c.Team_Batting,c.Total_Runs,t.Team_Name 
from cte c join Matches m on c.Match_Id=m.Match_Id 
join Team t on t.Team_Id=c.Team_Batting)
select 
    team_name,
    sum(case when year = 2013 then total_runs else 0 end) as "2013",
    sum(case when year = 2014 then total_runs else 0 end) as "2014",
    sum(case when year = 2015 then total_runs else 0 end) as "2015",
    sum(case when year = 2016 then total_runs else 0 end) as "2016"
from 
    cte1
group by 
    team_name
order by 
    team_name;


-- 13.	Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, 
-- rank the gender according to the average value.
with cte as 
(select b.Match_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Bowler,b.Team_Bowling
from Ball_by_Ball b join Wicket_Taken w 
on b.Match_Id=w.Match_Id and b.Over_Id=w.Over_Id and 
b.Ball_Id=w.Ball_Id and b.Innings_No=w.Innings_No),
cte1 as 
(select c.Match_Id,year(m.Match_Date) as Year,m.Venue_Id,c.Bowler,c.Team_Bowling,
t.Team_Name
from cte c join Matches m on c.Match_Id=m.Match_Id 
join Team t on c.Team_Bowling=t.Team_Id
),
cte2 as 
(
select c1.Match_Id,c1.Year,c1.Venue_Id,v.Venue_Name,c1.Bowler,p.Player_Name as Bowler_Name,c1.Team_Bowling,c1.Team_Name
from cte1 c1 join Player p on c1.Bowler=p.Player_Id 
join Venue v on v.Venue_Id=c1.Venue_Id
),
cte3 as 
(SELECT 
    cte2.Bowler_Name, 
    cte2.Venue_Name, 
    COUNT(*) AS Total_Wickets_Taken, 
    COUNT(DISTINCT cte2.Match_Id) AS Matches_Played, 
    CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT cte2.Match_Id) AS Avg_Wickets_Per_Match
FROM 
    cte2
GROUP BY 
    cte2.Bowler_Name, 
    cte2.Venue_Name
ORDER BY 
    Avg_Wickets_Per_Match DESC
)
select Bowler_Name,Venue_Name,Avg_Wickets_Per_Match,dense_rank() over(order by Avg_Wickets_Per_Match desc) as "Rank"
from cte3
order by Avg_Wickets_Per_Match desc


-- 14.	Which of the given players have consistently performed well in past seasons? (will you use any visualization to solve the problem)
-- For Batsman
	with cte as 
	(select b.Striker,p.Player_Name,b.Runs_Scored,m.Match_Id,m.Venue_Id
	from Ball_by_Ball b join Matches m on b.Match_Id=m.Match_Id
	join Player p on p.Player_Id=b.Striker)

	select Striker as Player_Id,Player_Name,count(distinct Match_Id) as Total_Matches_Played,sum(Runs_Scored) as Total_Runs_Scored,
	sum(Runs_Scored)/count(distinct Match_Id) as Average
	from cte 
	group by Striker,Player_Name
	order by Average desc
	limit 10;
-- For Bowler
with cte as (
select b.Match_Id,m.Venue_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Bowler as Player_Id,
p.Player_Name
from Ball_by_Ball b join Wicket_Taken w 
on b.Match_Id=w.Match_Id and b.Over_Id=w.Over_Id and 
b.Ball_Id=w.Ball_Id and b.Innings_No=w.Innings_No
join Matches m on m.Match_Id=b.Match_Id
join Player p on p.Player_Id=b.Bowler
)
select Player_Id,Player_Name,count(distinct Match_Id) as Total_Match_Played,
count(*) as Total_Wickets_Taken
from cte 
group by Player_Id,Player_Name
order by Total_Wickets_Taken desc
limit 10;


-- 15.	Are there players whose performance is more suited to specific venues or conditions? (how would you present this using charts?) 
-- For Batsman
with cte as 
(select b.Striker,p.Player_Name,b.Runs_Scored,m.Match_Id,m.Venue_Id
from Ball_by_Ball b join Matches m on b.Match_Id=m.Match_Id
join Player p on p.Player_Id=b.Striker),
cte1 as (
select c.Match_Id,c.Venue_Id,v.Venue_Name,c.Striker as Player_Id,c.Player_Name,
c.Runs_Scored  from cte c join Venue v on 
c.Venue_Id=v.Venue_Id)
select Player_Id,Player_Name,Venue_Id,Venue_Name,
count(distinct Match_Id) as Total_Matches_Played,
sum(Runs_Scored) as Total_Runs_Scored,
round(sum(Runs_Scored)/count(distinct Match_Id),2) as Average_Runs_Scored
from cte1 
group by Player_Id,Player_Name,Venue_Id,Venue_Name
order by Average_Runs_Scored desc
limit 10
-- For Bowlers
with cte as
(
select b.Match_Id,m.Venue_Id,b.Over_Id,b.Ball_Id,b.Innings_No,b.Bowler as Player_Id,
p.Player_Name
from Ball_by_Ball b join Wicket_Taken w 
on b.Match_Id=w.Match_Id and b.Over_Id=w.Over_Id and 
b.Ball_Id=w.Ball_Id and b.Innings_No=w.Innings_No
join Matches m on m.Match_Id=b.Match_Id
join Player p on p.Player_Id=b.Bowler
),
cte1 as 
(select c.Match_Id,c.Venue_Id,v.Venue_Name,c.Over_Id,c.Ball_Id,
c.Innings_No,c.Player_Id,c.Player_Name
from cte c join Venue v 
on c.Venue_Id=v.Venue_Id)
select Player_Id,Player_Name,Venue_Id,Venue_Name,count(distinct Match_Id) as Total_Matches_Played,
count(*) as Total_Wickets_Taken
from cte1 
group by Player_Id,Player_Name,Venue_Id,Venue_Name
order by Total_Wickets_Taken desc
limit 10































