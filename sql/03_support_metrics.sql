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
-- Remember we have some 'dirty' data where resolved_at < opened_at, so we will exclude these

SELECT
	issue_type,
	COUNT(*) AS resolved_tickets,
	ROUND(
		AVG(EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 60)
	, 2) AS avg_resolution_minutes
FROM support_tickets
WHERE status = 'resolved'
AND resolved_at >= opened_at
GROUP BY issue_type
ORDER BY avg_resolution_minutes DESC;


-- 5. Overall Customer Satisfaction Score (CSAT)
SELECT
	COUNT(*) AS valid_survey_responses,
	COUNT(*) FILTER(WHERE csat_score IN (4, 5)) AS satisfied_responses,
	ROUND(
		COUNT(*) FILTER(WHERE csat_score IN (4, 5))::NUMERIC / NULLIF(COUNT(*), 0) * 100
	, 2) AS csat_pct
FROM customer_feedback
WHERE csat_score BETWEEN 1 AND 5;


-- 6. CSAT by Issue Type
SELECT
	st.issue_type,
	COUNT(*) AS survey_responses,
	ROUND(
		COUNT(*) FILTER(WHERE cf.csat_score IN (4, 5))::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2
	) AS csat_pct
FROM customer_feedback as cf
JOIN support_tickets as st
ON cf.ticket_id = st.ticket_id
WHERE cf.csat_score BETWEEN 1 AND 5
GROUP BY st.issue_type
ORDER BY csat_pct ASC;


-- 7. Support Performance by Ride Type
WITH escalation_summary AS (
	SELECT
		st.ticket_id,
		MAX(
			CASE WHEN se.escalation_flag = TRUE THEN 1 ELSE 0 END
		) AS was_escalated
	FROM support_tickets as st
	LEFT JOIN support_events as se
	ON st.ticket_id = se.ticket_id
	GROUP BY st.ticket_id
),
repeat_summary AS (
	SELECT
		parent.ticket_id,
		MAX(
			CASE WHEN child.ticket_id IS NOT NULL THEN 1 ELSE 0 END
		) AS had_repeat_contact
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
		t.city,
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
	COUNT(*) AS support_tickets,
	ROUND(AVG(was_escalated) * 100 ,2) AS escalation_rate_pct,
	ROUND(
		AVG(CASE WHEN parent_ticket_id IS NULL THEN had_repeat_contact END), 2
	) AS repeat_contact_rate_pct,
	ROUND(
		AVG(
			CASE 
				WHEN resolved_at >= opened_at
				THEN EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 60
			END
		)
	, 2
	) AS avg_resolution_minutes
FROM ticket_level
GROUP BY ride_type
ORDER BY ride_type;