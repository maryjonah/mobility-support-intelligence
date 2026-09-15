-- 1. Agent labor cost per ticket

WITH event_labor AS (
	SELECT
		se.ticket_id,
		SUM(se.handling_minutes / 60.0 * a.cost_per_hout) AS agent_labor_cost
	FROM support_events as se
	JOIN agents as a
	ON se.agent_id = a.agent_id
	JOIN support_tickets as st
	ON se.ticket_id = st.ticket_id
	GROUP BY se.ticket_id
)
SELECT
	ticket_id,
	ROUND(agent_labor_cost, 2) AS agent_labor_cost
FROM event_labor;


-- 2. Financial adjustments per ticket

WITH deduplicated_adjustments AS (
	SELECT DISTINCT ON (adjustment_id)
		adjustment_id, 
		ticket_id,
		trip_id,
		adjustment_type,
		amount,
		reason,
		created_at,
		currency
	FROM financial_adjustments
	ORDER BY adjustment_id, created_at
)
SELECT
	ticket_id,
	ROUND(SUM(amount), 2) AS adjustment_cost
FROM deduplicated_adjustments
GROUP BY ticket_id
ORDER BY adjustment_cost DESC;


-- 3. Total sum by refunds or appeasement credit

WITH deduplicated_adjustments AS (
	SELECT DISTINCT ON (adjustment_id)
		adjustment_id,
		ticket_id,
		adjustment_type,
		amount
	FROM financial_adjustments
	ORDER BY adjustment_id
),
adjustment_summary AS (
	SELECT
		ticket_id,
		SUM(CASE WHEN adjustment_type = 'refund' THEN amount ELSE 0 END) AS refund_cost,
		SUM(CASE WHEN adjustment_type = 'appeasement_credit' THEN amount ELSE 0 END) AS appeasement_cost
	FROM deduplicated_adjustments
	GROUP BY ticket_id
)
SELECT
	ticket_id,
	ROUND(refund_cost, 2) AS refund_cost,
	ROUND(appeasement_cost, 2) AS appeasement_cost,
	ROUND(refund_cost + appeasement_cost, 2) AS total_adjustment_cost
FROM adjustment_summary
ORDER BY total_adjustment_cost DESC;


-- 4. Total Support Cost per Ticket

WITH event_labor AS (
	SELECT
		se.ticket_id,
		SUM(se.handling_minutes / 60. * a.cost_per_hout) AS agent_labor_cost
	FROM support_events as se
	JOIN agents as a
	ON se.agent_id = a.agent_id
	JOIN support_tickets as st
	ON se.ticket_id = st.ticket_id
	GROUP BY se.ticket_id
),
deduplicated_adjustments AS (
	SELECT DISTINCT ON (adjustment_id)
		adjustment_id,
		ticket_id,
		adjustment_type,
		amount
	FROM financial_adjustments
	ORDER BY adjustment_id
),
adjustment_summary AS (
	SELECT
		ticket_id,
		SUM(CASE WHEN adjustment_type = 'refund' THEN amount ELSE 0 END) AS refund_cost,
		SUM(CASE WHEN adjustment_type = 'appeasement_credit' THEN amount ELSE 0 END) AS appeasement_cost
	FROM deduplicated_adjustments
	GROUP BY ticket_id
),
ticket_cost AS (
	SELECT
		st.ticket_id,
		st.trip_id,
		COALESCE(el.agent_labor_cost, 0) AS agent_labor_cost,
		COALESCE(adj.refund_cost, 0) AS refund_cost,
		COALESCE(adj.appeasement_cost, 0) AS appeasement_cost
	FROM support_tickets as st
	LEFT JOIN event_labor as el
	ON st.ticket_id = el.ticket_id
	LEFT JOIN adjustment_summary as adj
	ON st.ticket_id = adj.ticket_id
)
SELECT
	ticket_id,
	trip_id,
	ROUND(agent_labor_cost, 2) AS agent_labor_cost,
	ROUND(refund_cost, 2) AS refund_cost,
	ROUND(appeasement_cost, 2) AS appeasement_cost,
	ROUND(agent_labor_cost + refund_cost + appeasement_cost, 2) AS total_support_cost
