-- 1. Issue type drivers

-- 1.1 Which issue types generate the most support demand for AV or Traditional trips?

SELECT
	t.ride_type,
	st.issue_type,
	COUNT(*) AS support_tickets
FROM support_tickets as st
JOIN trips as t
ON st.trip_id = t.trip_id
GROUP BY t.ride_type, st.issue_type
ORDER BY t.ride_type, support_tickets DESC;

-- 1.2 Percentage of ride type ticket belonging to an issue
WITH issue_counts AS (
	SELECT
		t.ride_type,
		st.issue_type,
		COUNT(*) AS support_tickets
	FROM support_tickets as st
	JOIN trips as t
	ON st.trip_id = t.trip_id
	GROUP BY t.ride_type, st.issue_type
),
ride_type_totals AS (
	SELECT
		ride_type,
		SUM(support_tickets) AS total_support_tickets
	FROM issue_counts
	GROUP BY ride_type
)
SELECT 
	ic.ride_type,
	ic.issue_type,
	ic.support_tickets,
	ROUND(ic.support_tickets::NUMERIC / NULLIF(rt.total_support_tickets, 0) * 100 ,2) AS pct_of_ride_type_tickets
FROM issue_counts as ic
JOIN ride_type_totals as rt
ON ic.ride_type = rt.ride_type
ORDER BY ic.ride_type, pct_of_ride_type_tickets DESC;

-- 1.3 Which issues are operationally difficult?
WITH escalation_summary AS (
	SELECT
		st.ticket_id,
		MAX(CASE WHEN se.escalation_flag = TRUE THEN 1 ELSE 0 END) AS was_escalated
	FROM support_tickets as st
	LEFT JOIN support_events as se
	ON st.ticket_id = se.ticket_id
	GROUP BY st.ticket_id
),
repeat_summary AS (
	SELECT
		parent.ticket_id,
		MAX(CASE WHEN child.ticket_id IS NOT NULL THEN 1 ELSE 0 END) AS had_repeat_contact
	FROM support_tickets as parent
	LEFT JOIN support_tickets as child
	ON child.parent_ticket_id = parent.ticket_id
	GROUP BY parent.ticket_id
),
ticket_level AS (
	SELECT
		st.ticket_id,
		st.parent_ticket_id,
		st.issue_type,
		st.opened_at,
		st.resolved_at,
		t.ride_type,
		es.was_escalated,
		rs.had_repeat_contact
	FROM support_tickets as st
	JOIN trips as t
	ON st.trip_id = t.trip_id
	LEFT JOIN escalation_summary as es
	ON st.ticket_id = es.ticket_id
	LEFT JOIN repeat_summary as rs
	ON st.ticket_id = rs.ticket_id
)
SELECT 
	ride_type,
	issue_type,
	COUNT(*) AS support_tickets,
	ROUND(AVG(was_escalated) * 100, 2) AS escalation_rate_pct,
	ROUND(
		AVG(CASE WHEN parent_ticket_id IS NULL THEN had_repeat_contact END) * 100
	,2) AS repeat_contact_rate_pct,
	ROUND(
		AVG(
			CASE WHEN resolved_at > opened_at THEN EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 60 END
		)
	,2) AS avg_resolution_minutes
FROM ticket_level
GROUP BY ride_type, issue_type
ORDER BY ride_type, support_tickets DESC;

-- 1.4. Financial cost by issue
WITH event_labor AS (
	SELECT
		se.ticket_id,
		SUM(se.handling_minutes / 60.0 * a.cost_per_hout) AS labor_cost
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
		st.issue_type,
		t.ride_type,
		COALESCE(el.labor_cost, 0) + COALESCE(adj.adjustment_cost, 0) AS total_support_cost
	FROM support_tickets as st
	JOIN trips as t
	ON st.trip_id = t.trip_id
	LEFT JOIN event_labor as el
	ON st.ticket_id = el.ticket_id
	LEFT JOIN adjustment_summary as adj
	ON st.ticket_id = adj.ticket_id
)
SELECT
	ride_type,
	issue_type,
	COUNT(*) AS support_tickets,
	ROUND(SUM(total_support_cost), 2) AS total_support_cost,
	ROUND(AVG(total_support_cost), 2) AS avg_support_cost_per_ticket
