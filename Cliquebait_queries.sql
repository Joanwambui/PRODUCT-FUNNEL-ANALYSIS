--How many users are there?
SELECT *
FROM [data_mart].[clique_bait].[users]


SELECT COUNT(DISTINCT user_id )
FROM [data_mart].[clique_bait].[users];

SELECT *
FROM [data_mart].[clique_bait].[users]
WHERE user_id = 2

--How many cookies does each user have on average?
SELECT user_id, AVG(cookie_count) AS average_cookies_per_user
FROM (
    SELECT user_id,COUNT(cookie_id) AS cookie_count
    FROM clique_bait.users
    GROUP BY user_id
) subquery
GROUP BY user_id;

with cookies as
   (select user_id,count(distinct cookie_id) as total_cookies
 from clique_bait.users
 group by user_id
 )
 select round(cast(sum(total_cookies)/count(user_id) as float),2)
 as avg_cookies
 from cookies

--What is the unique number of visits by all users per month?
SELECT *
FROM clique_bait.events_
 
SELECT COUNT( DISTINCT visit_id)
FROM clique_bait.events_

select datepart(month,event_time) as Month_Number,
  datename(month,event_time) as Months, count(distinct visit_id) as Visits
   from clique_bait.events_
   group by  datepart(month,event_time),datename(month,event_time)
   order by 1,2

--What is the number of events for each event type?
SELECT COUNT(event_type) as eventcounts
FROM clique_bait.events_
--GROUP BY event_type

select  distinct e.event_type,event_name,count(*) as counts
   from clique_bait.events_ e join clique_bait.event_identifier ei
   on e.event_type=ei.event_type
   group by e.event_type,event_name
   order by 1

--What is the percentage of visits which have a purchase event?
SELECT COUNT(event_type) event_counts
FROM clique_bait.events_
WHERE event_type = 3
GROUP BY event_type

SELECT 
    (COUNT(CASE WHEN event_type = 3 THEN event_type END) * 100 / COUNT(event_type)) AS percentage
FROM clique_bait.events_;

select round(count(distinct visit_id)*100.0/(select count(distinct visit_id) from clique_bait.events_ e ) ,2) 
   as purchase_prcnt
   from clique_bait.events_ e join clique_bait.event_identifier ei
   on e.event_type=ei.event_type
   where event_name='Purchase'
--What is the percentage of visits which view the checkout page but do not have a purchase event?
SELECT *
FROM clique_bait.page_hierarchy

SELECT * 
FROM clique_bait.page_hierarchy h
INNER JOIN clique_bait.events_ e
ON e.page_id=h.page_id

SELECT page_name , event_type
FROM clique_bait.page_hierarchy h
INNER JOIN clique_bait.events_ e
ON e.page_id=h.page_id
---WHERE event_type=3
WHERE page_name = 'Checkout'

with abc as(
   select  distinct visit_id,
   sum(case when event_name!='Purchase'and page_id=12 then 1 else 0 end) as checkouts,
   sum(case when event_name='Purchase' then 1 else 0 end) as purchases
   from
   clique_bait.events_ e join clique_bait.event_identifier ei
   on e.event_type=ei.event_type
   group by visit_id
   )
   select sum(checkouts) as total_checkouts,sum(purchases) as total_purchases,
   100-round(sum(purchases)*100.0/sum(checkouts),2) as prcnt
   from abc

--What are the top 3 pages by number of views?


SELECT page_id, COUNT(page_id) AS total_views, COUNT(DISTINCT cookie_id) AS distinct_cookies
FROM clique_bait.events_
GROUP BY page_id
ORDER BY total_views DESC
TOP 3;

--What is the number of views and cart adds for each product category?


---What are the top 3 products by purchases?
select top 3 page_name, count( visit_id) as visits
 from clique_bait.events_ e join
 clique_bait.page_hierarchy p on
 e.page_id=p.page_id
 group by page_name
 order by 2 desc

 --What is the number of views and cart adds for each product category?
 select product_category,
  sum(case when event_name='Page View' then 1 else 0 end) as views,
  sum(case when event_name='Add to Cart' then 1 else 0 end) as cart_adds
  from clique_bait.events_ e join clique_bait.event_identifier ei   
  on e.event_type=ei.event_type join clique_bait.page_hierarchy p
  on p.page_id=e.page_id
  where product_category is not null
  group by product_category

