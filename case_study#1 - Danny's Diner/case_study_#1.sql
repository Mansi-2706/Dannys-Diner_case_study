SELECT * FROM [dbo].[members];
SELECT * FROM [dbo].[menu];
SELECT * FROM [dbo].[salesN];

-- 1. What is the total amount each customer spent at the restaurant?

SELECT 
	s.customer_id, 
	SUM(price) AS total_amount 
FROM [dbo].[menu] AS m
INNER JOIN [dbo].[salesN] AS s
ON m.product_id = s.product_id
GROUP BY customer_id;

/* 
customer_id	total_amount
	A			76
	B			74
	C			36
*/

-- 2. How many days has each customer visited the restaurant?

SELECT 
	customer_id, 
	COUNT(DISTINCT order_date) AS days_visited
FROM [dbo].[salesN]
GROUP BY customer_id;

/*
customer_id	days_visited
	A	        4
	B			6
	C			2
*/

-- 3. What was the first item from the menu purchased by each customer?

WITH ranked_item AS (
SELECT 
	s.customer_id, 
	s.order_date, 
	m.product_name,
	DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS rank
FROM [dbo].[menu] AS m
INNER JOIN [dbo].[salesN] AS s
ON m.product_id = s.product_id
)
SELECT 
	DISTINCT customer_id, 
	product_name
FROM ranked_item
WHERE rank = 1

/*
customer_id	  product_name
		A	    curry
		A	    sushi
		B	    curry
		C	    ramen
*/

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT 
	TOP 1 m.product_name, 
	COUNT(s.product_id) AS most_purchased
FROM [dbo].[menu] AS m
INNER JOIN [dbo].[salesN] AS s
ON m.product_id = s.product_id
GROUP BY m.product_name
ORDER BY most_purchased DESC

/*
product_name	most_purchased
	ramen			8
*/

-- 5. Which item was the most popular for each customer?

WITH most_popular_ AS (
SELECT 
	s.customer_id, 
	m.product_name, 
	COUNT(s.product_id) AS most_popular,
    DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY COUNT(s.customer_id) DESC) AS rank
FROM [dbo].[menu] AS m
INNER JOIN [dbo].[salesN] AS s
ON m.product_id = s.product_id
GROUP BY s.customer_id, m.product_name
)
SELECT 
	customer_id, 
	product_name, 
	most_popular
FROM most_popular_
WHERE rank = 1

/*
customer_id		product_name	most_popular
		A			ramen				3
		B			sushi				2
		B			curry				2
		B			ramen				2
		C			ramen				3
*/

-- 6. Which item was purchased first by the customer after they became a member?

WITH member_joined AS (
SELECT 
	mem.customer_id, 
	s.product_id,
    ROW_NUMBER() OVER(PARTITION BY mem.customer_id ORDER BY s.order_date) AS row_num 
FROM [dbo].[members] AS mem 
INNER JOIN [dbo].[salesN] AS s
ON mem.customer_id = s.customer_id
AND mem.join_date < s.order_date
)
SELECT 
	mj.customer_id,
	m.product_name
FROM member_joined AS mj INNER JOIN [dbo].[menu] AS m
ON mj.product_id = m.product_id
WHERE row_num = 1
ORDER BY customer_id ASC;

/*
customer_id	  product_name
      A			ramen
      B			sushi
*/

-- 7. Which item was purchased just before the customer became a member?

WITH purchased_prior AS (
SELECT 
	mem.customer_id, 
	s.product_id,
    ROW_NUMBER() OVER(PARTITION BY mem.customer_id ORDER BY s.order_date DESC) AS row_num 
FROM [dbo].[members] AS mem 
INNER JOIN [dbo].[salesN] AS s
ON mem.customer_id = s.customer_id
AND mem.join_date > s.order_date
)
SELECT 
	pp.customer_id,
	m.product_name
FROM purchased_prior AS pp INNER JOIN [dbo].[menu] AS m
ON pp.product_id = m.product_id
WHERE row_num = 1
ORDER BY customer_id ASC;
/*
customer_id	 product_name
    A	       sushi
    B	       sushi
*/
 
-- 8. What is the total items and amount spent for each member before they became a member?

SELECT 
	sales.customer_id, 
	COUNT(sales.product_id) AS total_items,
	SUM(menu.price) AS amount_spent
FROM [dbo].[members] AS mem 
INNER JOIN [dbo].[salesN] AS sales
ON mem.customer_id = sales.customer_id
AND mem.join_date > sales.order_date
INNER JOIN [dbo].[menu] AS menu
ON menu.product_id = sales.product_id
GROUP BY sales.customer_id
ORDER BY sales.customer_id;
/*
customer_id	 total_items  amount_spent
		A		2			25
		B		3			40
*/

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH price_points AS (
SELECT 
	product_id,
	CASE WHEN product_id = 1 THEN price * 20 --product_id = 1 is for sushi
	ELSE price * 10
	END AS points
FROM [dbo].[menu]
)
SELECT 
	sales.customer_id,
	SUM(pp.points) AS total_points
FROM price_points AS pp INNER JOIN [dbo].[salesN] AS sales
ON pp.product_id = sales.product_id
GROUP BY customer_id;

/*
customer_id	  total_points
		A	      860
		B	      940
		C	      360
*/

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at the end of January?

WITH dates_cal AS (
  SELECT 
    customer_id, 
    CONVERT(DATE, join_date) AS join_date, 
    DATEADD(DAY, 6, CONVERT(DATE, join_date)) AS valid_date,
    DATEADD(DAY, -1, DATEADD(MONTH, 1, '2021-01-31')) AS last_date
  FROM [dbo].[members]
)

SELECT 
  sales.customer_id, 
  SUM(CASE
    WHEN menu.product_name = 'sushi' THEN 2 * 10 * menu.price
    WHEN sales.order_date BETWEEN dates.join_date AND dates.valid_date THEN 2 * 10 * menu.price
    ELSE 10 * menu.price END) AS points
FROM [dbo].[salesN] AS sales
  INNER JOIN dates_cal AS dates
  ON sales.customer_id = dates.customer_id
  AND dates.join_date <= sales.order_date
  AND sales.order_date <= dates.last_date
  INNER JOIN [dbo].[menu] AS menu
  ON sales.product_id = menu.product_id
GROUP BY sales.customer_id;

/*
customer_id		points
	A	         1020
	B	         440
*/