FROM ticket_cost
ORDER BY total_support_cost DESC;


-- 5. Support Cost per 1,000 Trips

WITH event_labor AS (
	SELECT
		se.ticket_id,
		SUM(se.handling_minutes / 60.0 * a.cost_per_hout) AS agent_labor_cost
	FROM support_events as se
	JOIN agents as a
	ON se.agent_id = a.agent_id
	JOIN support_tickets as st
	ON se.ticket_id = st.ticket_id
	GROUP BY se.ticket_id
),
deduplicated_adjustments AS (
	SELECT DISTINCT ON (adjustment_id)
		adjustment_id,
		ticket_id,
		amount
	FROM financial_adjustments
	ORDER BY adjustment_id
),
adjustment_summary AS (
	SELECT
		ticket_id,
		SUM(amount) AS adjustment_cost
	FROM deduplicated_adjustments
	GROUP BY ticket_id
),
ticket_cost AS (
	SELECT
		st.ticket_id,
		st.trip_id,
		COALESCE(el.agent_labor_cost, 0) + COALESCE(adj.adjustment_cost, 0) AS total_support_cost
	FROM support_tickets as st
	LEFT JOIN event_labor as el
	ON st.ticket_id = el.ticket_id
	LEFT JOIN adjustment_summary as adj
	ON st.ticket_id = adj.ticket_id
),
cost_by_ride_type AS (
	SELECT
		t.ride_type,
		COUNT(DISTINCT t.trip_id) AS total_trips,
		COALESCE(SUM(tc.total_support_cost), 0) AS total_support_cost
	FROM trips as t
	LEFT JOIN ticket_cost as tc
	ON t.trip_id = tc.trip_id
	GROUP BY t.ride_type
)
SELECT
	ride_type,
	total_trips,
	ROUND(total_support_cost, 2) AS total_support_cost,
	ROUND(total_support_cost / NULLIF(total_trips, 0) * 1000, 2) AS support_cost_per_1000_trips
FROM cost_by_ride_type
ORDER BY support_cost_per_1000_trips DESC;


-- 6. Refund Cost per Ticket

WITH deduplicated_adjustments AS (
	SELECT DISTINCT ON (adjustment_id)
		adjustment_id,
		ticket_id,
		adjustment_type,
		amount
	FROM financial_adjustments
	ORDER BY adjustment_id
),
refund_summary AS (
	SELECT
		SUM(amount) AS total_refund_cost
	FROM deduplicated_adjustments
	WHERE adjustment_type = 'refund'
)
SELECT
	ROUND(total_refund_cost, 2) AS total_refund_cost,
	COUNT(st.ticket_id) AS support_tickets,
	ROUND(total_refund_cost / NULLIF(COUNT(st.ticket_id), 0), 2) AS refund_cost_per_ticket
FROM support_tickets as st
CROSS JOIN refund_summary
GROUP BY total_refund_cost;


-- 6. Refund Cost per Ticket per Ride Type

WITH deduplicated_adjustments AS (
	SELECT DISTINCT ON (adjustment_id)
		adjustment_id,
		ticket_id,
		adjustment_type,
		amount
	FROM financial_adjustments
	ORDER BY adjustment_id
),
refund_by_ticket AS (
	SELECT
		ticket_id,
		SUM(amount) AS refund_cost
	FROM deduplicated_adjustments
	WHERE adjustment_type = 'refund'
	GROUP BY ticket_id
)
SELECT 
	t.ride_type,
	COUNT(st.ticket_id) AS support_tickets,
	ROUND(
		COALESCE(SUM(r.refund_cost), 0)
	,2) AS total_refund_cost,
	ROUND(
		COALESCE(SUM(r.refund_cost),0) / NULLIF(COUNT(st.ticket_id), 0)
	,2) AS refund_cost_per_ticket
FROM support_tickets as st
JOIN trips as t
ON st.trip_id = t.trip_id
LEFT JOIN refund_by_ticket as r
ON st.ticket_id = r.ticket_id
GROUP BY t.ride_type
ORDER BY refund_cost_per_ticket DESC;