'''
Product Funnel Analysis
Using a single SQL query — create a new output table which has the following details:

How many times was each product viewed?
How many times was each product added to cart?
How many times was each product added to a cart but not purchased (abandoned)?
How many times was each product purchased?
'''
drop table if exists product_tab
create table product_tab
(
page_name varchar(50),
page_views int,
cart_adds int,
cart_add_not_purchase int,
cart_add_purchase int
);
with tab1 as(
 select e.visit_id,page_name, 
 sum( case when event_name='Page View' then 1 else 0 end)as view_count,
 sum( case when event_name='Add to Cart' then 1 else 0 end)as cart_adds
 from clique_bait.events_ e join  clique_bait.page_hierarchy p
 on e.page_id=p.page_id 
 join clique_bait.event_identifier ei   
 on e.event_type=ei.event_type
 where product_id is not null
 group by e.visit_id,page_name
),
--creating purcchaseid because for purchased products the product_id is null
 tab2 as(
select distinct(visit_id) as Purchase_id
from clique_bait.events_ e join clique_bait.event_identifier ei   
 on e.event_type=ei.event_type where event_name = 'Purchase'),
tab3 as(
select *, 
(case when purchase_id is not null then 1 else 0 end) as purchase
from tab1 left join tab2
on visit_id = purchase_id),
tab4 as(
select page_name, sum(view_count) as Page_Views, sum(cart_adds) as Cart_Adds, 
sum(case when cart_adds = 1 and purchase = 0 then 1 else 0
 end) as Cart_Add_Not_Purchase,
sum(case when cart_adds= 1 and purchase = 1 then 1 else 0
 end) as Cart_Add_Purchase
from tab3
group by page_name)

insert into product_tab
(page_name ,page_views ,cart_adds ,cart_add_not_purchase ,cart_add_purchase )
select page_name, page_views, cart_adds, cart_add_not_purchase, cart_add_purchase
from tab4
select * from product_tab


drop table if exists product_category_tab
create table product_category_tab
(product_category varchar(50),
page_views int,
cart_adds int ,
cart_add_not_purchase int,
cart_add_purchase int )
;
with tab1 as(
 select e.visit_id,product_category, page_name, 
 sum( case when event_name='Page View' then 1 else 0 end)as view_count,
 sum( case when event_name='Add to Cart' then 1 else 0 end)as cart_adds
  --sum( case when event_name='Purchase' then 1 else 0 end)as purchases
 from clique_bait.events_ e join  clique_bait.page_hierarchy p
 on e.page_id=p.page_id 
 join clique_bait.event_identifier ei   
 on e.event_type=ei.event_type
 where product_id is not null
 group by e.visit_id,product_category,page_name
),
--creating purcchaseid because for purchased products the product_id is null
 tab2 as(
select distinct(visit_id) as Purchase_id
from clique_bait.events_ e join clique_bait.event_identifier ei   
 on e.event_type=ei.event_type where event_name = 'Purchase'),
tab3 as(
select *, 
(case when purchase_id is not null then 1 else 0 end) as purchase
from tab1 left join tab2
on visit_id = purchase_id),
tab4 as(
select product_category, sum(view_count) as Page_Views, sum(cart_adds) as Cart_Adds, 
sum(case when cart_adds = 1 and purchase = 0 then 1 else 0
 end) as Cart_Add_Not_Purchase,
sum(case when cart_adds= 1 and purchase = 1 then 1 else 0
 end) as Cart_Add_Purchase
from tab3
group by  product_category)

insert into product_category_tab
(product_category,page_views ,cart_adds ,cart_add_not_purchase ,cart_add_purchase )
select product_category, page_views, cart_adds, cart_add_not_purchase, cart_add_purchase
from tab4
select * from product_category_tab