-- 1. Verify there are 25 duplicate financial adjustment rows
SELECT
	adjustment_id,
	COUNT(*) AS duplicate_num
FROM financial_adjustments
GROUP BY adjustment_id
HAVING COUNT(*) > 1
ORDER BY adjustment_id;


-- 1.1 Return the total number of duplicated rows
SELECT
	COUNT(*) - COUNT(DISTINCT adjustment_id) AS total_duplicate_adjustment_records
FROM financial_adjustments;


-- 2. How many support tickets do not have a trip_id
SELECT
	COUNT(*) AS tickets_missing_trip_id
FROM support_tickets
WHERE trip_id IS NULL;

-- 2.1 Return the details of these support tickets
SELECT
	ticket_id,
	rider_id,
	opened_at,
	issue_type,
	parent_ticket_id
FROM support_tickets
WHERE trip_id IS NULL
ORDER BY opened_at;


-- 3. Support tickets whose trip_ids do not exist in trips table
SELECT
	COUNT(*) AS tickets_with_invalid_trip
FROM support_tickets as st
LEFT JOIN trips as t
ON st.trip_id = t.trip_id
WHERE st.trip_id IS NOT NULL
AND t.trip_id IS NULL;


-- 4. Support events that do not have a support ticket id
SELECT
	COUNT(*) AS orphan_support_events
FROM support_events as se
LEFT JOIN support_tickets as st
ON se.ticket_id = st.ticket_id
WHERE se.ticket_id IS NOT NULL
AND st.ticket_id IS NULL;

-- 4.1 Show details of these tickets
SELECT
	se.event_id,
	se.ticket_id,
	se.event_time,
	se.event_type,
	se.agent_id
FROM support_events as se
LEFT JOIN support_tickets as st
ON se.ticket_id = st.ticket_id
WHERE st.ticket_id IS NULL
ORDER BY se.event_id;


-- 5. Tickets with impossible datetime (resolved before they were opened)
SELECT 
	COUNT(*) AS tickets_resolved_before_opened
FROM support_tickets
WHERE resolved_at < opened_at;

-- 5.1 Show these tickets
SELECT
	ticket_id,
	opened_at,
	resolved_at,
	EXTRACT(EPOCH FROM (resolved_at - opened_at)) / 60 AS resolution_minutes
FROM support_tickets
WHERE resolved_at < opened_at
ORDER BY ticket_id;


-- 6. Customer feedback with invalid CSAT scores (normal range is between 1 - 5))
SELECT
	COUNT(*) AS invalid_csat_records
FROM customer_feedback
WHERE csat_score NOT BETWEEN 1 AND 5;

-- 6.1 Inspect these invalid values
SELECT
	csat_score,
	COUNT(*) AS record_count
FROM customer_feedback
WHERE csat_score NOT BETWEEN 1 AND 5
GROUP BY csat_score
ORDER BY csat_score;