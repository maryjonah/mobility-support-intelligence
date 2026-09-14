-- Metrics encompassing customer support and operations

-- 1. Contact Rate per 1,000 trips
SELECT
	COUNT(st.ticket_id) AS support_contacts,
	COUNT(DISTINCT t.trip_id) AS trips,
	ROUND(
		COUNT(st.ticket_id)::NUMERIC / NULLIF(COUNT(DISTINCT t.trip_id), 0) * 1000
	,2) AS contacts_per_1000_trips
FROM trips as t
LEFT JOIN support_tickets as st
ON t.trip_id = st.trip_id;

-- 1.1 Contact Rate per 1,000 trips based on ride type
SELECT
	t.ride_type,
	COUNT(st.ticket_id) AS support_contacts,
	COUNT(DISTINCT t.trip_id) AS trips,
	ROUND(
		COUNT(st.ticket_id)::NUMERIC / NULLIF(COUNT(DISTINCT t.trip_id), 0) * 1000
	, 2) AS contacts_per_1000_trips
FROM trips as t
LEFT JOIN support_tickets as st
ON t.trip_id = st.trip_id
GROUP BY t.ride_type
ORDER BY contacts_per_1000_trips DESC;


-- 2. Repeat Contact Rate
WITH eligible_primary_tickets AS (
	SELECT
		ticket_id,
		rider_id,
		issue_type,
		opened_at,
		resolved_at
	FROM support_tickets
	WHERE parent_ticket_id IS NULL
	AND resolved_at >= opened_at
),
repeat_flags AS (
	SELECT
		p.ticket_id,
		MAX(CASE WHEN child.ticket_id IS NOT NULL THEN 1 ELSE 0 END) AS has_repeat_contact
	FROM eligible_primary_tickets as p
	LEFT JOIN support_tickets as child
	ON child.parent_ticket_id = p.ticket_id
	AND child.rider_id = p.rider_id
	AND child.issue_type = p.issue_type
	AND child.opened_at >= p.resolved_at
	AND child.opened_at <= p.resolved_at + INTERVAL '7 days'
	GROUP BY p.ticket_id
)
SELECT 
	COUNT(*) AS eligible_primary_tickets,
	SUM(has_repeat_contact) AS tickets_with_repeat_contacts,
	ROUND(AVG(has_repeat_contact) * 100, 2)
FROM repeat_flags;


-- 3. Escalation Rate
WITH ticket_escalation AS (
	SELECT
		st.ticket_id,
		MAX(
			CASE WHEN se.escalation_flag  = TRUE THEN 1 ELSE 0 END
		) AS was_escalated
	FROM support_tickets as st
	LEFT JOIN support_events as se
	ON st.ticket_id = se.ticket_id
	GROUP BY st.ticket_id
)
SELECT
	COUNT(*) AS support_tickets,
	SUM(was_escalated) AS escalated_tickets,
	ROUND(AVG(was_escalated) * 100, 2) AS escalation_pct_rate
FROM ticket_escalation;


-- 4. Average Resolution Time (starts at 5 in chatgpt)