FROM ticket_cost
GROUP BY ride_type, issue_type
ORDER BY ride_type, total_support_cost DESC;

-- 1.5 Support Performance by Issue Type

WITH escalation_summary AS (
	SELECT
	st.ticket_id,
	MAX(CASE WHEN se.escalation_flag = TRUE THEN 1 ELSE 0 END) AS was_escalated
	FROM support_tickets as st
	LEFT JOIN support_events as se
	ON st.ticket_id = se.ticket_id
	GROUP BY st.ticket_id
),
repeat_summary AS (
	SELECT
		parent.ticket_id,
		MAX(CASE WHEN child.ticket_id IS NOT NULL THEN 1 ELSE 0 END) AS had_repeat_contact
	FROM support_tickets AS parent
	LEFT JOIN support_tickets as child
	ON child.parent_ticket_id = parent.ticket_id
	GROUP BY parent.ticket_id
),
event_labor AS (
	SELECT
		se.ticket_id,
		SUM(se.handling_minutes / 60.0 * a.cost_per_hout) AS labor_cost
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
ticket_level AS (
	SELECT
		st.ticket_id,
		st.parent_ticket_id,
		st.issue_type,
		st.opened_at,
		st.resolved_at,
		t.ride_type,
		t.city,
		es.was_escalated,
		rs.had_repeat_contact,
		COALESCE(el.labor_cost, 0) + COALESCE(adj.adjustment_cost, 0) AS total_support_cost
	FROM support_tickets as st
	JOIN trips as t
	ON st.trip_id = t.trip_id
	LEFT JOIN escalation_summary as es
	ON st.ticket_id = es.ticket_id
	LEFT JOIN repeat_summary as rs
	ON st.ticket_id = rs.ticket_id
	LEFT JOIN event_labor as el
	ON st.ticket_id = el.ticket_id
	LEFT JOIN adjustment_summary as adj
	ON st.ticket_id = adj.ticket_id
)
SELECT
	issue_type,
	COUNT(*) AS support_tickets,
	ROUND(AVG(was_escalated), 2) AS escalation_rate_pct,
	ROUND(AVG(CASE WHEN parent_ticket_id IS NULL THEN had_repeat_contact END) * 100, 2) AS repeat_contact_rate_pct,
	ROUND(
		AVG(
			CASE
			WHEN resolved_at >= opened_at
			THEN
				EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 60 END
		)
	, 2) AS avg_resolution_minutes,
	ROUND(SUM(total_support_cost), 2) AS total_support_cost,
	ROUND(AVG(total_support_cost), 2) AS avg_support_per_ticket
FROM ticket_level
WHERE ride_type = 'AV'
GROUP BY issue_type
ORDER BY total_support_cost DESC;


-- 2. City x Ride Drivers

-- 2.1 Is the AV support problem happening everywhere, or it is concentrated in specific cities?

SELECT
	t.city,
	t.ride_type,
	COUNT(st.ticket_id) AS support_tickets
FROM trips as t
LEFT JOIN support_tickets as st
ON t.trip_id = st.trip_id
GROUP BY t.city, t.ride_type
ORDER BY t.city, t.ride_type;

-- 2.2 Contact rate per 1,000 trips by city and ride type

SELECT
	t.city,
	t.ride_type,
	COUNT(DISTINCT t.trip_id) AS trips,
	COUNT(st.ticket_id) AS support_contacts,
	ROUND(
		COUNT(st.ticket_id)::NUMERIC / NULLIF(COUNT(DISTINCT t.trip_id), 0) * 1000, 2
	) AS contacts_per_1000_trips
FROM trips as t
LEFT JOIN support_tickets as st
ON t.trip_id = st.trip_id
GROUP BY t.city, t.ride_type
ORDER BY t.city, contacts_per_1000_trips;

-- 2.3 Operational difficulty by city

WITH escalation_summary AS (
	SELECT
		st.ticket_id,
		MAX(CASE WHEN se.escalation_flag = TRUE THEN 1 ELSE 0 END) AS was_escalated
	FROM support_tickets as st
	LEFT JOIN support_events as se
	ON st.ticket_id = se.ticket_id
	GROUP BY st.ticket_id
),
repeat_summary AS (
	SELECT
		parent.ticket_id,
		MAX(CASE WHEN child.ticket_id IS NOT NULL THEN 1 ELSE 0 END) AS had_repeat_contact
	FROM support_tickets as parent
	LEFT JOIN support_tickets as child
	ON child.parent_ticket_id = parent.ticket_id
	GROUP BY parent.ticket_id
),
ticket_level AS (
	SELECT
		st.ticket_id,
		st.parent_ticket_id,
		st.opened_at,
		st.resolved_at,
		t.city,
		t.ride_type,
		es.was_escalated,
		rs.had_repeat_contact
	FROM support_tickets as st
	JOIN trips as t
	ON st.trip_id = t.trip_id
	LEFT JOIN escalation_summary as es
	ON st.ticket_id = es.ticket_id
	LEFT JOIN repeat_summary as rs
	ON st.ticket_id = rs.ticket_id
)
SELECT
	city,
	ride_type,
	COUNT(*) AS support_tickets,
	ROUND(AVG(was_escalated) * 100, 2) AS escalation_rate_pct,
	ROUND(
		AVG(CASE WHEN parent_ticket_id IS NULL THEN had_repeat_contact END) * 100
	,2) AS repeat_contact_rate_pct,
	ROUND(
		AVG(CASE WHEN resolved_at >= opened_at THEN EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 60 END)
	,2) AS avg_resolution_minutes
FROM ticket_level
GROUP BY city, ride_type
ORDER BY city, ride_type;

-- 2.4 Support cost by city x ride type

WITH event_labor AS (
	SELECT
		se.ticket_id,
		SUM(se.handling_minutes / 60.0 * a.cost_per_hout) AS labor_cost
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
		COALESCE(el.labor_cost, 0) +  COALESCE(adj.adjustment_cost, 0) AS total_support_cost
	FROM support_tickets as st
	LEFT JOIN event_labor as el
	ON st.ticket_id = el.ticket_id
	LEFT JOIN adjustment_summary as adj
	ON st.ticket_id = adj.ticket_id
),
city_cost AS (
	SELECT
		t.city,
		t.ride_type,
		COUNT(DISTINCT t.trip_id) AS total_trips,
		COALESCE(SUM(tc.total_support_cost), 0) AS total_support_cost
	FROM trips as t
	LEFT JOIN ticket_cost as tc
	ON t.trip_id = tc.trip_id
	GROUP BY t.city, t.ride_type
)
SELECT
	city,
	ride_type,
	total_trips,
	ROUND(total_support_cost, 2) AS total_support_cost,
	ROUND(total_support_cost / NULLIF(total_trips, 0) * 1000, 2) AS support_cost_per_1000_trips
FROM city_cost
ORDER BY support_cost_per_1000_trips DESC;

-- 2.5 Within each city, which AV issues are creating the most support demand?

SELECT
	t.city,
	st.issue_type,
	COUNT(*) AS av_support_tickets
FROM support_tickets as st
JOIN trips as t
ON st.trip_id = t.trip_id
WHERE t.ride_type = 'AV'
GROUP BY t.city, st.issue_type
ORDER BY t.city, av_support_tickets DESC;

