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


-- 7. The ticket_id on a row should not be the same as its parent_ticket_id
SELECT 
	COUNT(*) AS self_referencing_tickets
FROM support_tickets
WHERE ticket_id = parent_ticket_id;


-- 8. Return the number of repeated tickets
SELECT
	COUNT(*) as repeated_tickets
FROM support_tickets
WHERE parent_ticket_id IS NOT NULL;


-- 9. Verify that all completed trips have the following as not empty: started_at, completed_at, cancelled_at
SELECT
	COUNT(*) AS invalid_completed_trips
FROM trips
WHERE trip_status = 'completed'
AND (
	started_at IS NULL
	OR completed_at IS NULL
	OR cancelled_at IS NOT NULL
);


-- 10. Are there trips where they were started before requested_at time or they were completed before started_at
SELECT
	COUNT(*) AS completed_trips_with_invalid_time_order
FROM trips
WHERE trip_status = 'completed'
AND (
	started_at < requested_at
	OR completed_at < started_at
);


-- 11. Any cancelled trip with completion timestamp?
SELECT
	COUNT(*) AS invalid_cancelled_trip
FROM trips
WHERE trip_status  = 'cancelled'
AND (
	cancelled_at IS NULL
	OR completed_at IS NOT NULL
);


-- 12. Every customer feedback should point to an existing ticket
SELECT
	COUNT(*) AS feedback_with_invalid_ticket
FROM customer_feedback as cf
LEFT JOIN support_tickets as st
ON cf.ticket_id = st.ticket_id
WHERE st.ticket_id IS NULL;


-- 13. Every customer feedback should point to an existing rider
SELECT
	COUNT(*) AS feedback_with_invalid_rider
FROM customer_feedback as cf
LEFT JOIN riders as r
ON cf.rider_id = r.rider_id
WHERE r.rider_id IS NULL;


-- 14. Each eligible assessment should have a valid ticket id
SELECT
	COUNT(*) AS experiment_assignment_with_invalid_ticket
FROM experiment_assignments as ea
LEFT JOIN support_tickets as st
ON ea.ticket_id = st.ticket_id
WHERE st.ticket_id IS NULL;


-- 15. Verify that no assignment started before 1st April 2026
SELECT
	COUNT(*) AS pre_launch_assignments 
FROM experiment_assignments
WHERE assigned_at < TIMESTAMP '2026-04-01 00:00:00';


-- 16. Verify there is a 50/50 split
SELECT
	experiment_group,
	COUNT(*) AS assignments
FROM experiment_assignments
GROUP BY experiment_group
ORDER BY experiment_group;


-- 17. Are there any categories outide 'Control/ Treatment'
SELECT 
	COUNT(*) AS invalid_experiment_groups
FROM experiment_assignments
WHERE experiment_group NOT IN ('Control', 'Treatment');


-- 18. The ticket id in a financial adjustment should be valid
SELECT
	COUNT(*) AS adjustments_with_invalid_ticket
FROM financial_adjustments as fa
LEFT JOIN support_tickets as st
ON fa.ticket_id = st.ticket_id
WHERE st.ticket_id IS NULL;


-- 19. The financial adjustment should have a valid trip id as well
SELECT
	COUNT(*) AS adjustments_with_invalid_trip
FROM financial_adjustments as fa
LEFT JOIN trips as t
ON fa.trip_id = t.trip_id
WHERE t.trip_id IS NULL;


-- 20. Return the adjustment types
SELECT
	adjustment_type,
	COUNT(*) AS adjustment_count
FROM financial_adjustments
GROUP BY adjustment_type
ORDER BY adjustment_count DESC;


-- 21. Are there any negative or no financial adjustments
SELECT
	COUNT(*) AS zero_or_negative_adjustments
FROM financial_adjustments
WHERE amount <= 0;


-- 22. Any record where refund was higher than fare
SELECT
	COUNT(*) AS refunds_above_trip_fare
FROM financial_adjustments as fa
JOIN trips as t
ON fa.trip_id = t.trip_id
WHERE fa.adjustment_type = 'refund'
AND fa.amount > t.fare_amount;


-- 23. Do support event's point to a valid agent
SELECT
	COUNT(*) AS events_with_invalid_agent
FROM support_events as se
LEFT JOIN agents as a
ON se.agent_id = a.agent_id
WHERE se.agent_id IS NOT NULL
AND a.agent_id IS NULL;


-- 24. Support tickets have valid agent id?
SELECT
	COUNT(*) AS tickets_with_invalid_initial_agent
FROM support_tickets as st
LEFT JOIN agents as a
ON st.initial_agent_id = a.agent_id
WHERE a.agent_id IS NULL;


-- 25. Validate there is no assignment outside the AV assigned issues
SELECT
	COUNT(*) AS assignments_with_ineligible_issue
FROM experiment_assignments as ea
JOIN support_tickets as st
ON ea.ticket_id = st.ticket_id
WHERE st.issue_type NOT IN (
	'pickup_issue',
	'vehicle_access_issue',
	'trip_status_issue',
	'cancellation_issue'
);


-- 26. Confirm no assignment is non-AV
SELECT
	COUNT(*) AS confirmed_non_av_assignments
FROM experiment_assignments  as ea
JOIN support_tickets as st
ON ea.ticket_id = st.ticket_id 
JOIN trips AS t
ON st.trip_id = t.trip_id
WHERE t.ride_type <> 'AV';


-- 27. How many assignments have missing trip ids?
SELECT
	COUNT(*) AS experiment_assignment_missing_trip_relationship
FROM experiment_assignments as ea
JOIN support_tickets as st
ON ea.ticket_id = st.ticket_id
LEFT JOIN trips AS t
ON st.trip_id = t.trip_id
WHERE t.trip_id IS NULL;

